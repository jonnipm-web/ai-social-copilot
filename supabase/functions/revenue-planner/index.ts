import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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
- Todas as respostas em português brasileiro
- Valores em Reais (BRL)`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { input, project_name } = await req.json();

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
          {
            role: "user",
            content: `Projeto: ${project_name || "Projeto Digital"}\nInput/nicho/mercado: ${input}\n\nCrie o plano de receita e retorne o JSON.`,
          },
        ],
        temperature: 0.3,
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
