import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em análise competitiva e inteligência de mercado digital.

Identifique os principais concorrentes para o projeto/nicho fornecido e retorne SOMENTE um JSON válido.

Se houver contexto adicional do projeto, use nicho, público, proposta de valor e estágio para identificar concorrentes mais precisos e relevantes — não liste concorrentes genéricos.

O JSON deve ter exatamente esta estrutura:

{
  "competitors": [
    {
      "name": "Nome do Concorrente",
      "url": "https://exemplo.com",
      "type": "direct",
      "similarity_score": 85,
      "authority_score": 72,
      "relevance_score": 90,
      "description": "descrição breve do concorrente e por que é relevante para este projeto específico",
      "strengths": ["ponto forte 1", "ponto forte 2"],
      "weaknesses": ["ponto fraco 1", "ponto fraco 2"],
      "opportunities": ["oportunidade de diferenciação 1", "oportunidade 2"]
    }
  ]
}

Regras:
- type: "direct" (mesmo nicho/produto), "indirect" (nicho adjacente) ou "aspirational" (líder de mercado referência)
- similarity_score, authority_score, relevance_score: 0-100
- Retorne entre 5 e 10 concorrentes
- Misture concorrentes diretos, indiretos e aspiracionais
- Todas as respostas em português brasileiro
- URLs devem ser URLs reais e plausíveis`;

type ContextSnapshot = Record<string, unknown>;

function buildContextBlock(snapshot: ContextSnapshot | null | undefined): string {
  if (!snapshot) return "";
  const lines: string[] = ["\n--- CONTEXTO DO PROJETO ---"];
  const project = snapshot.project as Record<string, string> | undefined;
  if (project?.name) {
    lines.push(`Projeto: ${project.name}`);
    if (project.description) lines.push(`Descrição: ${project.description}`);
    if (project.niche) lines.push(`Nicho: ${project.niche}`);
    if (project.audience) lines.push(`Público-alvo: ${project.audience}`);
    if (project.value_proposition) lines.push(`Proposta de valor: ${project.value_proposition}`);
    if (project.positioning) lines.push(`Posicionamento: ${project.positioning}`);
    if (project.stage) lines.push(`Estágio: ${project.stage}`);
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
    const userMessage = `Input/nicho/projeto: ${input}${contextBlock}\nIdentifique os concorrentes e retorne o JSON.`;

    const groqResponse = await callGroq({
      model: "llama-3.3-70b-versatile",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMessage },
      ],
      temperature: 0.4,
      max_tokens: 3000,
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
