import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
    // Fallback: regex-based text extraction for simple PDFs
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
    if (!body?.file_base64 || !body?.file_type) {
      return new Response(
        JSON.stringify({ error: "Campos obrigatórios: file_base64, file_type." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { file_base64, file_type } = body;
    const bytes = base64ToUint8Array(file_base64);

    let text = "";

    switch (file_type.toLowerCase()) {
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
      default:
        return new Response(
          JSON.stringify({ error: `Tipo de arquivo não suportado: ${file_type}. Use PDF, DOCX ou TXT.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
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
});
