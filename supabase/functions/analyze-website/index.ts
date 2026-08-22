import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY  = Deno.env.get("GROQ_API_KEY")  ?? "";
const GROQ_URL      = "https://api.groq.com/openai/v1/chat/completions";
const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")  ?? "";
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Limits
const FETCH_TIMEOUT_MS     = 10_000;
const MAX_RESPONSE_BYTES   = 2 * 1024 * 1024; // 2 MB
const MAX_REDIRECTS        = 3;
const GROQ_TIMEOUT_MS      = 30_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── SSRF guard ────────────────────────────────────────────────────────────────
// SEC-01: Full DNS-resolution + redirect-aware SSRF protection.
// Replaces the regex-only hostname check from SEC-00A.

function isPrivateIp(ip: string): boolean {
  // IPv4
  const v4 = ip.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const [, a, b, c] = v4.map(Number);
    if (a === 0)   return true;                    // 0.0.0.0/8
    if (a === 10)  return true;                    // 10.0.0.0/8
    if (a === 100 && b >= 64 && b <= 127) return true; // 100.64.0.0/10 CGNAT
    if (a === 127) return true;                    // 127.0.0.0/8
    if (a === 169 && b === 254) return true;       // 169.254.0.0/16
    if (a === 172 && b >= 16 && b <= 31) return true;  // 172.16.0.0/12
    if (a === 192 && b === 0 && c === 0) return true;  // 192.0.0.0/24
    if (a === 192 && b === 168) return true;       // 192.168.0.0/16
    if (a === 198 && (b === 18 || b === 19)) return true; // 198.18.0.0/15
    if (a >= 224) return true;                     // multicast + reserved
    return false;
  }

  // IPv6
  const lc = ip.toLowerCase().replace(/^\[|\]$/g, "");
  if (lc === "::1" || lc === "::" || lc === "0:0:0:0:0:0:0:0" || lc === "0:0:0:0:0:0:0:1") return true;
  if (/^fe[89ab][0-9a-f]:/.test(lc)) return true; // fe80::/10 link-local
  if (/^fc|^fd/.test(lc)) return true;             // fc00::/7 ULA
  if (/^ff/.test(lc)) return true;                 // ff00::/8 multicast
  // IPv4-mapped and IPv4-compatible
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
  // Explicit block for well-known metadata endpoints
  if (["169.254.169.254", "metadata.google.internal", "metadata.internal"].includes(lc)) {
    throw new Error("Endpoint de metadados de nuvem não permitido.");
  }

  // Resolve DNS — reject if any returned IP is private
  const ips: string[] = [];
  try {
    const a    = await Deno.resolveDns(hostname, "A").catch(() => []);
    const aaaa = await Deno.resolveDns(hostname, "AAAA").catch(() => []);
    ips.push(...a, ...aaaa);
  } catch {
    // If DNS resolution itself fails (NXDOMAIN, etc.) let the fetch fail naturally
  }

  for (const ip of ips) {
    if (isPrivateIp(ip)) {
      throw new Error("URL aponta para endereço IP privado ou reservado.");
    }
  }

  // If resolveDns returned nothing (e.g. env without DNS access), also check if
  // the hostname itself looks like a bare IP literal
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
      headers: { "User-Agent": "Mozilla/5.0 (compatible; AIAnalyzer/1.0)", ...extraHeaders },
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

async function fetchWebsiteContent(url: string): Promise<string> {
  const res = await safeFetch(url, { "Accept": "text/html,application/xhtml+xml" });

  if (!res.ok) {
    throw new Error(`Site inacessível (HTTP ${res.status}).`);
  }
  const contentType = res.headers.get("content-type") ?? "";
  if (!contentType.includes("text/html") && !contentType.includes("text/plain")) {
    throw new Error("Tipo de conteúdo não suportado. A URL deve apontar para uma página HTML.");
  }

  const raw = await readLimitedBody(res);
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
    throw new Error("Conteúdo do site muito curto para análise.");
  }
  return text.slice(0, 12000);
}

// ── Quota check ───────────────────────────────────────────────────────────────
// SEC-01: Server-side quota enforcement via atomic RPC.
// Falls back to permissive on DB error to avoid breaking the product on infra issues.
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
      return true; // permissive on unexpected DB error
    }
    const allowed = await res.json();
    return allowed === true;
  } catch (e) {
    console.error("Quota check failed:", e);
    return true;
  }
}

// ── System prompt ─────────────────────────────────────────────────────────────
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

    // Server-side quota enforcement (SEC-01)
    const authHeader = req.headers.get("Authorization") ?? "";
    const allowed = await checkAndIncrementUsage(authHeader);
    if (!allowed) {
      return new Response(
        JSON.stringify({ error: "Cota mensal esgotada. Faça upgrade do plano para continuar." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let content: string;
    try {
      content = await fetchWebsiteContent(url);
    } catch (fetchErr) {
      return new Response(
        JSON.stringify({ error: fetchErr instanceof Error ? fetchErr.message : "Erro ao acessar URL." }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userMessage = `URL analisada: ${url}\n\nConteúdo extraído do site:\n\n${content}`;

    const groqController = new AbortController();
    const groqTimer = setTimeout(() => groqController.abort(), GROQ_TIMEOUT_MS);
    let groqRes: Response;
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
          temperature: 0.4,
          max_tokens: 4000,
        }),
        signal: groqController.signal,
      });
    } finally {
      clearTimeout(groqTimer);
    }

    if (!groqRes.ok) {
      console.error("Groq error:", groqRes.status);
      return new Response(
        JSON.stringify({ error: "Falha ao processar com a IA. Tente novamente." }),
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
