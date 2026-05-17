import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const GROQ_API_KEY            = Deno.env.get("GROQ_API_KEY") ?? "";
const SUPABASE_URL            = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GROQ_URL  = "https://api.groq.com/openai/v1/chat/completions";
const TEXT_MODEL   = "llama-3.3-70b-versatile";
const VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";
const FREE_LIMIT   = 10;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const JSON_SCHEMA = `{
  "improved_text": "texto otimizado, claro e envolvente",
  "professional_version": "versão com tom profissional e formal",
  "casual_version": "versão descontraída com linguagem natural",
  "persuasive_version": "versão persuasiva com call-to-action",
  "comment_reply": "sugestão de resposta a comentários sobre este post",
  "suggested_hashtags": ["#hashtag1", "#hashtag2", "#hashtag3", "#hashtag4", "#hashtag5"],
  "platforms": {
    "linkedin": "versão para LinkedIn: profissional, parágrafos curtos, sem emojis excessivos, até 3000 chars",
    "instagram": "versão para Instagram: visual, emojis estratégicos, quebras de linha, até 2200 chars",
    "twitter_x": "versão para Twitter/X: impactante e direta, MÁXIMO 280 caracteres"
  },
  "scores": { "clarity": 8.5, "impact": 7.0, "engagement": 9.0 }
}`;

const REQUIRED_FIELDS = [
  "improved_text", "professional_version", "casual_version",
  "persuasive_version", "comment_reply", "suggested_hashtags",
  "platforms", "scores",
];

function buildTextPrompt(nicheHint: string): string {
  return `Você é um especialista em comunicação digital e redes sociais.
${nicheHint ? `\n${nicheHint}\n` : ""}
Receba um texto e retorne SOMENTE um JSON válido, sem markdown, sem explicações:

${JSON_SCHEMA}

- "suggested_hashtags": exatamente 5 hashtags relevantes ao conteúdo e nicho
- "platforms.twitter_x": OBRIGATORIAMENTE menor que 280 caracteres
- As notas avaliam o texto ORIGINAL (0–10, uma casa decimal)
Retorne apenas o JSON.`;
}

function buildVisionPrompt(nicheHint: string): string {
  return `Você é um especialista em comunicação digital com capacidade de análise visual.
${nicheHint ? `\n${nicheHint}\n` : ""}
Analise a imagem e crie sugestões de posts para redes sociais. Retorne SOMENTE um JSON válido:

${JSON_SCHEMA}

- "improved_text": legenda principal que valorize a imagem
- "suggested_hashtags": exatamente 5 hashtags relevantes à imagem e nicho
- "platforms.twitter_x": OBRIGATORIAMENTE menor que 280 caracteres
Retorne apenas o JSON.`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    if (req.method !== "POST") return json({ error: "Método não permitido." }, 405);

    // ── Autenticação JWT ──────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) return json({ error: "Não autorizado." }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) return json({ error: "Não autorizado." }, 401);

    // ── Rate limiting ─────────────────────────────────────────
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("is_pro")
      .eq("user_id", user.id)
      .maybeSingle();

    const isPro  = profile?.is_pro ?? false;
    const limit  = isPro ? 999999 : FREE_LIMIT;

    const { data: usage } = await supabase.rpc("check_and_increment_usage", {
      p_user_id: user.id,
      p_limit:   limit,
    });

    if (!usage?.allowed) {
      return json({
        error: `Limite de ${FREE_LIMIT} gerações gratuitas atingido este mês.`,
        limit_reached: true,
        count: usage?.count ?? FREE_LIMIT,
        limit: FREE_LIMIT,
      }, 429);
    }

    // ── Validação do body ─────────────────────────────────────
    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Corpo da requisição inválido." }, 400);

    const hasImage = typeof body.image_base64 === "string" && body.image_base64.length > 0;
    const hasText  = typeof body.text === "string" && body.text.trim().length >= 10;
    const nicheHint = typeof body.niche_hint === "string" ? body.niche_hint : "";

    if (!hasImage && !hasText) {
      return json({ error: "Envie uma imagem ou texto com pelo menos 10 caracteres." }, 400);
    }

    // ── Chamada ao Groq ───────────────────────────────────────
    let groqBody: Record<string, unknown>;

    if (hasImage) {
      const mediaType  = (body.image_media_type as string) || "image/jpeg";
      const imageUrl   = `data:${mediaType};base64,${body.image_base64}`;
      const userContent: unknown[] = [{ type: "image_url", image_url: { url: imageUrl } }];
      if (hasText) userContent.push({ type: "text", text: `Contexto: ${body.text.trim()}` });
      groqBody = {
        model: VISION_MODEL,
        messages: [
          { role: "system", content: buildVisionPrompt(nicheHint) },
          { role: "user",   content: userContent },
        ],
        temperature: 0.7,
        max_tokens: 2000,
      };
    } else {
      groqBody = {
        model: TEXT_MODEL,
        messages: [
          { role: "system", content: buildTextPrompt(nicheHint) },
          { role: "user",   content: body.text.trim() },
        ],
        temperature: 0.7,
        max_tokens: 2000,
      };
    }

    const groqRes = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify(groqBody),
    });

    if (!groqRes.ok) {
      console.error("Groq error:", await groqRes.text());
      return json({ error: "Falha ao processar com a IA. Tente novamente." }, 502);
    }

    const groqData = await groqRes.json();
    const rawText  = groqData.choices?.[0]?.message?.content ?? "";
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);

    if (!jsonMatch) {
      console.error("JSON não encontrado:", rawText);
      return json({ error: "Resposta inválida da IA. Tente novamente." }, 502);
    }

    const result = JSON.parse(jsonMatch[0]);

    for (const field of REQUIRED_FIELDS) {
      if (!(field in result)) {
        return json({ error: `Campo '${field}' ausente na resposta da IA.` }, 502);
      }
    }

    return json(result);
  } catch (e) {
    console.error("Erro inesperado:", e);
    return json({ error: "Erro interno. Tente novamente." }, 500);
  }
});
