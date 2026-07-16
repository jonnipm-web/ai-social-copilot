import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const {
      scenario,        // string: descrição do cenário a simular
      ecosystem,       // { healthScore, projectCount, pendingActions, pendingOpportunities }
      projects,        // Array<{ name, ecosystemScore, executionScore, opportunityScore }>
      target,          // optional { type: 'project'|'opportunity'|'action', name: string }
    } = await req.json();

    const projectsBlock = (projects ?? [])
      .slice(0, 8)
      .map((p: { name: string; ecosystemScore: number; executionScore: number; opportunityScore: number }) =>
        `• ${p.name}: ecosystem=${p.ecosystemScore}/100, execução=${p.executionScore}/100, oportunidade=${p.opportunityScore}/100`)
      .join('\n');

    const eco = ecosystem ?? {};

    const systemPrompt = `Você é o Simulador de Decisões da IVE™, uma IA executiva especializada em análise de impacto para portfólios digitais.

## DADOS ATUAIS DO ECOSSISTEMA
Saúde geral: ${eco.healthScore ?? 0}/100
Total de projetos: ${eco.projectCount ?? 0}
Ações pendentes: ${eco.pendingActions ?? 0}
Oportunidades pendentes: ${eco.pendingOpportunities ?? 0}

## PROJETOS
${projectsBlock || '— sem dados de projetos —'}

${eco.target ? `## FOCO DA SIMULAÇÃO\nTipo: ${target?.type ?? '—'}\nNome: ${target?.name ?? '—'}` : ''}

## SUA TAREFA
Simule o impacto do cenário descrito pelo usuário com base nos dados acima.
Seja preciso, use os dados numéricos disponíveis e projete resultados realistas.

## FORMATO DE RESPOSTA OBRIGATÓRIO
Responda com uma análise concisa (máximo 3 parágrafos) seguida EXATAMENTE deste bloco JSON:

\`\`\`json
{
  "health_delta": 0,
  "execution_delta": 0,
  "opportunity_delta": 0,
  "roi_estimate": 0,
  "risk_level": "baixo",
  "recommendation": "texto da recomendação",
  "affected_projects": [],
  "confidence": 75,
  "timeline_weeks": 4
}
\`\`\`

Onde:
- health_delta: variação estimada no score de saúde do ecossistema (-100 a +100)
- execution_delta: variação no score de execução (-100 a +100)
- opportunity_delta: variação no score de oportunidades (-100 a +100)
- roi_estimate: ROI estimado em % (pode ser negativo)
- risk_level: "baixo", "médio", "alto" ou "crítico"
- recommendation: recomendação executiva em 1 frase
- affected_projects: lista de nomes de projetos afetados
- confidence: confiança da simulação de 0 a 100
- timeline_weeks: tempo estimado para ver o impacto em semanas

Responda sempre em Português do Brasil.`;

    const groqRes = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        temperature: 0.3,
        max_tokens: 700,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: `Simule este cenário: ${scenario}` },
        ],
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      throw new Error(`Groq error ${groqRes.status}: ${errText}`);
    }

    const groqData = await groqRes.json();
    const rawContent: string = groqData.choices?.[0]?.message?.content ?? '';

    // Parse structured result block
    let healthDelta      = 0;
    let executionDelta   = 0;
    let opportunityDelta = 0;
    let roiEstimate      = 0;
    let riskLevel        = 'médio';
    let recommendation   = '';
    let affectedProjects: string[] = [];
    let confidence       = 70;
    let timelineWeeks    = 4;
    let analysisText     = rawContent;

    const jsonMatch = rawContent.match(/```json\s*([\s\S]*?)```/);
    if (jsonMatch) {
      try {
        const meta        = JSON.parse(jsonMatch[1]);
        healthDelta       = meta.health_delta      ?? 0;
        executionDelta    = meta.execution_delta   ?? 0;
        opportunityDelta  = meta.opportunity_delta ?? 0;
        roiEstimate       = meta.roi_estimate      ?? 0;
        riskLevel         = meta.risk_level        ?? 'médio';
        recommendation    = meta.recommendation    ?? '';
        affectedProjects  = meta.affected_projects ?? [];
        confidence        = meta.confidence        ?? 70;
        timelineWeeks     = meta.timeline_weeks    ?? 4;
        analysisText      = rawContent.replace(/```json[\s\S]*?```/, '').trim();
      } catch (_) { /* keep defaults */ }
    }

    return new Response(
      JSON.stringify({
        analysis:          analysisText,
        health_delta:      healthDelta,
        execution_delta:   executionDelta,
        opportunity_delta: opportunityDelta,
        roi_estimate:      roiEstimate,
        risk_level:        riskLevel,
        recommendation,
        affected_projects: affectedProjects,
        confidence,
        timeline_weeks:    timelineWeeks,
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
