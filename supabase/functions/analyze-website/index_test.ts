/**
 * Testes de auth para analyze-website Edge Function — IVE-COMMERCIAL-AUTH-01.
 * Prova que nenhuma chamada ao Groq (nem ao site analisado) ocorre antes de
 * uma sessão de usuário real ser resolvida, e que o caso que motivou a
 * auditoria do Codex (Bearer bem-formado mas não-sessão, ex: chave anon)
 * é rejeitado.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/analyze-website/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient } from '../_shared/auth.ts';

let groqCalled = false;

const FAKE_ANALYSIS = {
  title: 't', description: 'd', main_topics: [], detected_niche: 'n', detected_audience: 'a',
  score_website: 50, score_adsense: 50, score_seo: 50, score_monetization: 50,
  strengths: [], weaknesses: [], critical_issues: [],
  seo_analysis: { title_quality: '', content_quality: '', keyword_usage: '', improvements: [] },
  adsense_analysis: { has_privacy_policy: true, has_about_page: true, has_contact: true, content_quality_for_adsense: '', improvements: [] },
  monetization_opportunities: [],
  monetization_plan: { affiliate_potential: '', info_product_potential: '', saas_potential: '', ecommerce_potential: '' },
  quick_wins: [], plan_7_days: [], plan_30_days: [], article_ideas: [], content_ideas: [], commercial_opportunities: [],
  persona_training: { tone: '', vocabulary: [], values: [], communication_style: '' },
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input: string | URL | Request, options?: RequestInit): Promise<Response> => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (url.includes('groq.com')) {
    groqCalled = true;
    return new Response(JSON.stringify({
      choices: [{ message: { content: JSON.stringify(FAKE_ANALYSIS) } }],
    }), { status: 200 });
  }
  // Fake website content — long enough to pass the >=100 char guard.
  return new Response(`<html><body>${'Conteúdo de teste. '.repeat(20)}</body></html>`, {
    status: 200,
    headers: { 'content-type': 'text/html' },
  });
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

// safeFetch validates the hostname's resolved IP via Deno.resolveDns before
// ever reaching our fetch mock — same technique as _shared/safe_fetch_test.ts,
// so no live DNS/network call happens here either.
function stubDns(ip: string) {
  const original = Deno.resolveDns;
  // deno-lint-ignore no-explicit-any
  (Deno as any).resolveDns = (_hostname: string, type: 'A' | 'AAAA') =>
    Promise.resolve(type === 'A' ? [ip] : []);
  // deno-lint-ignore no-explicit-any
  return () => { (Deno as any).resolveDns = original; };
}

function req(body: unknown, headers: Record<string, string> = { Authorization: 'Bearer test-session-jwt' }): Request {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test('AW-1: sem Authorization -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req({ url: 'https://example.com' }, {}), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('AW-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req({ url: 'https://example.com' }, { Authorization: 'Bearer anon-public-key' }), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('AW-3: usuário autenticado válido -> Groq é chamado, retorna 200', async () => {
  groqCalled = false;
  const restoreDns = stubDns('93.184.216.34'); // public IP, same convention as safe_fetch_test.ts
  try {
    const res = await handler(req({ url: 'https://public.example' }), validUserClient);
    assertEquals(res.status, 200);
    assertEquals(groqCalled, true);
    const data = await res.json();
    assertEquals(data.title, 't');
  } finally {
    restoreDns();
  }
});
