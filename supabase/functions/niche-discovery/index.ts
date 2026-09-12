import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { AuthError, resolveAuthenticatedUser, unauthorizedResponse } from "../_shared/auth.ts";
import { normalizeLanguage, withLanguageDirective } from "../_shared/language.ts";
import { quotaBlockedResponse, refundQuota, reserveQuota } from "../_shared/quota.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em descoberta de nichos de mercado rentáveis para criadores de conteúdo e empreendedores digitais.

Mapeie os melhores nichos, sub-nichos e micro-nichos para o input fornecido e retorne SOMENTE um JSON válido.

O JSON deve ter exatamente esta estrutura:

{
  "niches": [
    {
      "name": "Nome do Nicho/Sub-nicho/Micro-nicho",
      "level": "niche",
      "description": "descrição detalhada do nicho e por que é promissor",
      "competition_score": 65,
      "potential_score": 88,
      "growth_score": 75,
      "monetization_score": 82,
      "difficulty_score": 55,
      "trend_score": 70,
      "overall_score": 80,
      "keywords": ["palavra-chave 1", "palavra-chave 2", "palavra-chave 3", "até 6 keywords"],
      "monetization_methods": ["método 1", "método 2", "método 3"],
      "why": "por que este nicho tem alto potencial agora"
    }
  ]
}

Regras:
- level: "niche" (mercado amplo), "sub_niche" (segmento específico) ou "micro_niche" (segmento muito específico)
- Todos os scores: 0-100
- overall_score: média ponderada dos demais scores
- Retorne exatamente 10 nichos/sub-nichos/micro-nichos rankeados por overall_score decrescente
- Misture os 3 níveis: pelo menos 3 de cada tipo`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // IVE-COMMERCIAL-AUTH-01 — exige sessão de usuário real antes do Groq. Falha fechado.
  try {
    await resolveAuthenticatedUser(req);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  let quotaReserved = false;
  try {
    const { input, language: rawLanguage } = await req.json();
    const language = normalizeLanguage(rawLanguage);

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quota = await reserveQuota(req);
    if (!quota.allowed) return quotaBlockedResponse(corsHeaders, quota);
    quotaReserved = true;

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
          { role: "user", content: withLanguageDirective(language, `Input/nicho/projeto: ${input}\n\nMapeie os top 10 nichos/sub-nichos/micro-nichos e retorne o JSON.`) },
        ],
        temperature: 0.4,
        max_completion_tokens: 4000,
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
    if (quotaReserved) await refundQuota(req);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
