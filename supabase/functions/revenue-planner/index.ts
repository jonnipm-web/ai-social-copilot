import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from "../_shared/auth.ts";
import { EntitlementSubjectSource, requireModuleAccess } from "../_shared/entitlement.ts";
import { normalizeLanguage, withLanguageDirective } from "../_shared/language.ts";
import { QuotaClient, quotaBlockedResponse, refundQuota, reserveQuota } from "../_shared/quota.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em planejamento financeiro para negócios digitais, monetização de conteúdo e projetos online.

Crie um plano de receita realista para o projeto fornecido e retorne SOMENTE um JSON válido.

O JSON deve ter exatamente esta estrutura:

{
  "monthly_conservative": 1500,
  "monthly_moderate": 4500,
  "monthly_aggressive": 12000,
  "annual_conservative": 18000,
  "annual_moderate": 54000,
  "annual_aggressive": 144000,
  "revenue_sources": [
    {
      "name": "Nome da Fonte de Receita",
      "description": "como gerar receita com isto",
      "percentage": 35,
      "timeframe": "3-6 meses para ativar"
    }
  ],
  "milestones": [
    {
      "title": "Primeiro R$ X/mês",
      "target": 1000,
      "month": 3,
      "description": "o que precisa acontecer para atingir este marco"
    }
  ],
  "assumptions": [
    "premissa 1 usada para o cálculo",
    "premissa 2",
    "até 6 premissas"
  ]
}

Regras:
- Os valores devem ser realistas para o mercado brasileiro
- Cenário conservador: crescimento orgânico lento, sem investimento em tráfego pago
- Cenário moderado: crescimento consistente com algum investimento
- Cenário agressivo: com investimento significativo em tráfego e produto
- percentage em revenue_sources deve somar 100
- Defina 5-7 marcos progressivos
- Valores em Reais (BRL) independentemente do idioma da resposta`;

// Exportado para testes (MODULE-FOUNDATION-AND-ENTITLEMENT-02). Em produção,
// serve() chama esta função com os clients reais.
export async function handler(
  req: Request,
  authClient?: AuthClient,
  quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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
  // decides whether this caller may use 'revenue-planner'. Runs after authentication
  // and before any quota reservation or AI call. Fails closed.
  const access = await requireModuleAccess(req, authUser, 'revenue-planner', corsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  let quotaReserved = false;
  let idempotencyKey: string | undefined;
  let quotaResult: Awaited<ReturnType<typeof reserveQuota>> | undefined;
  try {
    const { input, project_name, language: rawLanguage, idempotency_key } = await req.json();
    idempotencyKey = idempotency_key;
    const language = normalizeLanguage(rawLanguage);

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quota = await reserveQuota(req, quotaClient, idempotencyKey, 'revenue-planner');
    if (!quota.allowed) return quotaBlockedResponse(corsHeaders, quota);
    quotaReserved = true;
    quotaResult = quota;

    const groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-120b",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: withLanguageDirective(language, `Projeto: ${project_name || "Projeto Digital"}\nInput/nicho/mercado: ${input}\n\nCrie o plano de receita e retorne o JSON.`),
          },
        ],
        temperature: 0.3,
        max_completion_tokens: 3000,
      }),
    });

    if (!groqResponse.ok) {
      const errText = await groqResponse.text();
      throw new Error(`Groq error ${groqResponse.status}: ${errText}`);
    }

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    if (quotaReserved) await refundQuota(req, quotaClient, quotaResult);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
