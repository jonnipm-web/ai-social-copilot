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
    if (!body?.text) {
      return new Response(JSON.stringify({ error: "Campo 'text' obrigatório." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const brandContext = body.brand_prompt
      ? `\nMARCA: ${body.brand_name}. ${body.brand_prompt}`
      : "";
    const personaContext = body.persona_prompt
      ? `\nPERSONA-ALVO: ${body.persona_name}. ${body.persona_prompt}`
      : "";
    const platformContext = body.platform ? `\nPLATAFORMA PRINCIPAL: ${body.platform}` : "";
    const objectiveContext = body.objective ? `\nOBJETIVO: ${body.objective}` : "";

    const systemPrompt = `Você é um especialista em marketing de conteúdo e reaproveitamento editorial.${brandContext}${personaContext}${platformContext}${objectiveContext}

A partir do texto fornecido, crie múltiplos formatos de conteúdo. Retorne SOMENTE um JSON válido:

{
  "instagram_posts": ["post 1 completo", "post 2 completo", "post 3 completo", "post 4 completo", "post 5 completo"],
  "carousels": [
    {"title": "título do carrossel 1", "slides": ["slide 1", "slide 2", "slide 3", "slide 4", "slide 5"]},
    {"title": "título do carrossel 2", "slides": ["slide 1", "slide 2", "slide 3", "slide 4", "slide 5"]},
    {"title": "título do carrossel 3", "slides": ["slide 1", "slide 2", "slide 3", "slide 4", "slide 5"]}
  ],
  "reels_scripts": ["roteiro completo reels 1", "roteiro completo reels 2"],
  "blog_article": "artigo completo para blog aqui",
  "email": "e-mail completo aqui",
  "alternative_titles": ["título 1", "título 2", "título 3", "título 4", "título 5"]
}

Retorne apenas o JSON. Nada mais.`;

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${GROQ_API_KEY}` },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: body.text },
        ],
        temperature: 0.75,
        max_tokens: 4000,
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
