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
  "score_opportunity": 82,
  "score_hotmart": 75,
  "score_shopify": 60,
  "hotmart_data": {
    "product_name": "nome sugerido para o produto digital",
    "promise": "promessa principal do produto",
    "price_range": "R$ 97 - R$ 297",
    "format": "ebook/curso/mentoria/comunidade",
    "upsell": "sugestão de upsell"
  },
  "shopify_data": {
    "product_name": "nome sugerido para o produto físico/digital",
    "short_description": "descrição curta em 1 frase",
    "categories": ["categoria 1", "categoria 2"],
    "price_range": "R$ 29 - R$ 97"
  },
  "persona_training": {
    "tone": "tom de voz (ex: educativo, inspirador, direto)",
    "vocabulary": ["palavra 1", "palavra 2", "até 5 palavras-chave do vocabulário"],
    "values": ["valor 1", "valor 2", "até 3 valores centrais"],
    "communication_style": "estilo de comunicação em 1 frase"
  },
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

Todos os scores são inteiros de 0 a 100.
score_opportunity avalia: tamanho de mercado, intensidade da dor, potencial de monetização, SEO e recorrência.
score_hotmart avalia potencial como produto digital (ebook, curso, mentoria).
score_shopify avalia potencial como produto e-commerce.
Retorne apenas o JSON. Nenhum texto antes ou depois.`;

// ── Fetch content from a URL ──────────────────────────────────

async function fetchUrlContent(url: string): Promise<string> {
  // Google Docs → export as plain text
  const docsMatch = url.match(/docs\.google\.com\/document\/d\/([a-zA-Z0-9_-]+)/);
  if (docsMatch) {
    const exportUrl = `https://docs.google.com/document/d/${docsMatch[1]}/export?format=txt`;
    const res = await fetch(exportUrl, {
      headers: { "User-Agent": "Mozilla/5.0" },
      redirect: "follow",
    });
    if (!res.ok) {
      throw new Error(
        `Google Doc inacessível (${res.status}). Verifique se está compartilhado como 'Qualquer pessoa com o link pode visualizar'.`
      );
    }
    return await res.text();
  }

  // Google Drive file (PDF/DOCX) → download attempt
  const driveMatch = url.match(/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (driveMatch) {
    const fileId = driveMatch[1];
    // Try the export as plain text (works for Google Docs stored as Drive files)
    const exportUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;
    const res = await fetch(exportUrl, {
      headers: { "User-Agent": "Mozilla/5.0" },
      redirect: "follow",
    });
    if (!res.ok) {
      throw new Error(
        `Arquivo do Google Drive inacessível. Use um Google Doc (não PDF) e compartilhe como 'Qualquer pessoa com o link'.`
      );
    }
    const contentType = res.headers.get("content-type") ?? "";
    if (contentType.includes("text/html")) {
      // Google Drive shows a confirmation page for large files — treat as error
      throw new Error(
        `Não foi possível baixar o arquivo diretamente. Converta para Google Docs e use o link de edição.`
      );
    }
    const text = await res.text();
    if (text.trim().length < 20) {
      throw new Error("Arquivo vazio ou binário. Use um Google Doc com o link de edição.");
    }
    return text;
  }

  // Generic public URL → fetch HTML and strip tags
  const res = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0" },
    redirect: "follow",
  });
  if (!res.ok) {
    throw new Error(`URL inacessível (${res.status}). Verifique se o endereço é público.`);
  }

  const contentType = res.headers.get("content-type") ?? "";
  if (contentType.includes("text/html") || contentType.includes("text/plain")) {
    const raw = await res.text();
    // Strip HTML tags
    const text = raw
      .replace(/<script[\s\S]*?<\/script>/gi, "")
      .replace(/<style[\s\S]*?<\/style>/gi, "")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    if (text.length < 20) throw new Error("Conteúdo da URL muito curto para análise.");
    return text;
  }

  throw new Error("Tipo de arquivo não suportado para análise automática. Use Texto Manual.");
}

// ── Main handler ──────────────────────────────────────────────

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

    let content: string = body.content ?? "";
    const sourceUrl: string | null = body.source_url ?? null;

    // Detect URL: use source_url if provided, otherwise check if content itself is a bare URL
    const trimmedContent = content.trim();
    const urlToFetch = sourceUrl ??
      (trimmedContent.startsWith("http") && !trimmedContent.includes(" ") && !trimmedContent.includes("\n")
        ? trimmedContent
        : null);

    if (urlToFetch) {
      try {
        content = await fetchUrlContent(urlToFetch);
      } catch (fetchErr) {
        return new Response(
          JSON.stringify({ error: String(fetchErr instanceof Error ? fetchErr.message : fetchErr) }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    if (!content || content.trim().length < 20) {
      return new Response(
        JSON.stringify({ error: "Conteúdo muito curto para análise (mínimo 20 caracteres)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const niche = body.niche ? `\nNicho: ${body.niche}` : "";
    const audience = body.target_audience ? `\nAudiência-alvo: ${body.target_audience}` : "";
    const language = body.language ?? "pt-BR";

    const userMessage = `Idioma de análise: ${language}${niche}${audience}\n\nConteúdo para analisar:\n\n${content.trim().slice(0, 10000)}`;

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
        max_tokens: 4000,
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
