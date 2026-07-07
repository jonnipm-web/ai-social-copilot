import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function buildSystemPrompt(objective: string, duration: number, channels: string[]): string {
  return `Você é um especialista em criação de campanhas de marketing digital.

Crie uma campanha completa de ${duration} dias com objetivo: ${objective}
Canais: ${channels.join(", ")}

Retorne SOMENTE um JSON válido com esta estrutura:

{
  "campaign_name": "nome criativo da campanha",
  "tagline": "slogan da campanha",
  "objective": "${objective}",
  "duration_days": ${duration},
  "channels": ${JSON.stringify(channels)},
  "overview": "visão geral da campanha em 2-3 frases",
  "target_cpa": "custo por aquisição estimado",
  "expected_results": ["resultado esperado 1", "resultado 2", "até 4"],
  "calendar": [
    {
      "day": 1,
      "channel": "canal",
      "content_type": "post/reels/stories/email/artigo/carrossel",
      "topic": "tema do conteúdo",
      "hook": "gancho de abertura",
      "cta": "chamada para ação",
      "hashtags": ["#tag1", "#tag2"],
      "content_brief": "briefing do conteúdo em 2-3 frases"
    }
  ],
  "email_sequence": [
    {"day": 1, "subject": "assunto", "preview": "preview do email", "objective": "objetivo"}
  ],
  "key_messages": ["mensagem chave 1", "mensagem 2", "até 4"],
  "success_metrics": ["métrica 1", "métrica 2", "até 5"]
}

O calendário deve ter 1 entrada por dia por canal (máximo 30 dias no JSON, resumir se duration > 30).
Para cada canal, gere conteúdo relevante e variado.
Retorne apenas o JSON. Nenhum texto antes ou depois.`;
}

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
      objective = "venda",
      duration_days = 30,
      channels = ["Instagram"],
      niche = "",
      target_audience = "",
      summary = "",
      value_proposition = "",
      keywords = [],
      language = "pt-BR",
    } = body;

    const context = [
      `Produto/Ativo: ${title}`,
      niche ? `Nicho: ${niche}` : "",
      target_audience ? `Público-alvo: ${target_audience}` : "",
      value_proposition ? `Proposta de valor: ${value_proposition}` : "",
      summary ? `Contexto: ${summary.slice(0, 500)}` : "",
      keywords.length ? `Keywords: ${keywords.slice(0, 6).join(", ")}` : "",
    ].filter(Boolean).join("\n");

    const userMessage = `Idioma da campanha: ${language}\n\n${context}`;

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: buildSystemPrompt(objective, Math.min(duration_days, 30), channels) },
          { role: "user", content: userMessage },
        ],
        temperature: 0.7,
        max_tokens: 4000,
      }),
    });

    if (!groqRes.ok) {
      const err = await groqRes.text();
      console.error("Groq error:", err);
      return new Response(
        JSON.stringify({ error: "Falha ao gerar campanha. Tente novamente." }),
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
