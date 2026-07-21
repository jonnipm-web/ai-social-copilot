/**
 * ive-agent-runner — AI Provider Abstraction
 *
 * Abstração desacoplada de provedor de IA.
 * Provider primário: OpenAI (gpt-4o por padrão).
 * Fallback: Groq (llama-3.3-70b-versatile) — compatível via API OpenAI.
 *
 * API keys exclusivamente via env vars do servidor.
 * Nunca expostas ao cliente Flutter.
 */

import type { AICompletionRequest, AICompletionResponse, AIMessage, AIToolCall } from './types.ts';

// ── Interface ──────────────────────────────────────────────────────────────────

export interface AIProvider {
  complete(request: AICompletionRequest, signal?: AbortSignal): Promise<AICompletionResponse>;
  readonly model: string;
  readonly providerName: string;
}

// ── OpenAI-Compatible Base (shared fetch logic) ────────────────────────────────

async function callOpenAICompatible(
  url:    string,
  apiKey: string,
  model:  string,
  req:    AICompletionRequest,
  signal?: AbortSignal,
): Promise<AICompletionResponse> {
  const body: Record<string, unknown> = {
    model,
    temperature: req.temperature ?? 0.35,
    max_tokens:  req.max_tokens  ?? 1200,
    messages:    req.messages,
  };

  if (req.tools && req.tools.length > 0) {
    body.tools       = req.tools;
    body.tool_choice = 'auto';
  }

  const res = await fetch(url, {
    method:  'POST',
    signal,
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const status = res.status;
    // Nunca loga o body completo — pode conter dados sensíveis
    throw new AIProviderError(
      `HTTP ${status} from AI provider`,
      status >= 500 ? 'SERVER_ERROR' : 'CLIENT_ERROR',
      status,
    );
  }

  const data = await res.json() as Record<string, unknown>;
  const choice = (data.choices as Array<Record<string, unknown>>)?.[0];
  if (!choice) throw new AIProviderError('Empty response from AI provider', 'EMPTY_RESPONSE');

  const message    = choice.message    as Record<string, unknown>;
  const rawContent = message?.content  as string | null ?? null;
  const rawCalls   = message?.tool_calls as Array<Record<string, unknown>> | null ?? null;

  const tool_calls: AIToolCall[] | null = rawCalls?.map(tc => ({
    id:       tc.id as string ?? '',
    type:     'function' as const,
    function: {
      name:      (tc.function as Record<string, unknown>)?.name as string ?? '',
      arguments: (tc.function as Record<string, unknown>)?.arguments as string ?? '{}',
    },
  })) ?? null;

  const usage = data.usage as Record<string, number> | undefined;

  return {
    content:       rawContent,
    tool_calls:    tool_calls?.length ? tool_calls : null,
    model:         data.model as string ?? model,
    finish_reason: choice.finish_reason as string | null ?? null,
    usage: usage ? {
      prompt_tokens:     usage.prompt_tokens     ?? 0,
      completion_tokens: usage.completion_tokens ?? 0,
      total_tokens:      usage.total_tokens      ?? 0,
    } : undefined,
  };
}

// ── OpenAI Provider ────────────────────────────────────────────────────────────

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';

export class OpenAIProvider implements AIProvider {
  readonly model:        string;
  readonly providerName = 'openai';

  constructor(
    private readonly apiKey: string,
    model?: string,
  ) {
    this.model = model ?? 'gpt-4o';
  }

  async complete(req: AICompletionRequest, signal?: AbortSignal): Promise<AICompletionResponse> {
    return callOpenAICompatible(OPENAI_URL, this.apiKey, this.model, req, signal);
  }
}

// ── Groq Provider (fallback — OpenAI-compatible API, supports tool calling) ────

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

export class GroqProvider implements AIProvider {
  readonly model:        string;
  readonly providerName = 'groq';

  constructor(
    private readonly apiKey: string,
    model?: string,
  ) {
    this.model = model ?? 'llama-3.3-70b-versatile';
  }

  async complete(req: AICompletionRequest, signal?: AbortSignal): Promise<AICompletionResponse> {
    return callOpenAICompatible(GROQ_URL, this.apiKey, this.model, req, signal);
  }
}

// ── Factory ────────────────────────────────────────────────────────────────────

export class AIProviderError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'AIProviderError';
  }
}

/**
 * Cria o provider correto baseado em env vars do servidor.
 * Nunca usa secrets do cliente.
 *
 * Ordem de preferência:
 * 1. OPENAI_API_KEY → OpenAIProvider (model: OPENAI_MODEL ou gpt-4o)
 * 2. GROQ_API_KEY   → GroqProvider  (model: llama-3.3-70b-versatile)
 *
 * Lança erro se nenhuma key estiver configurada.
 */
export function createAIProvider(): AIProvider {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (openaiKey) {
    const model = Deno.env.get('OPENAI_MODEL') ?? 'gpt-4o';
    return new OpenAIProvider(openaiKey, model);
  }

  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (groqKey) {
    return new GroqProvider(groqKey);
  }

  throw new Error('Nenhuma API key de AI configurada. Configure OPENAI_API_KEY ou GROQ_API_KEY nas secrets do Edge Function.');
}

// ── Message helpers ────────────────────────────────────────────────────────────

export function systemMsg(content: string): AIMessage {
  return { role: 'system', content };
}

export function userMsg(content: string): AIMessage {
  return { role: 'user', content };
}

export function assistantMsg(content: string | null, tool_calls?: AIToolCall[]): AIMessage {
  return { role: 'assistant', content, tool_calls: tool_calls ?? undefined };
}

export function toolResultMsg(tool_call_id: string, content: string): AIMessage {
  return { role: 'tool', tool_call_id, content };
}
