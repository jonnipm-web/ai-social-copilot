import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const TEXT_MODEL = "llama-3.3-70b-versatile";
const VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const JSON_SCHEMA = `{
  "improved_text": "...",
  "professional_version": "...",
  "casual_version": "...",
  "persuasive_version": "...",
  "comment_reply": "...",
  "scores": { "clarity": 8.5, "impact": 7.0, "engagement": 9.0 }
}`;

function buildTextPrompt(nicheHint: string): string {
  return `Você é um especialista em comunicação digital e redes sociais.
${nicheHint ? `\n${nicheHint}\n` : ""}
Receba um texto e retorne SOMENTE um JSON válido, sem markdown, sem explicações, no seguinte formato exato:

${JSON_SCHEMA}

As notas devem ser de 0 a 10 com uma casa decimal, avaliando o texto ORIGINAL.
Retorne apenas o JSON. Nenhum texto antes ou depois.`;
}

function buildVisionPrompt(nicheHint: string): string {
  return `Você é um especialista em comunicação digital e redes sociais com capacidade de análise visual.
${nicheHint ? `\n${nicheHint}\n` : ""}
Analise a imagem fornecida e crie sugestões de posts para redes sociais com base no que está na foto.

Retorne SOMENTE um JSON válido, sem markdown, sem explicações, no seguinte formato exato:

${JSON_SCHEMA}

- "improved_text": legenda principal otimizada, envolvente, que descreva e valorize a imagem
- "professional_version": versão com tom profissional e formal
- "casual_version": versão descontraída com linguagem natural
- "persuasive_version": versão persuasiva com call-to-action
- "comment_reply": sugestão de resposta para comentários sobre este post
- As notas avaliam o potencial de engajamento da imagem/contexto fornecido
Retorne apenas o JSON. Nenhum texto antes ou depois.`;
}

const REQUIRED_FIELDS = [
  "improved_text",
  "professional_version",
  "casual_version",
  "persuasive_version",
  "comment_reply",
  "scores",
];

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
        JSON.stringify({ error: "Corpo da requisição inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const hasImage = typeof body.image_base64 === "string" && body.image_base64.length > 0;
    const hasText = typeof body.text === "string" && body.text.trim().length >= 10;
    const nicheHint = typeof body.niche_hint === "string" ? body.niche_hint : "";

    if (!hasImage && !hasText) {
      return new Response(
        JSON.stringify({ error: "Envie uma imagem ou um texto com pelo menos 10 caracteres." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let groqBody: Record<string, unknown>;

    if (hasImage) {
      const mediaType = (body.image_media_type as string) || "image/jpeg";
      const imageUrl = `data:${mediaType};base64,${body.image_base64}`;
      const userContent: unknown[] = [
        { type: "image_url", image_url: { url: imageUrl } },
      ];
      if (hasText) {
        userContent.push({ type: "text", text: `Contexto adicional: ${body.text.trim()}` });
      }
      groqBody = {
        model: VISION_MODEL,
        messages: [
          { role: "system", content: buildVisionPrompt(nicheHint) },
          { role: "user", content: userContent },
        ],
        temperature: 0.7,
        max_tokens: 1500,
      };
    } else {
      groqBody = {
        model: TEXT_MODEL,
        messages: [
          { role: "system", content: buildTextPrompt(nicheHint) },
          { role: "user", content: body.text.trim() },
        ],
        temperature: 0.7,
        max_tokens: 1500,
      };
    }

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify(groqBody),
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

    for (const field of REQUIRED_FIELDS) {
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
