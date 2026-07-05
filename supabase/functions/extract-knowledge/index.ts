import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em marketing digital, SEO, monetização e criação de conteúdo.

Analise profundamente o texto fornecido e retorne SOMENTE um JSON válido, sem markdown, sem explicações.

O JSON deve ter exatamente esta estrutura:

{
  "summary": "resumo em 3-5 frases do conteúdo",
  "keywords_primary": ["palavra-chave 1", "palavra-chave 2", "...até 8"],
  "keywords_secondary": ["kw secundária 1", "...até 10"],
  "keywords_longtail": ["frase longa 1", "...até 8"],
  "entities": ["pessoa/marca/lugar/produto mencionado", "..."],
  "topics": ["tópico principal 1", "...até 6"],
  "content_pillars": ["pilar de conteúdo 1", "...até 5"],
  "audience_pain_points": ["dor da audiência 1", "...até 6"],
  "audience_desires": ["desejo da audiência 1", "...até 6"],
  "commercial_angles": ["ângulo comercial 1", "...até 5"],
  "ctas": ["CTA sugerida 1", "...até 5"],
  "campaign_ideas": ["ideia de campanha 1", "...até 4"],
  "post_ideas": ["ideia de post para redes sociais 1", "...até 6"],
  "article_ideas": ["ideia de artigo/blog 1", "...até 4"],
  "seo_opportunities": ["oportunidade SEO 1", "...até 5"],
  "adsense_opportunities": ["oportunidade AdSense 1", "...até 4"],
  "amazon_kdp_opportunities": ["oportunidade Amazon KDP 1", "...até 4"],
  "score_seo": 75,
  "score_adsense": 60,
  "score_amazon_kdp": 45,
  "score_linkedin": 80,
  "score_social": 70,
  "score_details": {
    "seo": {
      "strengths": ["ponto forte 1", "ponto forte 2"],
      "weaknesses": ["ponto fraco 1"],
      "improvements": ["melhoria 1", "melhoria 2"]
    },
    "adsense": {
      "strengths": ["..."],
      "weaknesses": ["..."],
      "improvements": ["..."]
    },
    "amazon_kdp": {
      "strengths": ["..."],
      "weaknesses": ["..."],
      "improvements": ["..."]
    },
    "linkedin": {
      "strengths": ["..."],
      "weaknesses": ["..."],
      "improvements": ["..."]
    },
    "social": {
      "strengths": ["..."],
      "weaknesses": ["..."],
      "improvements": ["..."]
    }
  }
}

Scores são inteiros de 0 a 100.
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
    if (!body || typeof body.content !== "string" || body.content.trim().length < 20) {
      return new Response(
        JSON.stringify({ error: "Campo 'content' obrigatório (mínimo 20 caracteres)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const content = body.content.trim();
    const niche = body.niche ? `\nNicho: ${body.niche}` : "";
    const audience = body.target_audience ? `\nAudiência-alvo: ${body.target_audience}` : "";
    const language = body.language ?? "pt-BR";

    const userMessage = `Idioma de análise: ${language}${niche}${audience}\n\nConteúdo para analisar:\n\n${content.slice(0, 8000)}`;

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
        temperature: 0.5,
        max_tokens: 3000,
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
