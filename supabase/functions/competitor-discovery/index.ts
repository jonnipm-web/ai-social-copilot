import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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
- Todas as respostas em português brasileiro
- URLs devem ser URLs reais e plausíveis`;

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
          { role: "user", content: `Input/nicho/projeto: ${input}\n\nIdentifique os concorrentes e retorne o JSON.` },
        ],
        temperature: 0.4,
        max_tokens: 3000,
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
