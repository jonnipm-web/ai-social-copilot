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

const SYSTEM_PROMPT = `Você é um especialista em análise competitiva e inteligência de mercado digital.

Identifique os principais concorrentes para o input fornecido e retorne SOMENTE um JSON válido.

O JSON deve ter exatamente esta estrutura:

{
  "competitors": [
    {
      "name": "Nome do Concorrente",
      "url": "https://exemplo.com",
      "type": "direct",
      "similarity_score": 85,
      "authority_score": 72,
      "relevance_score": 90,
      "description": "descrição breve do concorrente e por que é relevante",
      "strengths": ["ponto forte 1", "ponto forte 2"],
      "weaknesses": ["ponto fraco 1", "ponto fraco 2"],
      "opportunities": ["oportunidade de diferenciação 1", "oportunidade 2"]
    }
  ]
}

Regras:
- type: "direct" (mesmo nicho/produto), "indirect" (nicho adjacente) ou "aspirational" (líder de mercado referência)
- similarity_score, authority_score, relevance_score: 0-100
- Retorne entre 5 e 10 concorrentes
- Misture concorrentes diretos, indiretos e aspiracionais
- URLs devem ser URLs reais e plausíveis`;

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
  // decides whether this caller may use 'competitor-discovery'. Runs after authentication
  // and before any quota reservation or AI call. Fails closed.
  const access = await requireModuleAccess(req, authUser, 'competitor-discovery', corsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  let quotaReserved = false;
  // IVE-COMMERCIAL-QUOTA-HARDENING-13 — hoisted above the try block so the
  // catch-block refund below can pass the SAME key the reservation used.
  let idempotencyKey: string | undefined;
  let quotaResult: Awaited<ReturnType<typeof reserveQuota>> | undefined;
  try {
    const { input, language: rawLanguage, idempotency_key } = await req.json();
    idempotencyKey = idempotency_key;
    const language = normalizeLanguage(rawLanguage);

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quota = await reserveQuota(req, quotaClient, idempotencyKey, 'competitor-discovery');
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
          { role: "user", content: withLanguageDirective(language, `Input/nicho/projeto: ${input}\n\nIdentifique os concorrentes e retorne o JSON.`) },
        ],
        temperature: 0.4,
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
