import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { AuthError, resolveAuthenticatedUser, unauthorizedResponse } from "../_shared/auth.ts";
import { quotaBlockedResponse, refundQuota, reserveQuota } from "../_shared/quota.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em descoberta de oportunidades de mercado e estratégia de negócios digitais.

Identifique as melhores oportunidades de mercado para o input fornecido e retorne SOMENTE um JSON válido.

O JSON deve ter exatamente esta estrutura:

{
  "opportunities": [
    {
      "title": "Nome da Oportunidade",
      "type": "content",
      "description": "descrição detalhada da oportunidade e por que ela existe agora",
      "opportunity_score": 85,
      "market_score": 80,
      "growth_score": 90,
      "competition_score": 60,
      "monetization_score": 75,
      "difficulty_score": 45,
      "timeframe": "3-6 meses",
      "effort": "Médio",
      "action_steps": [
        "Passo 1 para aproveitar a oportunidade",
        "Passo 2",
        "Passo 3"
      ],
      "risks": ["Risco 1", "Risco 2"]
    }
  ]
}

Regras:
- type: "content", "seo", "product", "monetization", "partnership", "platform" ou "audience"
- opportunity_score, market_score, growth_score, competition_score, monetization_score, difficulty_score: 0-100
- difficulty_score: quanto mais alto, mais difícil (inverta para facilidade)
- Retorne entre 5 e 8 oportunidades rankeadas por opportunity_score decrescente
- Todas as respostas em português brasileiro
- Seja específico e acionável`;

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
    const { input } = await req.json();

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
          { role: "user", content: `Input/nicho/projeto: ${input}\n\nDescubra as melhores oportunidades e retorne o JSON.` },
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
