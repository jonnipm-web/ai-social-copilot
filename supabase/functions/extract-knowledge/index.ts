import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY  = Deno.env.get("GROQ_API_KEY")  ?? "";
const GROQ_URL      = "https://api.groq.com/openai/v1/chat/completions";
const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")  ?? "";
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Limits
const FETCH_TIMEOUT_MS   = 10_000;
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024; // 2 MB
const MAX_REDIRECTS      = 3;
const GROQ_TIMEOUT_MS    = 30_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── SSRF guard ────────────────────────────────────────────────────────────────
// SEC-01: Full DNS-resolution + redirect-aware SSRF protection.

function isPrivateIp(ip: string): boolean {
  const v4 = ip.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const [, a, b, c] = v4.map(Number);
    if (a === 0)   return true;
    if (a === 10)  return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a === 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 0 && c === 0) return true;
    if (a === 192 && b === 168) return true;
    if (a === 198 && (b === 18 || b === 19)) return true;
    if (a >= 224) return true;
    return false;
  }
  const lc = ip.toLowerCase().replace(/^\[|\]$/g, "");
  if (lc === "::1" || lc === "::" || lc === "0:0:0:0:0:0:0:0" || lc === "0:0:0:0:0:0:0:1") return true;
  if (/^fe[89ab][0-9a-f]:/.test(lc)) return true;
  if (/^fc|^fd/.test(lc)) return true;
  if (/^ff/.test(lc)) return true;
  if (lc.startsWith("::ffff:")) return isPrivateIp(lc.slice(7));
  if (lc.startsWith("::ffff:0:")) return isPrivateIp(lc.slice(9));
  if (lc.startsWith("64:ff9b::")) return isPrivateIp(lc.slice(9));
  return false;
}

async function assertPublicHost(hostname: string): Promise<void> {
  const lc = hostname.toLowerCase();
  if (lc === "localhost" || lc === "0.0.0.0") {
    throw new Error("Host privado não permitido.");
  }
  if (!lc.includes(".") && !lc.startsWith("[")) {
    throw new Error("Hostname sem TLD não é permitido.");
  }
  if (["169.254.169.254", "metadata.google.internal", "metadata.internal"].includes(lc)) {
    throw new Error("Endpoint de metadados de nuvem não permitido.");
  }

  const ips: string[] = [];
  try {
    const a    = await Deno.resolveDns(hostname, "A").catch(() => []);
    const aaaa = await Deno.resolveDns(hostname, "AAAA").catch(() => []);
    ips.push(...a, ...aaaa);
  } catch { /* fallback to literal IP check below */ }

  for (const ip of ips) {
    if (isPrivateIp(ip)) {
      throw new Error("URL aponta para endereço IP privado ou reservado.");
    }
  }

  if (ips.length === 0 && /^[\d.:]+$/.test(lc)) {
    if (isPrivateIp(lc)) {
      throw new Error("Endereço IP privado ou reservado não permitido.");
    }
  }
}

async function validatePublicUrl(rawUrl: string): Promise<URL> {
  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error("URL inválida.");
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("Protocolo não permitido. Use http:// ou https://.");
  }
  await assertPublicHost(parsed.hostname);
  return parsed;
}

async function safeFetch(
  url: string,
  extraHeaders: Record<string, string> = {},
  redirectsLeft = MAX_REDIRECTS,
): Promise<Response> {
  if (redirectsLeft < 0) throw new Error("Muitos redirecionamentos.");
  await validatePublicUrl(url);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0", ...extraHeaders },
      redirect: "manual",
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }

  if (res.status >= 300 && res.status < 400) {
    const location = res.headers.get("Location");
    if (!location) throw new Error("Redirect sem cabeçalho Location.");
    const nextUrl = new URL(location, url).href;
    return safeFetch(nextUrl, extraHeaders, redirectsLeft - 1);
  }

  return res;
}

async function readLimitedBody(res: Response): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_RESPONSE_BYTES) {
      reader.cancel();
      throw new Error("Resposta muito grande. Limite de 2 MB excedido.");
    }
    chunks.push(value);
  }
  return new TextDecoder().decode(
    chunks.reduce((a, b) => { const m = new Uint8Array(a.length + b.length); m.set(a); m.set(b, a.length); return m; }, new Uint8Array()),
  );
}

async function fetchUrlContent(url: string): Promise<string> {
  // Google Docs → export as plain text
  const docsMatch = url.match(/docs\.google\.com\/document\/d\/([a-zA-Z0-9_-]+)/);
  if (docsMatch) {
    const exportUrl = `https://docs.google.com/document/d/${docsMatch[1]}/export?format=txt`;
    const res = await safeFetch(exportUrl);
    if (!res.ok) {
      throw new Error(
        `Google Doc inacessível (${res.status}). Verifique se está compartilhado como 'Qualquer pessoa com o link pode visualizar'.`,
      );
    }
    return await readLimitedBody(res);
  }

  // Google Drive file → download attempt
  const driveMatch = url.match(/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (driveMatch) {
    const fileId = driveMatch[1];
    const exportUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;
    const res = await safeFetch(exportUrl);
    if (!res.ok) {
      throw new Error(
        `Arquivo do Google Drive inacessível. Use um Google Doc e compartilhe como 'Qualquer pessoa com o link'.`,
      );
    }
    const contentType = res.headers.get("content-type") ?? "";
    if (contentType.includes("text/html")) {
      throw new Error(
        `Não foi possível baixar o arquivo diretamente. Converta para Google Docs e use o link de edição.`,
      );
    }
    const text = await readLimitedBody(res);
    if (text.trim().length < 20) {
      throw new Error("Arquivo vazio ou binário. Use um Google Doc com o link de edição.");
    }
    return text;
  }

  // Generic public URL → fetch HTML and strip tags
  const res = await safeFetch(url);
  if (!res.ok) {
    throw new Error(`URL inacessível (${res.status}). Verifique se o endereço é público.`);
  }

  const contentType = res.headers.get("content-type") ?? "";
  if (contentType.includes("text/html") || contentType.includes("text/plain")) {
    const raw = await readLimitedBody(res);
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

// ── Quota check ───────────────────────────────────────────────────────────────
async function checkAndIncrementUsage(authHeader: string): Promise<boolean> {
  if (!SUPABASE_URL) return true;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);
    let res: Response;
    try {
      res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/check_and_increment_usage`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader,
          "apikey": SUPABASE_ANON,
        },
        body: "{}",
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) {
      console.error("Quota RPC error:", res.status);
      return true;
    }
    const allowed = await res.json();
    return allowed === true;
  } catch (e) {
    console.error("Quota check failed:", e);
    return true;
  }
}

// ── System prompt ─────────────────────────────────────────────────────────────
const SYSTEM_PROMPT = `Você é um especialista em marketing digital, SEO, monetização e criação de conteúdo.

Analise profundamente o texto fornecido e retorne SOMENTE um JSON válido, sem markdown, sem explicações.

O JSON deve ter exatamente esta estrutura:

{
  "summary": "resumo em 3-5 frases do conteúdo",
  "detected_title": "título detectado do conteúdo",
  "detected_type": "tipo detectado: livro | ebook | artigo | post | site | produto | marca | projeto | curso | texto",
  "detected_niche": "nicho principal detectado automaticamente",
  "detected_audience": "público-alvo detectado automaticamente",
  "detected_language": "idioma detectado: pt-BR | en-US | es",
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
    "seo": { "strengths": ["..."], "weaknesses": ["..."], "improvements": ["..."] },
    "adsense": { "strengths": ["..."], "weaknesses": ["..."], "improvements": ["..."] },
    "amazon_kdp": { "strengths": ["..."], "weaknesses": ["..."], "improvements": ["..."] },
    "linkedin": { "strengths": ["..."], "weaknesses": ["..."], "improvements": ["..."] },
    "social": { "strengths": ["..."], "weaknesses": ["..."], "improvements": ["..."] }
  }
}

Todos os scores são inteiros de 0 a 100.
Retorne apenas o JSON. Nenhum texto antes ou depois.`;

// ── Main handler ──────────────────────────────────────────────────────────────
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
          JSON.stringify({ error: fetchErr instanceof Error ? fetchErr.message : "Erro ao acessar URL." }),
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

    // Server-side quota enforcement (SEC-01)
    const authHeader = req.headers.get("Authorization") ?? "";
    const allowed = await checkAndIncrementUsage(authHeader);
    if (!allowed) {
      return new Response(
        JSON.stringify({ error: "Cota mensal esgotada. Faça upgrade do plano para continuar." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const niche    = body.niche           ? `\nNicho: ${body.niche}`                     : "";
    const audience = body.target_audience ? `\nAudiência-alvo: ${body.target_audience}`  : "";
    const language = body.language ?? "pt-BR";

    const userMessage = `Idioma de análise: ${language}${niche}${audience}\n\nConteúdo para analisar:\n\n${content.trim().slice(0, 10000)}`;

    // Groq call with retry + timeout
    let groqRes: Response | null = null;
    let lastGroqErr = "";
    for (let attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await new Promise((r) => setTimeout(r, attempt * 1500));
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);
        try {
          groqRes = await fetch(GROQ_URL, {
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
            signal: controller.signal,
          });
        } finally {
          clearTimeout(timer);
        }
        if (groqRes.ok) break;
        lastGroqErr = await groqRes.text().catch(() => `status ${groqRes!.status}`);
        console.error(`Groq attempt ${attempt + 1} failed:`, lastGroqErr);
      } catch (fetchErr) {
        lastGroqErr = String(fetchErr);
        console.error(`Groq fetch error attempt ${attempt + 1}:`, fetchErr);
        groqRes = null;
      }
    }

    if (!groqRes || !groqRes.ok) {
      console.error("Groq final error after retries:", lastGroqErr);
      return new Response(
        JSON.stringify({ error: "Serviço de IA temporariamente indisponível. Tente novamente em instantes." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const groqData = await groqRes.json();
    const rawText = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error("JSON não encontrado na resposta Groq");
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
