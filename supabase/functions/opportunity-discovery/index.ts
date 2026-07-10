import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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

  try {
    const { input } = await req.json();

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Input/nicho/projeto: ${input}\n\nDescubra as melhores oportunidades e retorne o JSON.` },
        ],
        temperature: 0.4,
        max_tokens: 4000,
      }),
    });

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
