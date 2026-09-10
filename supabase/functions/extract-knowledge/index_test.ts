/**
 * Testes de auth para extract-knowledge Edge Function — IVE-COMMERCIAL-AUTH-01.
 * Mesmo contrato provado em analyze-website/context-copilot: nenhuma chamada
 * ao Groq antes de uma sessão de usuário real ser resolvida.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/extract-knowledge/index_test.ts
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
      choices: [{ message: { content: '{"summary":"s","detected_title":"t","detected_type":"artigo","detected_niche":"n","detected_audience":"a","detected_language":"pt-BR","keywords_primary":[],"keywords_secondary":[],"keywords_longtail":[],"entities":[],"topics":[],"content_pillars":[],"audience_pain_points":[],"audience_desires":[],"commercial_angles":[],"ctas":[],"campaign_ideas":[],"post_ideas":[],"article_ideas":[],"seo_opportunities":[],"adsense_opportunities":[],"amazon_kdp_opportunities":[],"score_seo":50,"score_adsense":50,"score_amazon_kdp":50,"score_linkedin":50,"score_social":50,"score_opportunity":50,"score_hotmart":50,"score_shopify":50,"hotmart_data":{"product_name":"","promise":"","price_range":"","format":"","upsell":""},"shopify_data":{"product_name":"","short_description":"","categories":[],"price_range":""},"persona_training":{"tone":"","vocabulary":[],"values":[],"communication_style":""},"score_details":{"seo":{"strengths":[],"weaknesses":[],"improvements":[]},"adsense":{"strengths":[],"weaknesses":[],"improvements":[]},"amazon_kdp":{"strengths":[],"weaknesses":[],"improvements":[]},"linkedin":{"strengths":[],"weaknesses":[],"improvements":[]},"social":{"strengths":[],"weaknesses":[],"improvements":[]}}}' } }],
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

const CONTENT_BODY = { content: 'Conteúdo de teste com mais de vinte caracteres para passar na validação mínima.' };

Deno.test('EK-1: sem Authorization -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(CONTENT_BODY, {}), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('EK-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(CONTENT_BODY, { Authorization: 'Bearer anon-public-key' }), validUserClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('EK-3: usuário autenticado válido -> Groq é chamado, retorna 200', async () => {
  groqCalled = false;
  const res = await handler(req(CONTENT_BODY), validUserClient);
  assertEquals(res.status, 200);
  assertEquals(groqCalled, true);
  const data = await res.json();
  assertEquals(data.detected_title, 't');
});
