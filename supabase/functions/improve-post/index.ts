import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const MODEL = "claude-sonnet-4-6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em comunicação digital e redes sociais.

Receba um texto e retorne SOMENTE um JSON válido, sem markdown, sem explicações, no seguinte formato exato:

{
  "improved_text": "texto otimizado mantendo a ideia original, mais claro e envolvente",
  "professional_version": "versão com tom profissional e formal",
  "casual_version": "versão descontraída e próxima, com linguagem natural",
  "persuasive_version": "versão persuasiva com call-to-action claro",
  "comment_reply": "sugestão de resposta para comentários sobre este post",
  "scores": {
    "clarity": 8.5,
    "impact": 7.0,
    "engagement": 9.0
  }
}

As notas devem ser de 0 a 10 com uma casa decimal, avaliando o texto ORIGINAL (não o melhorado).
Retorne apenas o JSON. Nenhum texto antes ou depois.`;

serve(async (req) => {
  // CORS preflight
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
    if (!body || typeof body.text !== "string" || body.text.trim().length < 10) {
      return new Response(
        JSON.stringify({ error: "Campo 'text' obrigatório (mínimo 10 caracteres)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userText = body.text.trim();

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1500,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: userText }],
      }),
    });

    if (!anthropicRes.ok) {
      const err = await anthropicRes.text();
      console.error("Anthropic error:", err);
      return new Response(
        JSON.stringify({ error: "Falha ao processar com a IA. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const anthropicData = await anthropicRes.json();
    const rawText: string = anthropicData.content?.[0]?.text ?? "";

    // Extrai o JSON da resposta (remove eventuais artefatos)
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error("JSON não encontrado na resposta:", rawText);
      return new Response(
        JSON.stringify({ error: "Resposta inválida da IA. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const result = JSON.parse(jsonMatch[0]);

    // Valida campos obrigatórios
    const required = [
      "improved_text",
      "professional_version",
      "casual_version",
      "persuasive_version",
      "comment_reply",
      "scores",
    ];
    for (const field of required) {
      if (!(field in result)) {
        return new Response(
          JSON.stringify({ error: `Campo '${field}' ausente na resposta da IA.` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

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
