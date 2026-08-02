import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em descoberta de nichos de mercado rentáveis para criadores de conteúdo e empreendedores digitais.

Mapeie os melhores nichos, sub-nichos e micro-nichos para o projeto/input fornecido e retorne SOMENTE um JSON válido.

Se houver contexto adicional do projeto (nicho já identificado, público, estágio), use para mapear nichos adjacentes, especializações e oportunidades de expansão — não repita o nicho principal genérico.

O JSON deve ter exatamente esta estrutura:

{
  "niches": [
    {
      "name": "Nome do Nicho/Sub-nicho/Micro-nicho",
      "level": "niche",
      "description": "descrição detalhada do nicho e por que é promissor para este projeto",
      "competition_score": 65,
      "potential_score": 88,
      "growth_score": 75,
      "monetization_score": 82,
      "difficulty_score": 55,
      "trend_score": 70,
      "overall_score": 80,
      "keywords": ["palavra-chave 1", "palavra-chave 2", "palavra-chave 3", "até 6 keywords"],
      "monetization_methods": ["método 1", "método 2", "método 3"],
      "why": "por que este nicho tem alto potencial agora para este projeto específico"
    }
  ]
}

Regras:
- level: "niche" (mercado amplo), "sub_niche" (segmento específico) ou "micro_niche" (segmento muito específico)
- Todos os scores: 0-100
- overall_score: média ponderada dos demais scores
- Retorne exatamente 10 nichos/sub-nichos/micro-nichos rankeados por overall_score decrescente
- Misture os 3 níveis: pelo menos 3 de cada tipo
- Todas as respostas em português brasileiro`;

type ContextSnapshot = Record<string, unknown>;

function buildContextBlock(snapshot: ContextSnapshot | null | undefined): string {
  if (!snapshot) return "";
  const lines: string[] = ["\n--- CONTEXTO DO PROJETO ---"];
  const project = snapshot.project as Record<string, string> | undefined;
  if (project?.name) {
    lines.push(`Projeto: ${project.name}`);
    if (project.description) lines.push(`Descrição: ${project.description}`);
    if (project.niche) lines.push(`Nicho principal atual: ${project.niche}`);
    if (project.audience) lines.push(`Público-alvo: ${project.audience}`);
    if (project.monetization) lines.push(`Monetização: ${project.monetization}`);
    if (project.stage) lines.push(`Estágio: ${project.stage}`);
  }
  const prevAnalyses = snapshot.previous_analyses as Array<{ niche?: string; score: number; date: string }> | undefined;
  if (prevAnalyses?.length) {
    lines.push("", "Análises anteriores:");
    for (const a of prevAnalyses.slice(0, 2)) {
      lines.push(`• Nicho: ${a.niche ?? "N/A"} | Score: ${a.score}`);
    }
  }
  const personas = snapshot.personas as string[] | undefined;
  if (personas?.length) {
    lines.push("", `Personas: ${personas.join(", ")}`);
  }
  lines.push("--- FIM DO CONTEXTO ---\n");
  return lines.join("\n");
}

async function callGroq(body: object, retries = 1): Promise<Response> {
  const response = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GROQ_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (response.status === 429 && retries > 0) {
    const retryAfter = parseInt(response.headers.get("Retry-After") ?? "10", 10);
    await new Promise((r) => setTimeout(r, Math.min(retryAfter * 1000, 30_000)));
    return callGroq(body, retries - 1);
  }
  return response;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { input, context_snapshot } = await req.json();

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const contextBlock = buildContextBlock(context_snapshot as ContextSnapshot);
    const userMessage = `Input/nicho/projeto: ${input}${contextBlock}\nMapeie os top 10 nichos/sub-nichos/micro-nichos e retorne o JSON.`;

    const groqResponse = await callGroq({
      model: "llama-3.3-70b-versatile",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMessage },
      ],
      temperature: 0.4,
      max_tokens: 4000,
    });

    if (!groqResponse.ok) {
      if (groqResponse.status === 429) {
        throw new Error("[RATE_LIMITED] Limite de requisições atingido. Aguarde alguns segundos.");
      }
      const errBody = await groqResponse.text();
      throw new Error(`Groq error ${groqResponse.status}: ${errBody}`);
    }

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const msg = String(err);
    const status = msg.includes("[RATE_LIMITED]") ? 429 : 500;
    return new Response(JSON.stringify({ error: msg }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
