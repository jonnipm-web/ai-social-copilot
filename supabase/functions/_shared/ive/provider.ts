/**
 * Intelligence provider boundary (IVE-INTELLIGENCE-CORE-01).
 *
 * The core talks to a generation interface, never to a vendor URL. Today's
 * only implementation is Groq (same model and endpoint every AI function
 * already uses — no vendor migration). Failures are normalized so no
 * upstream error text (which can echo prompt fragments) reaches the client.
 * The API key is read server-side only.
 */

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface GenerationResult {
  text: string;
  model: string;
}

export class ProviderUnavailableError extends Error {
  constructor(readonly kind: 'config' | 'http' | 'empty' | 'network', readonly status?: number) {
    super(`provider unavailable: ${kind}${status ? ` ${status}` : ''}`);
  }
}

export interface IntelligenceProvider {
  readonly name: string;
  generate(messages: ChatMessage[], opts?: { maxTokens?: number; temperature?: number }): Promise<GenerationResult>;
}

export class GroqChatProvider implements IntelligenceProvider {
  readonly name = 'groq';
  constructor(
    private readonly model = 'openai/gpt-oss-120b',
    private readonly url = 'https://api.groq.com/openai/v1/chat/completions',
  ) {}

  async generate(messages: ChatMessage[], opts: { maxTokens?: number; temperature?: number } = {}): Promise<GenerationResult> {
    const key = Deno.env.get('GROQ_API_KEY');
    if (!key) throw new ProviderUnavailableError('config');
    let res: Response;
    try {
      res = await fetch(this.url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: this.model,
          temperature: opts.temperature ?? 0.4,
          max_completion_tokens: opts.maxTokens ?? 800,
          response_format: { type: 'text' },
          messages,
        }),
      });
    } catch {
      throw new ProviderUnavailableError('network');
    }
    if (!res.ok) {
      await res.body?.cancel();
      throw new ProviderUnavailableError('http', res.status);
    }
    const data = await res.json().catch(() => null);
    const text = data?.choices?.[0]?.message?.content;
    if (typeof text !== 'string' || text.trim().length === 0) throw new ProviderUnavailableError('empty');
    return { text, model: this.model };
  }
}
