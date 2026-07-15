import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { message, screen_name, context, history } = await req.json();

    const ctx = context ?? {};

    // ── Build context block ──────────────────────────────────────────────────
    const lines: string[] = [`TELA ATUAL: ${screen_name}`];

    if (ctx.project) {
      lines.push(`\n## PROJETO ATUAL\nNome: ${ctx.project.name}\nDescrição: ${ctx.project.description || '—'}\nTipo: ${ctx.project.type || '—'}\nStatus: ${ctx.project.status || '—'}`);
    }

    if (ctx.scores) {
      const s = ctx.scores;
      lines.push(`\n## SCORES DO ECOSSISTEMA\nEcosystem Score: ${s.ecosystem}/100\nOportunidade: ${s.opportunity}/100\nStrategic Fit: ${s.strategic_fit}/100\nROI Score: ${s.roi}/100\nMomentum: ${s.momentum}/100\nMarket Score: ${s.market}/100\nExecution Score: ${s.execution}/100\nRecomendação: ${s.recommendation}`);
    }

    if (ctx.opportunities?.length) {
      const opps = (ctx.opportunities as Array<{title:string;finalScore:number;status:string;opportunityType:string}>)
        .slice(0, 5)
        .map(o => `• ${o.title} [score=${o.finalScore}, status=${o.status}, tipo=${o.opportunityType}]`)
        .join('\n');
      lines.push(`\n## OPORTUNIDADES (${ctx.opportunities.length} total)\n${opps}`);
    }

    if (ctx.actions?.length) {
      const acts = (ctx.actions as Array<{title:string;status:string;priority:number;impactScore:number;effortScore:number}>)
        .slice(0, 5)
        .map(a => `• ${a.title} [status=${a.status}, impacto=${a.impactScore}, esforço=${a.effortScore}]`)
        .join('\n');
      lines.push(`\n## AÇÕES (${ctx.actions.length} total)\n${acts}`);
    }

    if (ctx.documents?.length) {
      const docs = (ctx.documents as Array<{title:string;status:string}>)
        .slice(0, 5)
        .map(d => `• ${d.title} [${d.status}]`)
        .join('\n');
      lines.push(`\n## DOCUMENTOS INDEXADOS (${ctx.documents.length} total)\n${docs}`);
    }

    if (ctx.personas?.length) {
      const prs = (ctx.personas as Array<{name:string;niche:string;learningScore:number}>)
        .map(p => `• ${p.name} [nicho=${p.niche || '—'}, aprendizado=${p.learningScore}pts]`)
        .join('\n');
      lines.push(`\n## PERSONAS (${ctx.personas.length} total)\n${prs}`);
    }

    if (ctx.revenue) {
      lines.push(`\n## PLANO DE RECEITA\nMensal moderado: R$${ctx.revenue.monthly_moderate?.toFixed(0) ?? '0'}\nAnual moderado: R$${ctx.revenue.annual_moderate?.toFixed(0) ?? '0'}`);
    }

    if (ctx.market) {
      lines.push(`\n## MERCADO\nNicho: ${ctx.market.niche || '—'}\nCompetição: ${ctx.market.competition || '—'}\nCrescimento: ${ctx.market.growth || 0}pts\nMarket Score: ${ctx.market.market_score || 0}/100`);
    }

    const contextBlock = lines.join('\n');

    // ── Build conversation history ──────────────────────────────────────────
    const historyMessages = ((history ?? []) as Array<{role:string;content:string}>)
      .slice(-10)
      .map(h => ({ role: h.role, content: h.content }));

    // ── System prompt ───────────────────────────────────────────────────────
    const systemPrompt = `Você é o AI Social Copilot, um assistente estratégico integrado à plataforma de gestão de portfólio de projetos digitais.

Seu papel é analisar os dados do contexto atual e responder às perguntas do usuário com precisão, clareza e ação.

${contextBlock}

## SUAS CAPACIDADES

**EXPLICAR**: Explique por que, como, origem e evidências de qualquer score, recomendação ou dado.
**SIMULAR**: Simule cenários, impacto no score e impacto financeiro com base nos dados reais.
**RECOMENDAR**: Sugira próximas ações, prioridades e identifique riscos com base nos dados.
**EXECUTAR**: Quando solicitado, sugira criação de ações, aprovação de oportunidades, geração de roadmap.

## REGRAS DE RESPOSTA

1. Sempre baseie sua resposta nos dados do contexto fornecido acima.
2. Seja direto e objetivo — resposta máxima: 4 parágrafos curtos.
3. Use dados numéricos do contexto sempre que possível.
4. Ao final de TODA resposta, inclua EXATAMENTE este bloco JSON (não inclua mais nada após ele):

\`\`\`json
{
  "sources": ["lista das fontes usadas (ex: Ecosystem Score, OpportunityLab, Ações)"],
  "confidence": 75,
  "entities": ["nomes de projetos/personas/oportunidades mencionados"],
  "action_suggestion": null
}
\`\`\`

Quando sugerir uma ação executável, substitua action_suggestion por:
\`\`\`json
{
  "action_suggestion": {
    "type": "create_action",
    "label": "Criar ação: [título]",
    "data": { "title": "título", "action_type": "tarefa", "priority": 80 }
  }
}
\`\`\`
Tipos permitidos: "create_action", "approve_opportunity", "create_project", "generate_roadmap"

Responda sempre em Português do Brasil.`;

    // ── Groq call ────────────────────────────────────────────────────────────
    const groqRes = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        temperature: 0.4,
        max_tokens: 800,
        response_format: { type: 'text' },
        messages: [
          { role: 'system', content: systemPrompt },
          ...historyMessages,
          { role: 'user', content: message },
        ],
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      throw new Error(`Groq error ${groqRes.status}: ${errText}`);
    }

    const groqData = await groqRes.json();
    const rawContent: string = groqData.choices?.[0]?.message?.content ?? '';

    // ── Parse metadata block ──────────────────────────────────────────────
    let sources: string[] = [];
    let confidence = 70;
    let entities: string[] = [];
    let actionSuggestion = null;
    let answerText = rawContent;

    const jsonMatch = rawContent.match(/```json\s*([\s\S]*?)```/);
    if (jsonMatch) {
      try {
        const meta = JSON.parse(jsonMatch[1]);
        sources         = meta.sources ?? [];
        confidence      = meta.confidence ?? 70;
        entities        = meta.entities ?? [];
        actionSuggestion = meta.action_suggestion ?? null;
        // Remove the JSON block from the answer text
        answerText = rawContent.replace(/```json[\s\S]*?```/, '').trim();
      } catch (_) { /* keep defaults */ }
    }

    return new Response(
      JSON.stringify({
        answer:            answerText,
        sources,
        confidence,
        entities,
        action_suggestion: actionSuggestion,
        timestamp:         new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
