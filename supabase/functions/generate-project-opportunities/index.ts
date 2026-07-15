import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { project_name, project_description, project_type, documents, market_context } =
      await req.json();

    const docLines = ((documents ?? []) as Array<{ title: string; content: string }>)
      .slice(0, 6)
      .map((d) => `• ${d.title}: ${(d.content ?? '').substring(0, 400)}`)
      .join('\n') || 'Sem documentos específicos listados';

    const userPrompt = `Projeto: ${project_name}
Descrição: ${project_description || 'Não informada'}
Tipo: ${project_type || 'Não especificado'}
${market_context ? `Contexto de mercado: ${market_context}` : ''}

Documentos indexados (resumo):
${docLines}

Analise este projeto e gere EXATAMENTE 3 oportunidades estratégicas concretas e um roadmap.
Retorne APENAS JSON válido no formato abaixo, sem texto adicional:

{
  "opportunities": [
    {
      "title": "título curto e específico da oportunidade",
      "description": "descrição de 2 frases: o que é e por que gera valor",
      "opportunity_type": "expansão",
      "market_score": 75,
      "revenue_score": 65,
      "competition_score": 45,
      "synergy_score": 80,
      "strategic_fit": 70,
      "final_score": 67
    }
  ],
  "roadmap": {
    "short_term": ["ação executável em 30 dias", "outra ação 30 dias"],
    "medium_term": ["meta para 90 dias", "outra meta 90 dias"],
    "long_term": ["visão de 12 meses", "outra visão anual"]
  }
}

Tipos válidos para opportunity_type: expansão, novo produto, novo nicho, afiliado, SaaS, ebook, curso, assinatura
Scores devem ser inteiros entre 0 e 100.
final_score = média ponderada dos demais scores.`;

    const resp = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('GROQ_API_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'system',
            content:
              'Você é um especialista em estratégia de negócios digitais. Responda APENAS com JSON válido, sem markdown, sem texto antes ou depois do JSON.',
          },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.7,
        max_tokens: 2048,
        response_format: { type: 'json_object' },
      }),
    });

    if (!resp.ok) {
      const err = await resp.text();
      return Response.json({ error: `Groq error: ${err}` }, { status: 502, headers: corsHeaders });
    }

    const groq = await resp.json();
    const content = groq.choices?.[0]?.message?.content ?? '{}';

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(content);
    } catch {
      return Response.json(
        { error: 'JSON inválido retornado pelo modelo', raw: content },
        { status: 502, headers: corsHeaders },
      );
    }

    // Ensure at least an empty structure
    if (!parsed.opportunities) parsed.opportunities = [];
    if (!parsed.roadmap) parsed.roadmap = { short_term: [], medium_term: [], long_term: [] };

    return Response.json(parsed, { headers: corsHeaders });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500, headers: corsHeaders });
  }
});
