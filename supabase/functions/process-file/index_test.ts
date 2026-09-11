/**
 * Testes para process-file Edge Function — IVE-PROCESS-FILE-CLOSURE.
 * Prova o auth gate (mesmo contrato das outras 16 funções) e as novas
 * validações de tipo/tamanho antes de qualquer parsing.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/process-file/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient } from '../_shared/auth.ts';

// DENO_TESTING deve estar definido antes desta linha para suprimir serve().
const { handler } = await import('./index.ts');

const validUserClient: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      if (token === 'test-session-jwt') return { data: { user: { id: 'u1', email: 'u1@example.com' } }, error: null };
      return { data: { user: null }, error: { message: 'invalid token' } };
    },
  },
};

function req(body: unknown, headers: Record<string, string> = { Authorization: 'Bearer test-session-jwt' }): Request {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

const LONG_TXT = 'Conteúdo de teste. '.repeat(10); // > 20 chars

Deno.test('PF-1: sem Authorization -> 401', async () => {
  const res = await handler(req({ file_base64: 'dGVzdGU=', file_type: 'txt' }, {}), validUserClient);
  assertEquals(res.status, 401);
});

Deno.test('PF-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401', async () => {
  const res = await handler(req({ file_base64: 'dGVzdGU=', file_type: 'txt' }, { Authorization: 'Bearer anon-public-key' }), validUserClient);
  assertEquals(res.status, 401);
});

Deno.test('PF-3: tipo não suportado -> 400, rejeitado antes do decode', async () => {
  const res = await handler(req({ file_base64: 'dGVzdGU=', file_type: 'exe' }), validUserClient);
  assertEquals(res.status, 400);
});

Deno.test('PF-4: arquivo maior que o limite -> 413, rejeitado antes do decode', async () => {
  const oversized = 'A'.repeat(8 * 1024 * 1024 + 1);
  const res = await handler(req({ file_base64: oversized, file_type: 'txt' }), validUserClient);
  assertEquals(res.status, 413);
});

Deno.test('PF-5: usuário autenticado válido, TXT dentro do limite -> 200', async () => {
  const b64 = btoa(LONG_TXT);
  const res = await handler(req({ file_base64: b64, file_type: 'txt' }), validUserClient);
  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(typeof data.text, 'string');
  assertEquals(data.text.length > 20, true);
});

Deno.test('PF-6: campos obrigatórios ausentes -> 400', async () => {
  const res = await handler(req({ file_type: 'txt' }), validUserClient);
  assertEquals(res.status, 400);
});

// ── PF-7/PF-8: proteção contra zip bomb no DOCX (achado do Codex Gate) ──────
// unzipSync() sem filtro descomprime TODAS as entradas do arquivo antes de
// eu escolher a que preciso -- um DOCX malicioso (é só um ZIP) com
// compressão extrema poderia estourar memória bem além do limite de ~6MB
// *comprimidos* checado antes do decode. O filtro do fflate roda ANTES de
// descomprimir e recebe o tamanho declarado (originalSize), então dá pra
// rejeitar sem nunca inflar os bytes.

Deno.test('PF-7: DOCX legítimo e pequeno continua funcionando (regressão do filtro)', async () => {
  const { zipSync, strToU8 } = await import('npm:fflate');
  const xml = `<w:document><w:body><w:p><w:r><w:t>${LONG_TXT}</w:t></w:r></w:p></w:body></w:document>`;
  const zipped = zipSync({ 'word/document.xml': strToU8(xml) });
  const b64 = btoa(String.fromCharCode(...zipped));
  const res = await handler(req({ file_base64: b64, file_type: 'docx' }), validUserClient);
  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(typeof data.text, 'string');
  assertEquals(data.text.length > 20, true);
});

// ── PF-9: caminho PDF (IVE-COMMERCIAL-AUTH-IMPORT-GATE) ─────────────────────
// extractFromPdf() nunca tinha um teste que de fato passasse bytes de PDF
// pelo handler -- só PF-3 (tipo não suportado, nem chega a tentar extrair).
// O código está inalterado desde a missão anterior, mas "inalterado" não é
// o mesmo que "coberto por teste"; isto fecha essa lacuna.
function buildMinimalPdfWithText(text: string): Uint8Array {
  // PDF minimalista o bastante para extractFromPdf() (que só procura blocos
  // BT...ET com operadores Tj de texto simples via regex, sem parsear a
  // estrutura real de objetos/xref) extrair o texto -- não é um PDF
  // estruturalmente válido de verdade, mas exercita o mesmo formato de
  // stream de conteúdo que um PDF real gerado por qualquer editor produz.
  const escaped = text.replace(/([()\\])/g, '\\$1');
  const content = `1 0 obj\n<< >>\nstream\nBT /F1 12 Tf 72 712 Td (${escaped}) Tj ET\nendstream\nendobj\n%%EOF`;
  return new TextEncoder().encode(content);
}

Deno.test('PF-9: PDF simples com texto extraível via operadores BT/Tj/ET -> 200, texto extraído', async () => {
  const pdfText = 'Texto de teste extraido de um PDF minimo valido para o parser.';
  const bytes = buildMinimalPdfWithText(pdfText);
  const b64 = btoa(String.fromCharCode(...bytes));
  const res = await handler(req({ file_base64: b64, file_type: 'pdf' }), validUserClient);
  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(typeof data.text, 'string');
  assertEquals(data.text.includes('Texto de teste extraido'), true);
});

Deno.test('PF-10: PDF sem nenhum bloco BT/ET reconhecível (ex: só imagem escaneada) -> 422, mensagem pede colar texto manualmente', async () => {
  const bytes = new TextEncoder().encode('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF');
  const b64 = btoa(String.fromCharCode(...bytes));
  const res = await handler(req({ file_base64: b64, file_type: 'pdf' }), validUserClient);
  assertEquals(res.status, 422);
});

Deno.test('PF-8: DOCX no formato de zip bomb (originalSize declarado gigante) é rejeitado, não descomprimido', async () => {
  const { zipSync, strToU8 } = await import('npm:fflate');
  // Dados repetidos comprimem quase de graça -- 25MB reais de zeros vira um
  // zip de poucos KB, provando que o ataque é barato de montar.
  const huge = new Uint8Array(25 * 1024 * 1024); // 25MB > MAX_DOCX_XML_SIZE (20MB)
  const zipped = zipSync({ 'word/document.xml': huge }, { level: 9 });
  // O zip comprimido em si também precisa caber no teto de ~6MB de base64
  // já testado em PF-4 -- confirma que o ataque passaria por aquele teto.
  const b64 = btoa(String.fromCharCode(...zipped));
  const start = performance.now();
  const res = await handler(req({ file_base64: b64, file_type: 'docx' }), validUserClient);
  const elapsedMs = performance.now() - start;
  // Deve falhar (arquivo "vazio"/não encontrado, não os 25MB de zeros) e
  // fazer isso rápido -- nunca chegou a inflar os 25MB.
  assertEquals(res.status, 500);
  assertEquals(elapsedMs < 2000, true);
});
