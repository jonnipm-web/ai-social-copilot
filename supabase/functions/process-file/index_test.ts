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
