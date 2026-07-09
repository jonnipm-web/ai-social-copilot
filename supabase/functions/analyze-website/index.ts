import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em SEO, AdSense, monetização de sites e marketing digital.

Analise o conteúdo do site fornecido e retorne SOMENTE um JSON válido, sem markdown, sem explicações.

O JSON deve ter exatamente esta estrutura:

{
  "title": "título detectado do site",
  "description": "descrição em 1-2 frases do site",
  "main_topics": ["tópico 1", "tópico 2", "até 5 tópicos principais"],
  "detected_niche": "nicho principal do site",
  "detected_audience": "público-alvo principal",
  "score_website": 72,
  "score_adsense": 65,
  "score_seo": 58,
  "score_monetization": 70,
  "strengths": ["ponto forte 1", "ponto forte 2", "até 5 pontos fortes"],
  "weaknesses": ["ponto fraco 1", "ponto fraco 2", "até 5 pontos fracos"],
  "critical_issues": ["problema crítico 1", "até 3 problemas críticos"],
  "seo_analysis": {
    "title_quality": "avaliação do título",
    "content_quality": "avaliação do conteúdo",
    "keyword_usage": "uso de palavras-chave",
    "improvements": ["melhoria SEO 1", "melhoria SEO 2", "até 5 melhorias"]
  },
  "adsense_analysis": {
    "has_privacy_policy": true,
    "has_about_page": true,
    "has_contact": true,
    "content_quality_for_adsense": "avaliação da qualidade para AdSense",
    "improvements": ["melhoria AdSense 1", "até 5 melhorias para aprovação AdSense"]
  },
  "monetization_opportunities": ["oportunidade 1", "oportunidade 2", "até 6 oportunidades"],
  "monetization_plan": {
    "affiliate_potential": "avaliação do potencial de afiliados",
    "info_product_potential": "potencial para produtos digitais",
    "saas_potential": "potencial SaaS",
    "ecommerce_potential": "potencial e-commerce"
  },
  "quick_wins": ["ação rápida 1", "ação rápida 2", "até 5 ações rápidas"],
  "plan_7_days": ["ação dia 1-7 número 1", "até 5 ações para 7 dias"],
  "plan_30_days": ["ação 30 dias 1", "até 5 ações para 30 dias"],
  "article_ideas": ["ideia de artigo 1", "até 6 ideias de artigos"],
  "content_ideas": ["ideia de conteúdo 1", "até 6 ideias de conteúdo"],
  "commercial_opportunities": ["oportunidade comercial 1", "até 5 oportunidades"],
  "persona_training": {
    "tone": "tom de voz detectado",
    "vocabulary": ["palavra 1", "palavra 2", "até 5 palavras do vocabulário"],
    "values": ["valor 1", "valor 2", "até 3 valores centrais"],
    "communication_style": "estilo de comunicação em 1 frase"
  }
}

Todos os scores são inteiros de 0 a 100.
score_website: qualidade geral do site (design, conteúdo, UX, velocidade percebida).
score_adsense: probabilidade de aprovação no Google AdSense (política, conteúdo, estrutura).
score_seo: otimização para mecanismos de busca.
score_monetization: potencial de monetização geral.
Retorne apenas o JSON. Nenhum texto antes ou depois.`;

async function fetchWebsiteContent(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; AIAnalyzer/1.0)",
      "Accept": "text/html,application/xhtml+xml",
    },
    redirect: "follow",
  });

  if (!res.ok) {
    throw new Error(`Site inacessível (HTTP ${res.status}). Verifique se a URL está correta e é pública.`);
  }

  const contentType = res.headers.get("content-type") ?? "";
  if (!contentType.includes("text/html") && !contentType.includes("text/plain")) {
    throw new Error("Tipo de conteúdo não suportado. A URL deve apontar para uma página HTML.");
  }

  const raw = await res.text();
  const text = raw
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<nav[\s\S]*?<\/nav>/gi, "")
    .replace(/<footer[\s\S]*?<\/footer>/gi, "")
    .replace(/<header[\s\S]*?<\/header>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (text.length < 100) {
    throw new Error("Conteúdo do site muito curto para análise. O site pode ser JavaScript-heavy ou estar bloqueado.");
  }

  return text.slice(0, 12000);
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
    if (!body || typeof body.url !== "string") {
      return new Response(
        JSON.stringify({ error: "Campo 'url' obrigatório." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const url = body.url.trim();
    if (!url.startsWith("http")) {
      return new Response(
        JSON.stringify({ error: "URL inválida. Deve começar com http:// ou https://" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let content: string;
    try {
      content = await fetchWebsiteContent(url);
    } catch (fetchErr) {
      return new Response(
        JSON.stringify({ error: String(fetchErr instanceof Error ? fetchErr.message : fetchErr) }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userMessage = `URL analisada: ${url}

Conteúdo extraído do site:

${content}`;

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
        temperature: 0.4,
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
