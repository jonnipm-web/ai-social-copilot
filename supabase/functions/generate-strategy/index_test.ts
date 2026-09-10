/**
 * Testes de auth para generate-strategy Edge Function — IVE-COMMERCIAL-AUTH-01.
 * Mesmo contrato provado nas demais: nenhuma chamada ao Groq antes de uma
 * sessão de usuário real ser resolvida.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/generate-strategy/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient } from '../_shared/auth.ts';

let groqCalled = false;

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input: string | URL | Request): Promise<Response> => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (url.includes('groq.com')) {
    groqCalled = true;
    return new Response(JSON.stringify({
      choices: [{ message: { content: '{"strategic_summary":"s","target_audience":{"primary":"","secondary":"","age_range":"","interests":[]},"pain_points":[],"desires":[],"positioning":"","differentials":[],"value_proposition":"","recommended_channels":[],"funnel":{"awareness":"","consideration":"","conversion":"","retention":""},"cta_primary":"","cta_secondary":"","commercial_opportunities":[],"priority_keywords":[],"content_calendar_hint":"","growth_plan":{"month_1":"","month_2":"","month_3":"","kpis":[]},"quick_wins":[]}' } }],
    }), { status: 200 });
  }
  return originalFetch(input);
};

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

const BODY = { title: 'Projeto Teste', content: 'Conteúdo de teste.' };

Deno.test('GS-1: sem Authorization -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(BODY, {}), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('GS-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(BODY, { Authorization: 'Bearer anon-public-key' }), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('GS-3: usuário autenticado válido -> Groq é chamado, retorna 200', async () => {
  groqCalled = false;
  const res = await handler(req(BODY), validUserClient);
  assertEquals(res.status, 200);
  assertEquals(groqCalled, true);
  const data = await res.json();
  assertEquals(data.strategic_summary, 's');
});
