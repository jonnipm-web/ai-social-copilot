import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { project_name, opportunities } = await req.json();

    const oppLines = ((opportunities ?? []) as Array<{ title: string; description: string }>)
      .map((o) => `• ${o.title}: ${o.description}`)
      .join('\n') || 'Sem oportunidades listadas';

    const userPrompt = `Projeto: ${project_name}

Oportunidades identificadas para este projeto:
${oppLines}

Crie EXATAMENTE 5 ações concretas, priorizadas e executáveis para avançar nas oportunidades acima.
Retorne APENAS JSON válido no formato abaixo, sem texto adicional:

{
  "actions": [
    {
      "title": "Verbo + objeto concreto (ex: Criar landing page de captura)",
      "action_type": "tarefa",
      "priority": 1,
      "impact_score": 80,
      "effort_score": 35,
      "roi_score": 72
    }
  ]
}

Regras:
- Gere exatamente 5 ações
- priority: 1 (mais urgente/importante) a 5 (menos urgente)
- impact_score: impacto esperado no negócio, 0-100
- effort_score: esforço necessário, 0-100 (menor = mais fácil de executar)
- roi_score: retorno sobre investimento esperado, 0-100
- Tipos válidos para action_type: tarefa, conteúdo, campanha, produto, análise`;

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
              'Você é um gerente de projetos especialista em marketing digital. Responda APENAS com JSON válido, sem markdown, sem texto antes ou depois do JSON.',
          },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.6,
        max_tokens: 1024,
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

    if (!parsed.actions) parsed.actions = [];

    return Response.json(parsed, { headers: corsHeaders });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500, headers: corsHeaders });
  }
});
