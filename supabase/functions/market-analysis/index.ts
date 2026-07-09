import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em inteligência de mercado, SEO, monetização e estratégia digital.

Analise o input fornecido (URL, domínio, nicho ou descrição de projeto) e retorne SOMENTE um JSON válido, sem markdown, sem explicações.

O JSON deve ter exatamente esta estrutura:

{
  "niche": "nicho principal detectado",
  "sub_niche": "sub-nicho específico",
  "target_audience": "público-alvo principal detalhado",
  "business_type": "tipo de negócio (blog, e-commerce, SaaS, infoproduto, etc)",
  "value_proposition": "proposta de valor única",
  "positioning": "posicionamento de mercado",
  "monetization_model": "modelo de monetização principal",
  "opportunity_score": 75,
  "executive_summary": "resumo executivo em 2-3 frases sobre o potencial de mercado",
  "competitive_landscape": "descrição do cenário competitivo",
  "strengths": ["ponto forte 1", "ponto forte 2", "até 5 pontos fortes"],
  "weaknesses": ["ponto fraco 1", "ponto fraco 2", "até 5 pontos fracos"],
  "market_trends": ["tendência 1", "tendência 2", "até 5 tendências de mercado"],
  "recommendations": [
    "recomendação executiva prioritária 1",
    "recomendação executiva prioritária 2",
    "recomendação executiva prioritária 3",
    "até 5 recomendações"
  ]
}

Regras:
- opportunity_score: 0-100 baseado em potencial real de mercado
- Todas as respostas em português brasileiro
- Seja específico e acionável`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { input, input_type } = await req.json();

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userMessage = `Tipo de entrada: ${input_type || "url"}\nInput: ${input}\n\nAnalise este mercado e retorne o JSON conforme especificado.`;

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
          { role: "user", content: userMessage },
        ],
        temperature: 0.3,
        max_tokens: 2048,
      }),
    });

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const analysis = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(analysis), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
