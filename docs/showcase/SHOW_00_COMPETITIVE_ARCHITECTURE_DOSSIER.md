# SHOW-00 — Competitive Architecture Dossier
## Benchmarks analisados × InsightValues™ — Tabela ADOPT/ADAPT/DIFFERENTIATE/REJECT/FUTURE

**Data:** 2026-08-13

---

## SEÇÃO A — SÍNTESE DOS BENCHMARKS

### A1. AXIOM
**Princípio central:** TRUTH → DECISION → ACTION → OUTCOME → LEARNING

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Separação FACT vs INFERENCE | Alto — credibilidade do Showcase | MISSING | **ADOPT** |
| Evidence lineage (rastreio de fonte) | Alto — explainability | MISSING | **ADOPT** |
| Business memory estruturada | Alto — já existe parcialmente | PARTIAL (BusinessMemory) | **ADAPT** |
| Especialistas coordenados | Médio — IVE como single advisor | MISSING (Edge Functions independentes) | **ADAPT** |
| Human approval gate | Alto — demos a investidores precisam de controle | MISSING | **ADOPT** |
| Actions + receipts | Alto — execution assurance | MISSING | **ADOPT** |
| Outcome measurement | Médio — ROI tracker existe | PARTIAL (ROI metrics) | **ADAPT** |
| Learning loop | Alto — diferenciador estratégico | MISSING | **FUTURE** |

### A2. PROJECTFLOW AI
**Princípio central:** Nenhum agente com autoridade implícita ou ilimitada.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Evidence-backed requirements | Alto — decisões com evidências | MISSING | **ADOPT** |
| Immutable approvals | Baixo — overhead para produto B2B SMB | MISSING | **REJECT** |
| Bounded agent execution | Médio — Edge Functions já têm limites implícitos | PARTIAL (por contrato Groq) | **ADAPT** |
| Explicit authority (scope) | Alto — ações não devem ser auto-executadas | MISSING | **ADOPT** |
| Execution checkpoints | Médio — ação só é completa quando verificada | MISSING | **FUTURE** |
| Traceability | Alto — auditoria de decisões | PARTIAL (origin/sources nos itens) | **ADAPT** |

### A3. SMB ACQUIRE
**Princípio central:** A interface não é a autoridade. Capacidades têm contratos.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Stable capability contract | Alto — Showcase precisa de API estável | MISSING | **ADOPT** |
| Same policy UI/agent/CLI | Médio — relevante para futura API pública | MISSING | **FUTURE** |
| Idempotency | Alto — evitar duplicação em retries | MISSING | **ADOPT** |
| Audit trail | Alto — demonstrações a investidores | PARTIAL (created_at/updated_at) | **ADAPT** |
| Action receipts | Alto — execution assurance | MISSING | **ADOPT** |
| Explicit operational boundaries | Alto — o que a IVE pode e não pode fazer | MISSING | **ADOPT** |

### A4. MAIBE
**Princípio central:** Uma ação não é concluída porque foi enviada. Só é concluída quando o resultado esperado é verificado.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Execução em ambiente real | Baixo — IV não executa em browser | MISSING | **REJECT** |
| API + browser automation | Baixo — fora do escopo atual | MISSING | **REJECT** |
| Persistent workspace | Médio — Knowledge Vault funciona assim | PARTIAL | **ADAPT** |
| Verification after action | Alto — action status ≠ verified outcome | MISSING | **ADOPT** |
| Recovery | Médio — importante mas complexo | MISSING | **FUTURE** |
| Human takeover | Alto — controle humano é princípio central | PARTIAL (approval status) | **ADAPT** |

### A5. CLIPFORGE
**Princípio central:** Single Outcome Principle. Input claro → Transformação clara → Output claro.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Input único claro | Alto — Showcase tem muitos inputs hoje | MISSING | **ADOPT** |
| Transformação explícita | Alto — usuário deve entender o que acontece | PARTIAL (scores visíveis) | **ADAPT** |
| Output claro e único | Alto — cada experiência tem um objetivo | MISSING | **ADOPT** |
| Simplicidade acima de funcionalidades | Alto — InsightValues tende ao overengineering | MISSING | **ADOPT** |

### A6. FARAN
**Princípio central:** Número de agentes ≠ inteligência. Agentes só são úteis quando têm responsabilidade, inputs, outputs e autoridade definidos.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| Durable memory | Alto — conhecimento persiste entre sessões | PARTIAL (Supabase + SharedPrefs) | **ADAPT** |
| Semantic retrieval | Alto — encontrar conhecimento relevante | MISSING | **FUTURE** |
| Agent responsibility boundaries | Alto — Edge Functions sem contrato explícito | MISSING | **ADOPT** |
| Typed contracts (inputs/outputs) | Alto — fundamental para testabilidade | MISSING | **ADOPT** |
| Resumable workflows | Médio — análises longas podem ser retomadas | MISSING | **FUTURE** |
| Evaluation of intelligence | Alto — medir se a IA é realmente útil | MISSING | **ADOPT** |
| Regression testing of intelligence | Alto — evitar regressões silenciosas | MISSING | **ADOPT** |

### A7. PROJECTBEN
**Princípio central:** AI EXECUTIVE ADVISOR + INTELLIGENT OPERATING PRESENCE.

| Princípio | Relevância IV | Suporte atual | Decisão |
|---|---|---|---|
| AI presence (visibilidade) | Alto — IVE precisa ser percebida | PARTIAL (IveOverlay implementado) | **ADAPT** |
| Contextual availability | Alto — IVE disponível em qualquer tela | PARTIAL (overlay flutuante) | **ADAPT** |
| Persistent assistant | Médio — IVE lembra contexto entre sessões | PARTIAL (IveMemory) | **ADAPT** |
| Emotional / visual UX | Médio — IVE não deve ser mascote | PARTIAL (fallback ativa) | **DIFFERENTIATE** |
| Local persistence | Médio — SharedPreferences já existe | EXISTS | **ADAPT** |
| Perceived intelligence | Alto — IVE deve parecer capaz | PARTIAL | **ADAPT** |

---

## SEÇÃO B — ANÁLISE ANTI-CÓPIA / ANTI-OVERENGINEERING

### B1. O que seria cópia desnecessária de concorrentes?

- Implementar um "marketplace de agentes" — IV tem IVE como single advisor, não um swarm
- Copiar "autonomous browser automation" (MAIBE) — IV analisa e recomenda, não executa em ambiente real
- Implementar "immutable approvals" como blockchain (PROJECTFLOW) — overhead sem benefício claro no contexto SMB
- Criar N especialistas coordenados explicitamente — a IVE deve ser a face, especializações são internas
- Pipeline de 15 etapas visível ao usuário — o usuário precisa de decisões, não de arquitetura

### B2. O que já existe melhor no InsightValues?

- **Ecosystem Intelligence**: scoring multi-dimensional de portfólio (7 scores) — mais sofisticado que benchmarks simples
- **Opportunity Lab**: combinação de market score + revenue score + strategic fit — único no contexto visto
- **Auto Bootstrap**: geração automática de oportunidades + ações para projetos novos — reduz fricção inicial
- **Knowledge Vault integrado a Personas**: treinamento de voz a partir de documentos — diferenciador real
- **Market Intelligence Hub completo**: competitor discovery + gap analysis + niche ranking + content cluster + revenue planner — suite completa
- **IVE Event Bus**: sistema reativo de eventos sem polling — arquitetura limpa e extensível

### B3. Quais ideias dos benchmarks são realmente necessárias?

**Necessárias agora (SHOW-01 a SHOW-05):**
1. Separação FACT vs INFERENCE no output da IVE
2. Source lineage (qual documento fundamentou qual conclusão)
3. Human approval gate antes de qualquer ação executada
4. Single Outcome Principle no Showcase UX
5. Typed contracts para as Edge Functions (schema de entrada/saída)
6. IVE Verdict estruturado (GO / GO WITH CONDITIONS / NO-GO)

**Necessárias depois:**
7. Intelligence evaluation harness
8. Semantic retrieval (RAG)
9. Action receipts com verificação de resultado
10. Living Thesis

### B4. Quais criariam complexidade sem benefício?

- Multi-agent coordination com N especialistas coordenados por orchestrator — a IVE já é o advisor
- Browser automation (MAIBE) — fora do escopo de analysis/decision
- Immutable approval chains (PROJECTFLOW) — overhead para usuário SMB
- CLI idêntico ao SDK idêntico ao UI (SMB ACQUIRE) — prematura no estágio atual
- Resumable workflows com checkpoint state — over-engineered para as análises atuais

### B5. O que deve ficar fora da primeira Showcase?

- Integração Quant (sem acesso ao repositório)
- Learning loop completo (Living Thesis)
- Semantic retrieval / RAG
- Intelligence evaluation harness
- Multi-agent coordination
- Action verification automatizada
- Globalization completa

### B6. Quais são diferenciais próprios do InsightValues?

1. **Ecosystem Intelligence** — visão de portfólio multi-projeto com scoring integrado
2. **Auto Bootstrap** — projeto novo gera oportunidades + ações automaticamente via Knowledge
3. **Decision Validation** — bloqueio inteligente de decisões com dados insuficientes
4. **IVE Presence** — avatar executiva com estados operacionais, não mascote
5. **Knowledge → Action Chain** — documento → análise → oportunidade → ação em cadeia automática
6. **Niche/Market positioning** como contexto central de todas as decisões
7. **Portuguese-first** — profundidade de mercado BR que benchmarks internacionais não têm

### B7. Onde estamos tentando resolver problema que ainda não existe?

- **Multi-language UI** — o produto é PT-BR first; internacionalização é roadmap, não bloqueador
- **Full audit trail imutável** — usuários SMB não auditam histórico, querem próximas ações
- **Execution verification** para ações manuais — o usuário executa manualmente, não o sistema

### B8. Quais componentes devem permanecer simples?

- **IVE Copilot chat** — context window + LLM + resposta. Não precisar de RAG para V1 Showcase
- **Action status** — 5 estados é suficiente (pending/approved/executing/completed/cancelled)
- **Memory** — SharedPreferences + Supabase já cobrem os casos de uso observados
- **Scoring** — os algoritmos de score atual são transparentes e funcionais; não precisam de ML

---

## SEÇÃO C — PRINCÍPIOS ADOTADOS PARA O SHOWCASE

### ADOPT (implementar para o Showcase)
1. FACT vs INFERENCE separation (Axiom)
2. Source lineage (Axiom + SMB Acquire)
3. Human authority gate antes de execução (Axiom + ProjectFlow + MAIBE)
4. Action receipts (Axiom + SMB Acquire)
5. Typed specialist contracts (Faran)
6. Intelligence evaluation (Faran)
7. Single Outcome Principle por experiência (Clipforge)
8. Explicit authority / capability boundaries (SMB Acquire + ProjectFlow)
9. IVE Verdict estruturado GO/GO WITH CONDITIONS/NO-GO (Axiom)
10. Idempotency em operações críticas (SMB Acquire)

### ADAPT (adaptar ao contexto InsightValues)
1. Business memory → estruturar os 7 tipos existentes com origem/confiança (Axiom)
2. Evidence → usar sources[] existente como foundation (ProjectFlow)
3. IVE Presence → manter avatar executivo, não emocional (ProjectBen)
4. Audit trail → enriquecer created_at com rastreio de decisão (SMB Acquire)
5. Human takeover → approval status existente + gate explícito (MAIBE)
6. Traceability → origin/sources já presentes, formalizar contrato (ProjectFlow)
7. Persistent assistant → IveMemory expandida (ProjectBen)
8. Workspace → Knowledge Vault como workspace persistente (MAIBE)

### DIFFERENTIATE (proposta própria do InsightValues)
1. IVE como Executive Advisor único visível (não N agentes)
2. Ecosystem Intelligence como camada integradora de portfólio
3. Auto Bootstrap como gerador de momentum inicial
4. Decisão Empresarial como flow principal (não apenas análise de conteúdo)
5. Market-first context para todas as recomendações

### REJECT (não implementar)
1. Immutable blockchain approvals (ProjectFlow) — overhead
2. Browser automation (MAIBE) — fora de escopo
3. CLI-identical-to-SDK-identical-to-UI (SMB Acquire) — prematura
4. N specialists orchestrated explicitly — a IVE é a face unificada
5. Emotional UX / mascote (ProjectBen) — IV é executive advisor

### FUTURE (roadmap pós-Showcase)
1. Semantic retrieval / RAG (Faran)
2. Resumable workflows com checkpoint (Faran)
3. Learning loop / Living Thesis (Axiom)
4. Regression testing of AI outputs (Faran)
5. Recovery automatizado (MAIBE)
6. Same-policy UI/agent/CLI (SMB Acquire)
7. Execution checkpoints automatizados (ProjectFlow)
