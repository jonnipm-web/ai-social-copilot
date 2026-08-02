import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em análise de gaps de mercado, SEO, conteúdo e monetização digital.

Identifique todas as lacunas e oportunidades não exploradas para o projeto/nicho fornecido e retorne SOMENTE um JSON válido.

Se houver contexto adicional do projeto, use-o para identificar gaps específicos ao estágio, nicho e público já definidos — seja preciso e não genérico.

O JSON deve ter exatamente esta estrutura:

{
  "content_gaps": [
    "Lacuna de conteúdo 1 — o que está faltando e por quê importa",
    "Lacuna de conteúdo 2",
    "até 8 gaps de conteúdo"
  ],
  "seo_gaps": [
    "Gap de SEO 1 — palavras-chave não exploradas, estrutura, etc",
    "Gap de SEO 2",
    "até 8 gaps de SEO"
  ],
  "authority_gaps": [
    "Gap de autoridade 1 — backlinks, parcerias, menções que faltam",
    "até 6 gaps de autoridade"
  ],
  "monetization_gaps": [
    "Gap de monetização 1 — fontes de receita não exploradas",
    "até 6 gaps de monetização"
  ],
  "product_gaps": [
    "Gap de produto/serviço 1 — o que o mercado quer mas não tem",
    "até 6 gaps de produto"
  ]
}

Regras:
- Seja específico e acionável em cada gap
- Priorize oportunidades com maior potencial de retorno
- Use o contexto do projeto para personalizar os gaps ao nicho e público específicos
- Todas as respostas em português brasileiro`;

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
    if (project.monetization) lines.push(`Monetização: ${project.monetization}`);
    if (project.stage) lines.push(`Estágio: ${project.stage}`);
  }
  const knowledge = snapshot.knowledge_context as Array<{ title: string; summary: string }> | undefined;
  if (knowledge?.length) {
    lines.push("", "Conhecimentos registrados:");
    for (const k of knowledge.slice(0, 5)) {
      lines.push(`• ${k.title}: ${k.summary}`);
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
    const userMessage = `Input/nicho/projeto: ${input}${contextBlock}\nIdentifique todos os gaps e retorne o JSON.`;

    const groqResponse = await callGroq({
      model: "llama-3.3-70b-versatile",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMessage },
      ],
      temperature: 0.3,
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
