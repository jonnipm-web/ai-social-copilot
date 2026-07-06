import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um Estrategista de Marketing Digital e Monetização de elite.

Analise o conteúdo e dados fornecidos e retorne SOMENTE um JSON válido com a estratégia completa.

Estrutura obrigatória:

{
  "strategic_summary": "resumo executivo da estratégia em 3-4 frases",
  "target_audience": {
    "primary": "descrição do público primário",
    "secondary": "descrição do público secundário",
    "age_range": "faixa etária",
    "interests": ["interesse 1", "interesse 2", "até 5"]
  },
  "pain_points": ["dor principal 1", "dor 2", "até 5"],
  "desires": ["desejo 1", "desejo 2", "até 5"],
  "positioning": "posicionamento único no mercado",
  "differentials": ["diferencial 1", "diferencial 2", "até 4"],
  "value_proposition": "proposta de valor em 1 frase impactante",
  "recommended_channels": [
    {"channel": "Instagram", "priority": "alta", "reason": "motivo"},
    {"channel": "YouTube", "priority": "média", "reason": "motivo"}
  ],
  "funnel": {
    "awareness": "estratégia de awareness",
    "consideration": "estratégia de consideração",
    "conversion": "estratégia de conversão",
    "retention": "estratégia de retenção"
  },
  "cta_primary": "CTA principal",
  "cta_secondary": "CTA secundário",
  "commercial_opportunities": [
    {"type": "tipo de monetização", "description": "descrição", "potential": "alto/médio/baixo"}
  ],
  "priority_keywords": ["keyword 1", "keyword 2", "até 8"],
  "content_calendar_hint": "sugestão de frequência e tipos de conteúdo",
  "growth_plan": {
    "month_1": "foco do mês 1",
    "month_2": "foco do mês 2",
    "month_3": "foco do mês 3",
    "kpis": ["KPI 1", "KPI 2", "até 4"]
  },
  "quick_wins": ["ação rápida 1", "ação rápida 2", "até 3"]
}

Retorne apenas o JSON. Nenhum texto antes ou depois.`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Método não permitido." }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json().catch(() => null);
    if (!body) {
      return new Response(
        JSON.stringify({ error: "Body inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const {
      title = "",
      content = "",
      summary = "",
      niche = "",
      target_audience = "",
      language = "pt-BR",
      keywords_primary = [],
      pain_points = [],
      desires = [],
      topics = [],
    } = body;

    const context = [
      `Título do ativo: ${title}`,
      niche ? `Nicho: ${niche}` : "",
      target_audience ? `Audiência-alvo: ${target_audience}` : "",
      summary ? `Resumo: ${summary}` : "",
      keywords_primary.length ? `Keywords principais: ${keywords_primary.slice(0, 8).join(", ")}` : "",
      pain_points.length ? `Dores identificadas: ${pain_points.slice(0, 5).join(", ")}` : "",
      desires.length ? `Desejos identificados: ${desires.slice(0, 5).join(", ")}` : "",
      topics.length ? `Tópicos principais: ${topics.slice(0, 6).join(", ")}` : "",
      content ? `\nConteúdo (trecho):\n${content.trim().slice(0, 3000)}` : "",
    ].filter(Boolean).join("\n");

    const userMessage = `Idioma: ${language}\n\n${context}`;

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userMessage },
        ],
        temperature: 0.6,
        max_tokens: 3000,
      }),
    });

    if (!groqRes.ok) {
      const err = await groqRes.text();
      console.error("Groq error:", err);
      return new Response(
        JSON.stringify({ error: "Falha ao gerar estratégia. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const groqData = await groqRes.json();
    const rawText = groqData.choices?.[0]?.message?.content ?? "";
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);

    if (!jsonMatch) {
      return new Response(
        JSON.stringify({ error: "Resposta inválida da IA. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Erro inesperado:", e);
    return new Response(
      JSON.stringify({ error: "Erro interno. Tente novamente." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
