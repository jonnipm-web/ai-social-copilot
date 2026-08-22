import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// SEC-01: Hard limits to prevent resource exhaustion
export const MAX_CONTENT_LENGTH_BYTES = 10 * 1024 * 1024; // 10 MB header check
export const MAX_BASE64_CHARS         = 10 * 1024 * 1024; // 10 MB base64 string
export const MAX_DECODED_BYTES        = 8  * 1024 * 1024; // 8 MB decoded file
export const MAX_ARCHIVE_EXPANSION    = 20 * 1024 * 1024; // 20 MB unzipped total
export const MAX_EXTRACTED_TEXT_CHARS = 100_000;          // 100 KB text output

// Magic bytes for supported types
const PDF_MAGIC  = [0x25, 0x50, 0x44, 0x46]; // %PDF
const DOCX_MAGIC = [0x50, 0x4B, 0x03, 0x04]; // PK\x03\x04 (ZIP)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Validation helpers ────────────────────────────────────────────────────────

export function checkMagicBytes(bytes: Uint8Array, magic: number[]): boolean {
  if (bytes.length < magic.length) return false;
  return magic.every((b, i) => bytes[i] === b);
}

export function validateFileType(bytes: Uint8Array, declaredType: string): void {
  const lower = declaredType.toLowerCase();
  if (lower === "pdf" || lower === "application/pdf") {
    if (!checkMagicBytes(bytes, PDF_MAGIC)) {
      throw new Error("Arquivo declarado como PDF não possui assinatura PDF válida.");
    }
    return;
  }
  if (
    lower === "docx" ||
    lower === "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ) {
    if (!checkMagicBytes(bytes, DOCX_MAGIC)) {
      throw new Error("Arquivo declarado como DOCX não possui assinatura ZIP válida.");
    }
    return;
  }
  // TXT: no magic bytes required
}

// ── Extraction helpers ────────────────────────────────────────────────────────

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function extractFromPdf(bytes: Uint8Array): Promise<string> {
  try {
    const { default: pdfParse } = await import("npm:pdf-parse/lib/pdf-parse.js");
    const buffer = Buffer.from(bytes);
    const data = await pdfParse(buffer);
    return data.text ?? "";
  } catch {
    // Fallback: regex-based extraction for simple PDFs
    const latin = new TextDecoder("latin1").decode(bytes);
    const blocks: string[] = [];
    const btEtMatches = latin.match(/BT[\s\S]*?ET/g) ?? [];
    for (const block of btEtMatches) {
      const strings = block.match(/\(([^)\\]*(?:\\.[^)\\]*)*)\)/g) ?? [];
      for (const s of strings) {
        const text = s.slice(1, -1)
          .replace(/\\n/g, " ").replace(/\\r/g, "").replace(/\\t/g, " ")
          .replace(/\\\\/g, "\\").replace(/\\([()])/g, "$1");
        if (text.trim().length > 0) blocks.push(text.trim());
      }
    }
    return blocks.join(" ").trim();
  }
}

async function extractFromDocx(bytes: Uint8Array): Promise<string> {
  try {
    const { unzipSync } = await import("npm:fflate");
    const unzipped = unzipSync(bytes);

    // Zip bomb check: total decompressed size
    let totalSize = 0;
    for (const key of Object.keys(unzipped)) {
      totalSize += unzipped[key].byteLength;
      if (totalSize > MAX_ARCHIVE_EXPANSION) {
        throw new Error("Arquivo DOCX excede o limite de expansão permitido.");
      }
    }

    const docXmlBytes = unzipped["word/document.xml"];
    if (!docXmlBytes) throw new Error("word/document.xml não encontrado no DOCX.");
    const xml = new TextDecoder("utf-8").decode(docXmlBytes);
    const text = xml
      .replace(/<w:br[^>]*\/>/g, "\n")
      .replace(/<w:p[ >][^>]*>/g, "\n")
      .replace(/<[^>]+>/g, "")
      .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"').replace(/&#x27;/g, "'")
      .replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim();
    return text;
  } catch (e) {
    if (e instanceof Error && e.message.includes("limite")) throw e;
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

    // SEC-01: Reject oversized requests before reading body
    const contentLength = Number(req.headers.get("Content-Length") ?? 0);
    if (contentLength > MAX_CONTENT_LENGTH_BYTES) {
      return new Response(
        JSON.stringify({ error: "Arquivo muito grande. Limite máximo: 10 MB." }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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

    // SEC-01: Limit base64 string length before decoding
    if (typeof file_base64 !== "string" || file_base64.length > MAX_BASE64_CHARS) {
      return new Response(
        JSON.stringify({ error: "Arquivo muito grande. Limite máximo: 10 MB." }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // SEC-01: Validate base64 before decoding
    let bytes: Uint8Array;
    try {
      bytes = base64ToUint8Array(file_base64);
    } catch {
      return new Response(
        JSON.stringify({ error: "Arquivo base64 inválido ou corrompido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // SEC-01: Check decoded size
    if (bytes.byteLength > MAX_DECODED_BYTES) {
      return new Response(
        JSON.stringify({ error: "Arquivo decodificado muito grande. Limite máximo: 8 MB." }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // SEC-01: Validate magic bytes to detect type mismatch
    const lower = file_type.toLowerCase();
    const isSupportedType =
      lower === "pdf" || lower === "application/pdf" ||
      lower === "docx" || lower === "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ||
      lower === "txt" || lower === "text/plain";

    if (!isSupportedType) {
      return new Response(
        JSON.stringify({ error: `Tipo de arquivo não suportado: ${file_type}. Use PDF, DOCX ou TXT.` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    try {
      validateFileType(bytes, file_type);
    } catch (magicErr) {
      return new Response(
        JSON.stringify({ error: magicErr instanceof Error ? magicErr.message : "Tipo de arquivo inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let text = "";

    switch (lower) {
      case "txt":
      case "text/plain":
        text = extractFromTxt(bytes);
        break;
      case "pdf":
      case "application/pdf":
        text = await extractFromPdf(bytes);
        break;
      case "docx":
      case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        text = await extractFromDocx(bytes);
        break;
    }

    text = text.trim();

    // SEC-01: Truncate extremely large extracted text instead of returning unbounded output
    if (text.length > MAX_EXTRACTED_TEXT_CHARS) {
      text = text.slice(0, MAX_EXTRACTED_TEXT_CHARS);
    }

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
    // SEC-01: Never leak internal error details to the caller
    console.error("Erro inesperado em process-file:", e);
    return new Response(
      JSON.stringify({ error: "Erro ao processar arquivo. Tente novamente." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
