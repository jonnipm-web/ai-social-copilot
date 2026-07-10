import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Você é um especialista em análise de gaps de mercado, SEO, conteúdo e monetização digital.

Identifique todas as lacunas e oportunidades não exploradas para o input fornecido e retorne SOMENTE um JSON válido.

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
- Todas as respostas em português brasileiro`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { input } = await req.json();

    if (!input) {
      return new Response(JSON.stringify({ error: "Input obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Input/nicho/projeto: ${input}\n\nIdentifique todos os gaps e retorne o JSON.` },
        ],
        temperature: 0.3,
        max_tokens: 3000,
      }),
    });

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content ?? "";

    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta inválida da IA");

    const result = JSON.parse(jsonMatch[0]);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
