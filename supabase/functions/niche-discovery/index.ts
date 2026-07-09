import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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
- Misture os 3 níveis: pelo menos 3 de cada tipo
- Todas as respostas em português brasileiro`;

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
          { role: "user", content: `Input/nicho/projeto: ${input}\n\nMapeie os top 10 nichos/sub-nichos/micro-nichos e retorne o JSON.` },
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
