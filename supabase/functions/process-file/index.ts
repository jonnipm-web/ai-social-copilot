import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { AuthClient, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPPORTED_TYPES = new Set([
  "txt", "text/plain",
  "pdf", "application/pdf",
  "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]);

// ~8MB of base64 (~6MB decoded) -- generous for a text-bearing document,
// bounded well below anything that would make regex/unzip parsing itself
// a meaningful resource cost. Checked on the raw base64 string, before
// any decode/parse work happens.
const MAX_BASE64_LENGTH = 8 * 1024 * 1024;

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// IVE-PROCESS-FILE-CLOSURE: previously tried `npm:pdf-parse` first, falling
// back to this regex extraction on failure. `pdf-parse` transitively pulls
// in pdfjs-dist + a native @napi-rs/canvas renderer -- 91MB of dependencies
// (confirmed via `deno info`) purely to support PDF *rendering*, which
// text extraction never needed. That bundle size is the actual, confirmed
// reason this function couldn't go through the canonical deploy route.
// This was always just the fallback path for simple, uncompressed-text
// PDFs -- now the only path. Complex/compressed/scanned PDFs will extract
// little or nothing, same as before when pdf-parse also failed on them;
// the existing <20-char-minimum check below already asks the user to
// paste text manually in that case.
function extractFromPdf(bytes: Uint8Array): string {
  const latin = new TextDecoder("latin1").decode(bytes);
  const blocks: string[] = [];

  const btEtMatches = latin.match(/BT[\s\S]*?ET/g) ?? [];
  for (const block of btEtMatches) {
    const strings = block.match(/\(([^)\\]*(?:\\.[^)\\]*)*)\)/g) ?? [];
    for (const s of strings) {
      const text = s.slice(1, -1)
        .replace(/\\n/g, " ")
        .replace(/\\r/g, "")
        .replace(/\\t/g, " ")
        .replace(/\\\\/g, "\\")
        .replace(/\\([()])/g, "$1");
      if (text.trim().length > 0) blocks.push(text.trim());
    }
  }

  return blocks.join(" ").trim();
}

async function extractFromDocx(bytes: Uint8Array): Promise<string> {
  try {
    const { unzipSync } = await import("npm:fflate");
    const unzipped = unzipSync(bytes);
    const docXmlBytes = unzipped["word/document.xml"];
    if (!docXmlBytes) throw new Error("word/document.xml não encontrado");
    const xml = new TextDecoder("utf-8").decode(docXmlBytes);
    const text = xml
      .replace(/<w:br[^>]*\/>/g, "\n")
      .replace(/<w:p[ >][^>]*>/g, "\n")
      .replace(/<[^>]+>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#x27;/g, "'")
      .replace(/[ \t]+/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
    return text;
  } catch {
    throw new Error("Não foi possível extrair texto do DOCX. Verifique se o arquivo não está corrompido.");
  }
}

function extractFromTxt(bytes: Uint8Array): string {
  try {
    return new TextDecoder("utf-8").decode(bytes);
  } catch {
    return new TextDecoder("latin1").decode(bytes);
  }
}

// Exportado para testes unitários. Em produção, serve() chama esta função.
export async function handler(req: Request, authClient?: AuthClient): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // IVE-PROCESS-FILE-CLOSURE — mesmo limite de identidade real usado nas
  // outras 16 funções. Falha fechado antes de qualquer parsing.
  try {
    await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Método não permitido." }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json().catch(() => null);
    if (!body?.file_base64 || !body?.file_type) {
      return new Response(
        JSON.stringify({ error: "Campos obrigatórios: file_base64, file_type." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { file_base64, file_type } = body;

    // Type and size are checked BEFORE any decode/parse work.
    const normalizedType = String(file_type).toLowerCase();
    if (!SUPPORTED_TYPES.has(normalizedType)) {
      return new Response(
        JSON.stringify({ error: `Tipo de arquivo não suportado: ${file_type}. Use PDF, DOCX ou TXT.` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (typeof file_base64 !== "string" || file_base64.length > MAX_BASE64_LENGTH) {
      return new Response(
        JSON.stringify({ error: "Arquivo muito grande. O limite é de aproximadamente 6 MB." }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const bytes = base64ToUint8Array(file_base64);

    let text = "";

    switch (normalizedType) {
      case "txt":
      case "text/plain":
        text = extractFromTxt(bytes);
        break;
      case "pdf":
      case "application/pdf":
        text = extractFromPdf(bytes);
        break;
      case "docx":
      case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        text = await extractFromDocx(bytes);
        break;
    }

    text = text.trim();

    if (text.length < 20) {
      return new Response(
        JSON.stringify({ error: "Não foi possível extrair texto do arquivo. Tente copiar e colar o texto manualmente." }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ text, char_count: text.length }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("Erro inesperado:", e);
    return new Response(
      JSON.stringify({ error: `Erro ao processar arquivo: ${e instanceof Error ? e.message : "Erro interno"}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
}

if (Deno.env.get("DENO_TESTING") !== "1") {
  serve((req) => handler(req));
}
