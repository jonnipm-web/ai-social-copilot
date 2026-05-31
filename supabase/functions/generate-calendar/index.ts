import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => null);
    if (!body?.brand_name || !body?.objective || !body?.platform || !body?.period_days) {
      return new Response(JSON.stringify({ error: "Campos obrigatórios: brand_name, objective, platform, period_days." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const periodDays = Number(body.period_days);
    const personaContext = body.persona_name
      ? `\nPERSONA-ALVO: ${body.persona_name}. ${body.persona_prompt ?? ""}`
      : "";

    const systemPrompt = `Você é um estrategista de conteúdo digital especializado em calendários editoriais.

MARCA: ${body.brand_name}
NICHO: ${body.niche ?? ""}
TOM: ${body.tone ?? ""}
CONTEXTO: ${body.brand_prompt ?? ""}${personaContext}
PLATAFORMA: ${body.platform}
OBJETIVO: ${body.objective}
PERÍODO: ${periodDays} dias

Crie um calendário editorial completo. Retorne SOMENTE um JSON válido:

{
  "brand_name": "${body.brand_name}",
  "objective": "${body.objective}",
  "platform": "${body.platform}",
  "period_days": ${periodDays},
  "days": [
    {
      "day": 1,
      "theme": "tema do dia",
      "format": "formato (post, carrossel, reels, stories, artigo)",
      "hook": "gancho de abertura do conteúdo",
      "cta": "call-to-action específico",
      "strategic_note": "observação estratégica sobre por que este conteúdo neste dia"
    }
  ]
}

Crie exatamente ${periodDays} entradas no array "days" (dia 1 até dia ${periodDays}).
Varie os formatos ao longo do período. Alinhe cada dia com o objetivo de ${body.objective}.
Retorne apenas o JSON. Nada mais.`;

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${GROQ_API_KEY}` },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `Gere o calendário editorial para ${periodDays} dias.` },
        ],
        temperature: 0.7,
        max_tokens: periodDays <= 7 ? 2000 : periodDays <= 15 ? 3500 : 5000,
      }),
    });

    if (!groqRes.ok) {
      return new Response(JSON.stringify({ error: "Falha ao processar com a IA." }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const groqData = await groqRes.json();
    const rawText = groqData.choices?.[0]?.message?.content ?? "";
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return new Response(JSON.stringify({ error: "Resposta inválida da IA." }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const result = JSON.parse(jsonMatch[0]);
    return new Response(JSON.stringify(result), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: "Erro interno." }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
