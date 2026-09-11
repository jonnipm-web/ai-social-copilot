import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { AuthError, resolveAuthenticatedUser, unauthorizedResponse } from "../_shared/auth.ts";
import { normalizeLanguage, withLanguageDirective } from "../_shared/language.ts";
import { quotaBlockedResponse, refundQuota, reserveQuota } from "../_shared/quota.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em SEO, arquitetura de conteúdo e estratégia de clusters de conteúdo para sites e blogs.

Com base no input e na keyword principal fornecidos, crie uma estrutura completa de Content Cluster e retorne SOMENTE um JSON válido.

O JSON deve ter exatamente esta estrutura:

{
  "clusters": [
    {
      "name": "Nome do Cluster",
      "pillar_topic": "Tópico pilar do cluster",
      "description": "Descrição do cluster",
      "keywords": ["kw1", "kw2", "kw3"],
      "subtopics": ["subtópico 1", "subtópico 2", "subtópico 3"]
    }
  ],
  "silos": [
    {
      "name": "Nome do Silo",
      "url_structure": "/categoria/subcategoria",
      "topics": ["tópico 1", "tópico 2"]
    }
  ],
  "articles": [
    {
      "title": "Título do Artigo",
      "type": "pillar",
      "cluster": "Nome do Cluster",
      "target_keyword": "keyword alvo",
      "secondary_keywords": ["kw secundária 1", "kw secundária 2"],
      "search_intent": "informacional",
      "priority": 1,
      "estimated_words": 2500
    }
  ],
  "editorial_roadmap": [
    {
      "month": 1,
      "articles": ["Título 1", "Título 2"],
      "focus": "Objetivo do mês"
    }
  ],
  "seo_structure": {
    "internal_linking_strategy": "Descrição da estratégia de links internos",
    "url_taxonomy": "Estrutura de URLs recomendada",
    "cornerstone_content": ["Artigo pilar 1", "Artigo pilar 2"],
    "content_gaps_to_fill": ["Gap 1", "Gap 2"]
  }
}

Regras:
- Crie pelo menos 3 clusters temáticos
- Mínimo de 15 artigos no array articles (mix de pillar pages e supporting content)
- O editorial_roadmap deve cobrir 6 meses
- type dos artigos: "pillar", "supporting", "landing_page", "comparison"
- search_intent: "informacional", "navegacional", "transacional", "comercial"
- Foque em relevância semântica e autoridade tópica`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // IVE-COMMERCIAL-AUTH-01 — exige sessão de usuário real antes do Groq. Falha fechado.
  try {
    await resolveAuthenticatedUser(req);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  let quotaReserved = false;
  try {
    const { input, main_keyword, language: rawLanguage } = await req.json();
    const language = normalizeLanguage(rawLanguage);

    if (!input || !main_keyword) {
      return new Response(JSON.stringify({ error: "Input e main_keyword são obrigatórios" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quota = await reserveQuota(req);
    if (!quota.allowed) return quotaBlockedResponse(corsHeaders, quota);
    quotaReserved = true;

    const groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-120b",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: withLanguageDirective(language, `Projeto/nicho: ${input}\nKeyword principal: ${main_keyword}\n\nCrie a estrutura completa de Content Cluster para esse projeto e retorne o JSON.`),
          },
        ],
        temperature: 0.4,
        max_completion_tokens: 6000,
      }),
    });

    if (!groqResponse.ok) {
      const errText = await groqResponse.text();
      throw new Error(`Groq error ${groqResponse.status}: ${errText}`);
    }

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    if (quotaReserved) await refundQuota(req);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
