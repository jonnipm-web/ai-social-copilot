import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import { QuotaClient, quotaBlockedResponse, refundQuota, reserveQuota } from '../_shared/quota.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Exportado para testes (MODULE-FOUNDATION-AND-ENTITLEMENT-02). Em produção,
// serve() chama esta função com os clients reais.
export async function handler(
  req: Request,
  authClient?: AuthClient,
  quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  // IVE-COMMERCIAL-AUTH-01 — exige sessão de usuário real antes do Groq. Falha fechado.
  let authUser: AuthenticatedUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  // MODULE-FOUNDATION-AND-ENTITLEMENT-02 — server-side entitlement: the server
  // (supabase/functions/_shared/module_policy.ts), not the client registry,
  // decides whether this caller may use 'action-engine'. Runs after authentication
  // and before any quota reservation or AI call. Fails closed.
  const access = await requireModuleAccess(req, authUser, 'action-engine', corsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  let quotaReserved = false;
  let idempotencyKey: string | undefined;
  let quotaResult: Awaited<ReturnType<typeof reserveQuota>> | undefined;
  try {
    const { project_name, opportunities, idempotency_key } = await req.json();
    idempotencyKey = idempotency_key;

    const oppLines = ((opportunities ?? []) as Array<{ title: string; description: string }>)
      .map((o) => `• ${o.title}: ${o.description}`)
      .join('\n') || 'Sem oportunidades listadas';

    const userPrompt = `Projeto: ${project_name}

Oportunidades identificadas para este projeto:
${oppLines}

Crie EXATAMENTE 5 ações concretas, priorizadas e executáveis para avançar nas oportunidades acima.
Retorne APENAS JSON válido no formato abaixo, sem texto adicional:

{
  "actions": [
    {
      "title": "Verbo + objeto concreto (ex: Criar landing page de captura)",
      "action_type": "tarefa",
      "priority": 1,
      "impact_score": 80,
      "effort_score": 35,
      "roi_score": 72
    }
  ]
}

Regras:
- Gere exatamente 5 ações
- priority: 1 (mais urgente/importante) a 5 (menos urgente)
- impact_score: impacto esperado no negócio, 0-100
- effort_score: esforço necessário, 0-100 (menor = mais fácil de executar)
- roi_score: retorno sobre investimento esperado, 0-100
- Tipos válidos para action_type: tarefa, conteúdo, campanha, produto, análise`;

    const quota = await reserveQuota(req, quotaClient, idempotencyKey, 'generate-project-actions');
    if (!quota.allowed) return quotaBlockedResponse(corsHeaders, quota);
    quotaReserved = true;
    quotaResult = quota;

    const resp = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('GROQ_API_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'openai/gpt-oss-120b',
        messages: [
          {
            role: 'system',
            content:
              'Você é um gerente de projetos especialista em marketing digital. Responda APENAS com JSON válido, sem markdown, sem texto antes ou depois do JSON.',
          },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.6,
        max_completion_tokens: 1024,
        response_format: { type: 'json_object' },
      }),
    });

    if (!resp.ok) {
      const err = await resp.text();
      await refundQuota(req, quotaClient, quotaResult);
      return Response.json({ error: `Groq error: ${err}` }, { status: 502, headers: corsHeaders });
    }

    const groq = await resp.json();
    const content = groq.choices?.[0]?.message?.content ?? '{}';

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(content);
    } catch {
      await refundQuota(req, quotaClient, quotaResult);
      return Response.json(
        { error: 'JSON inválido retornado pelo modelo', raw: content },
        { status: 502, headers: corsHeaders },
      );
    }

    if (!parsed.actions) parsed.actions = [];

    return Response.json(parsed, { headers: corsHeaders });
  } catch (e) {
    if (quotaReserved) await refundQuota(req, quotaClient, quotaResult);
    return Response.json({ error: String(e) }, { status: 500, headers: corsHeaders });
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
