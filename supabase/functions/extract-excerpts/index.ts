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
      ? `\n\nCONTEXTO DA MARCA: ${body.brand_name ?? ""}. ${body.brand_prompt}`
      : "";

    const systemPrompt = `Você é um especialista em criação de conteúdo editorial.${brandContext}

A partir do texto fornecido, extraia e crie conteúdos. Retorne SOMENTE um JSON válido neste formato exato:

{
  "impact_phrases": ["frase 1", "frase 2", "frase 3", "frase 4", "frase 5", "frase 6", "frase 7", "frase 8", "frase 9", "frase 10"],
  "short_posts": ["post 1", "post 2", "post 3", "post 4", "post 5"],
  "carousel_ideas": ["ideia de carrossel 1", "ideia de carrossel 2", "ideia de carrossel 3"],
  "video_scripts": ["roteiro 1", "roteiro 2", "roteiro 3"],
  "purchase_cta": "CTA de compra aqui",
  "follow_cta": "CTA para seguir perfil aqui"
}

Regras:
- impact_phrases: exatamente 10 frases de alto impacto do texto
- short_posts: exatamente 5 posts curtos prontos para publicar
- carousel_ideas: exatamente 3 ideias completas de carrossel com título e tópicos
- video_scripts: exatamente 3 roteiros curtos para Reels/Shorts (máx 60 segundos)
- purchase_cta: 1 CTA persuasivo de compra
- follow_cta: 1 CTA para seguir o perfil
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
        temperature: 0.7,
        max_tokens: 3000,
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
