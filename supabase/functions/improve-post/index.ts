import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

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

As notas devem ser de 0 a 10 com uma casa decimal, avaliando o texto ORIGINAL.
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
    if (!body || typeof body.text !== "string" || body.text.trim().length < 10) {
      return new Response(
        JSON.stringify({ error: "Campo 'text' obrigatório (mínimo 10 caracteres)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userText = body.text.trim();

    // Build system prompt with optional persona context
    let systemPrompt = SYSTEM_PROMPT;
    if (body.persona_context && typeof body.persona_context === "object") {
      const pc = body.persona_context;
      const personaLines: string[] = [];
      if (pc.name) personaLines.push(`Persona/Marca: ${pc.name}`);
      if (pc.tone) personaLines.push(`Tom de voz: ${pc.tone}`);
      if (pc.vocabulary?.length) personaLines.push(`Vocabulário preferido: ${pc.vocabulary.join(", ")}`);
      if (pc.values?.length) personaLines.push(`Valores: ${pc.values.join(", ")}`);
      if (pc.style) personaLines.push(`Estilo: ${pc.style}`);
      if (personaLines.length > 0) {
        systemPrompt = SYSTEM_PROMPT + "\n\nCONTEXTO DA PERSONA/MARCA (use para adaptar o tom e estilo):\n" + personaLines.join("\n");
      }
    }

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userText },
        ],
        temperature: 0.7,
        max_tokens: 1500,
      }),
    });

    if (!groqRes.ok) {
      const err = await groqRes.text();
      console.error("Groq error:", err);
      return new Response(
        JSON.stringify({ error: "Falha ao processar com a IA. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const groqData = await groqRes.json();
    const rawText = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error("JSON não encontrado:", rawText);
      return new Response(
        JSON.stringify({ error: "Resposta inválida da IA. Tente novamente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const result = JSON.parse(jsonMatch[0]);

    for (const field of ["improved_text", "professional_version", "casual_version", "persuasive_version", "comment_reply", "scores"]) {
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
