# SHOW-00 — Implementation Roadmap
## InsightValues™ — Roteiro de Implementação Corrigido pós-Auditoria

**Data:** 2026-08-13  
**Status:** ESPECIFICAÇÃO — Não implementar sem aprovação explícita  
**Base:** Auditoria arquitetural honesta do repositório real

---

## AVISO CRÍTICO

Este roadmap foi gerado **após** auditoria real do código. Ele diverge intencionalmente de qualquer roadmap pré-existente baseado em premissas não verificadas. A sequência de fases é ditada por:

1. Dependências técnicas reais (o que precisa existir para que outra coisa funcione)
2. P0/P1/P2 da Capability Gap Matrix (SHOW_00_CAPABILITY_GAP_MATRIX.md)
3. Restrições de segurança (o que permanece privado)
4. Demo reliability (o Showcase nunca pode travar)

---

## MAPA DE FASES — VISÃO GERAL

```
SHOW-00  ← AGORA → Auditoria arquitetural (este documento)
SHOW-01  ← DEMO DATA + CONTEXT FIX (P0 blockers)
SHOW-02  ← EVIDENCE LAYER (FACT vs INFERENCE)
SHOW-03  ← IVE VERDICT + AUTHORITY GATE
SHOW-04  ← SHOWCASE UX SHELL (guided linear flow)
SHOW-05  ← DEMO RELIABILITY (cache + fallbacks)
SHOW-06  ← REPOSITORY BOUNDARY (Option A → Option B)
SHOW-07+ ← ROADMAP PRODUTO PRINCIPAL (separado do Showcase)
```

**Princípio:** Showcase e Produto Principal co-evoluem em fases distintas. O Showcase nunca bloqueia o produto principal, e vice-versa.

---

## SHOW-01 — FOUNDATION (P0 BLOCKERS)

**Objetivo:** Remover os dois bloqueadores que tornam uma demo impossível.

**Dependência de entrada:** SHOW-00 completo + aprovação arquitetural.

### SHOW-01A — Demo Dataset
**Onde:** `lib/features/showcase/demo/`  
**O que:**
- 1 projeto de demonstração: `[DEMO] Should we launch InsightValues in the UK?`
- 5-7 knowledge items pré-analisados (PDFs leves, já processados)
- 1 market analysis pré-computada e armazenada no DB
- 10 opportunities pré-geradas (OpportunityLabItem com `origin: 'showcase_demo'`)
- 5 actions pré-geradas (ActionQueueItem com `origin: 'showcase_demo'`)
- 1 EcosystemScore pré-computado (recommendation: 'VALIDAR')
- Feature flag: `showcase_mode_enabled`
- Badge `[DEMO]` em todos os registros demo

**Resultado esperado:** Demo pode rodar sem nenhuma chamada de rede.

### SHOW-01B — Context Fix (Gap P0)
**Onde:** `supabase/functions/context-copilot/index.ts`  
**O que:** Passar excerpt real do conteúdo dos documentos no contexto do LLM.  
**Impacto:** Resolve causa raiz do problema "gap analysis ignoring books".  
**Risco:** Aumento do tamanho do prompt → testar com token budget de 800 chars/doc, máx 3 docs.

```typescript
// ANTES (estado atual)
documents: knowledgeItems.map(d => ({ title: d.title, status: d.status }))

// DEPOIS (target)
documents: knowledgeItems.slice(0, 3).map(d => ({
  title: d.title,
  status: d.status,
  excerpt: d.content?.slice(0, 800) ?? ''
}))
```

**Resultado esperado:** Context-copilot passa a referenciar conteúdo real dos documentos.

### SHOW-01 Checklist de saída
- [ ] `showcase_mode_enabled` feature flag existe e funciona
- [ ] Projeto demo carrega sem chamada de API externa
- [ ] Context-copilot menciona conteúdo de documentos em resposta de gap analysis
- [ ] Badge [DEMO] visível em todos os registros demo
- [ ] Nenhum spinner indefinido em nenhuma tela demo

---

## SHOW-02 — EVIDENCE LAYER

**Objetivo:** Adicionar separação FACT vs INFERENCE ao output da IVE.

**Dependência de entrada:** SHOW-01 completo.

### SHOW-02A — Truth Label Mínimo
**O que:** Adicionar enum `ClaimType` com 3 valores: `fact`, `inference`, `unknown`.  
**Onde:** `lib/data/models/evidence_claim.dart` (novo arquivo)

### SHOW-02B — Evidence Manifest no Copilot Output
**O que:** Modificar context-copilot para retornar:
- `source_type: 'document' | 'market_data' | 'llm_inference'` por source
- `claim_type: 'fact' | 'inference' | 'unknown'` por claim

### SHOW-02C — Visual Evidence Badge
**O que:** Widget `EvidenceBadge` exibindo tipo de claim + origem da fonte.  
**Onde:** `lib/shared/widgets/evidence_badge.dart` (novo)

### SHOW-02 Checklist de saída
- [ ] ClaimType enum implementado e usado no Copilot output
- [ ] EvidenceBadge renderiza corretamente nos 3 estados
- [ ] Resposta do Copilot distingue FACT vs INFERENCE visualmente
- [ ] Nenhum claim sem tipo (fallback para 'unknown' quando incerto)

---

## SHOW-03 — IVE VERDICT + AUTHORITY GATE

**Objetivo:** Adicionar o veredicto estruturado GO/GO WITH CONDITIONS/NO-GO e o gate de aprovação humana antes de qualquer execução.

**Dependência de entrada:** SHOW-02 completo.

### SHOW-03A — IVE Verdict Model
**O que:** Implementar `IveVerdict` enum e `IveDecision` model.  
**Mapeamento a partir do estado atual:**

| EcosystemScore.recommendation | IveVerdict |
|---|---|
| ESCALAR / ACELERAR | go |
| VALIDAR / MANTER | goWithConditions |
| PAUSAR / ANÁLISE INCOMPLETA | noGo |

**Onde:** `lib/data/models/ive_verdict.dart` (novo arquivo)

### SHOW-03B — Human Approval Gate
**O que:** UI de aprovação explícita antes de qualquer ActionQueueItem ir para `executing`.  
**Onde:** Componente `ApprovalGateWidget` na ActionEngine screen.  
**Lógica:** Status `approved` → gate UI → confirmação humana → `executing`.  
**Risco:** Não remover nenhum fluxo existente; o gate é adicional.

### SHOW-03C — Authority Model UI
**O que:** Badge de autoridade em cada ação proposta pela IVE:
- 🔍 READ — IVE leu dados
- 📊 ANALYZE — IVE computou
- 💡 PROPOSE — IVE sugeriu
- ⏳ AWAITING APPROVAL — aguardando humano
- ▶️ EXECUTING — aprovado e em execução

**Onde:** `lib/shared/widgets/authority_badge.dart` (novo)

### SHOW-03 Checklist de saída
- [ ] IveVerdict renderiza corretamente (GO / GO WITH CONDITIONS / NO-GO)
- [ ] Gate de aprovação não pode ser pulado (botão de execução desabilitado sem aprovação)
- [ ] Authority badge visível em todas as ações geradas pela IVE
- [ ] EcosystemScore.recommendation → IveVerdict mapeamento testado para todos os 6 valores

---

## SHOW-04 — SHOWCASE UX SHELL

**Objetivo:** Criar o fluxo linear de 15 etapas da experiência de Showcase.

**Dependência de entrada:** SHOW-03 completo.

### SHOW-04A — Feature isolada do Showcase
**O que:** `lib/features/showcase/` — feature isolada sem vazamento para features principais.  
**Entry point:** `lib/main_showcase.dart`  
**Rotas:** Isoladas do go_router principal.

### SHOW-04B — Showcase Shell (15 etapas)
**O que:** Navigator de etapas com:
1. Strategic Question input
2. Context Loading animation
3. Internal Knowledge loaded
4. External Research (Market Intelligence)
5. Evidence Manifest screen
6. Risks screen
7. Opportunities screen
8. Scenarios (Bear / Base / Bull)
9. IVE Verdict screen
10. Why? (Explainability)
11. Recommended Actions
12. Human Approval gate
13. Execution (simulada)
14. Verification screen
15. Outcome / Learning

**Princípio UX:** Sem menus de navegação. Linear. IVE presente em cada etapa.

### SHOW-04C — IVE Presence por etapa
**O que:** Mapear cada etapa a um IveVisualState:

| Etapa | IveVisualState |
|---|---|
| 1-2 | listening → thinking |
| 3-4 | researching (novo) |
| 5 | checkingEvidence (novo) |
| 6-8 | executive |
| 9 | executive + speaking |
| 10 | speaking |
| 11 | opportunity |
| 12 | waitingApproval (novo) |
| 13 | executing (novo) |
| 14 | verifying (novo) |
| 15 | success |

### SHOW-04 Checklist de saída
- [ ] `lib/main_showcase.dart` compila e exibe passo 1
- [ ] Navegação linear funciona (avançar/retroceder)
- [ ] IVE Avatar presente em cada etapa
- [ ] Dados demo carregam sem chamada de API
- [ ] Nenhum componente de showcase vaza para o produto principal

---

## SHOW-05 — DEMO RELIABILITY

**Objetivo:** Garantir que o Showcase nunca trave em uma demo real.

**Dependência de entrada:** SHOW-04 completo.

### SHOW-05A — Fallback Architecture
**O que:** Para cada Edge Function chamada no fluxo demo:
- Resposta pré-computada armazenada em `lib/features/showcase/demo/responses/`
- Timeout de 8 segundos → carregar fallback automaticamente
- Nenhum spinner indefinido

### SHOW-05B — Demo State Machine
**O que:** `ShowcaseDemoController` que gerencia:
- Estado de cada etapa (loading / loaded / fallback / error)
- Timer de timeout
- Fallback loading automático
- Reset para passo 1 (re-demo sem restart do app)

### SHOW-05C — Demo Presentation Checklist
**O que:** Documento `docs/showcase/DEMO_PRESENTATION_CHECKLIST.md` com:
- Preparação pré-demo (projetos demo no DB, análises cached)
- Passos da demo de 5 minutos
- Fallbacks para cada etapa se algo falhar
- Como resetar entre demos

### SHOW-05 Checklist de saída
- [ ] Showcase completo roda offline (apenas com dados cached)
- [ ] Timeout de 8s → fallback automático sem mensagem de erro exposta ao público
- [ ] Reset funciona sem reiniciar o app
- [ ] Demo de 5 minutos completa sem interrupção em 3 ensaios consecutivos

---

## SHOW-06 — REPOSITORY BOUNDARY (Option A → Option B)

**Objetivo:** Migrar Showcase para repositório independente.

**Dependência de entrada:** SHOW-05 completo + validação do Showcase como produto.

**Restrição:** NÃO iniciar antes de SHOW-05. Showcase misturado ao produto é estratégia temporária.

### SHOW-06A — SDK Extraction
**O que:** Extrair `packages/ive_sdk/` com:
- Core models (IveState, IveEvent, IveMemory, IveVerdict, EvidenceClaim)
- IveAvatar visual components
- Supabase client wrapper
- Edge Function contracts (TypeScript interfaces)

### SHOW-06B — Showcase Repository
**O que:** Criar `insightvalues-showcase` (novo repositório).  
**Dependência:** ive_sdk via git reference.  
**Dataset:** Demo data independente, sem vínculo com DB de produção.

### SHOW-06 Checklist de saída
- [ ] `packages/ive_sdk/` publica sem expor algoritmos proprietários
- [ ] `insightvalues-showcase` compila e passa nos testes
- [ ] Nenhuma lógica de scoring (EcosystemIntelligenceService) exportada no SDK
- [ ] Showcase repo pode ser tornado público sem expor IP

---

## SHOW-07 a SHOW-09 — INTELIGÊNCIA AVANÇADA (Produto Principal)

**Objetivo:** Melhorias no produto principal que também beneficiam o Showcase.

**Nota:** Estas fases pertencem ao produto principal, não exclusivamente ao Showcase. Showcase pode consumir os resultados via SDK após SHOW-06.

### SHOW-07 — Semantic Retrieval (RAG)
**O que:** Embeddings para Knowledge Vault. Vector search para recuperação relevante.  
**Dependência:** SHOW-06 (SDK definido antes de adicionar capacidades que o SDK exportará)  
**Bloqueador atual:** Nenhum package de embedding em pubspec; nenhum vector store configurado.

### SHOW-08 — Intelligence Evaluation Harness
**O que:** Testes automatizados de regressão do output de IA.  
**O que avaliar:** Drift de qualidade, alucinações, consistency entre chamadas.  
**Quando:** Antes de qualquer apresentação pública do Showcase.

### SHOW-09 — Action Receipts + Outcome Verification
**O que:** Recibo de execução de ação + verificação de resultado esperado.  
**Estado atual:** Status 'completed' é auto-declarado (não verificado).  
**Target:** ActionReceipt com expectedOutcome + verificationMethod + verificationResult.

---

## SHOW-10 a SHOW-12 — GLOBALIZATION + ENTERPRISE

**Objetivo:** Internacionalização e preparação para apresentações globais.

### SHOW-10 — English-first Showcase
**O que:** Toda a UX do Showcase em inglês (produto principal permanece PT-BR).  
**Bloqueador atual:** Nenhum arquivo .arb / l10n no projeto.  
**Abordagem:** Internacionalizar apenas `lib/features/showcase/` — não todo o app.

### SHOW-11 — Living Thesis
**O que:** Rastreamento de premissas de negócio ao longo do tempo.  
**Estado atual:** MISSING.  
**Dependência:** BusinessMemory estruturada + LearningEntry model.

### SHOW-12 — Quant Integration
**O que:** Integração com repositório Quant (não disponível nesta auditoria).  
**Bloqueador:** Repositório Quant não acessível. Aguarda disponibilidade.

---

## WHAT BELONGS WHERE — MAPA DE RESPONSABILIDADES

| Capacidade | Produto Principal | Showcase | SDK Compartilhado | Quant |
|---|---|---|---|---|
| Project management UI | ✅ | — | — | — |
| Knowledge Vault ingestion | ✅ | consumes | — | — |
| Market Intelligence Hub | ✅ | consumes | — | — |
| Ecosystem scoring algorithm | ✅ PRIVATE | — | ❌ não exportar | — |
| IVE Avatar visual system | ✅ | ✅ | ✅ exportar | — |
| IVE Verdict model | ✅ | ✅ | ✅ exportar | — |
| Evidence / Truth model | ✅ | ✅ | ✅ exportar | — |
| Decision Simulator | ✅ | consumes | — | — |
| Demo dataset | — | ✅ | — | — |
| Edge Function contracts | shared | shared | ✅ exportar | — |
| Prompts das Edge Functions | ✅ PRIVATE | — | ❌ não exportar | — |
| Quant strategies | — | — | — | ✅ PRIVATE |
| Globalization (PT-BR) | ✅ | — | — | — |
| Globalization (EN) | future | ✅ | — | — |
| Intelligence evaluation | ✅ | ✅ | — | — |
| RAG / semantic search | future | future | — | — |
| Learning loop | future | future | — | — |

---

## DEPENDÊNCIAS CRÍTICAS DO PATH

```
SHOW-01A (Demo Data) ──────────────────────┐
SHOW-01B (Context Fix) ────────────────────┤
                                           ↓
                                      SHOW-02 (Evidence Layer)
                                           ↓
                                      SHOW-03 (IVE Verdict + Gate)
                                           ↓
                                      SHOW-04 (UX Shell)
                                           ↓
                                      SHOW-05 (Demo Reliability)
                                           ↓
                                      SHOW-06 (Repo Boundary)
                                          / \
                                         /   \
                               SHOW-07    SHOW-10
                              (RAG)        (EN)
                                 \          /
                                  SHOW-08
                                (Eval Harness)
                                     |
                                  SHOW-09
                              (Receipts/Verify)
                                     |
                                  SHOW-11+
                              (Living Thesis,
                               Quant, etc.)
```

**Caminho crítico:** SHOW-01 → SHOW-02 → SHOW-03 → SHOW-04 → SHOW-05  
**Desbloqueador do Showcase:** SHOW-05 completo  
**Desbloqueador de repositório independente:** SHOW-06 após SHOW-05

---

## O QUE NÃO ESTÁ NESTE ROADMAP (E POR QUÊ)

| Item removido | Motivo |
|---|---|
| Multi-agent orchestration explícita | REJECT — a IVE é a face unificada; agentes são internos |
| Browser automation | REJECT — fora de escopo; IV analisa, não executa no browser |
| Immutable blockchain approvals | REJECT — overhead para SMB |
| CLI idêntico ao SDK | REJECT — prematura |
| Emotional UX / mascote | REJECT — IV é executive advisor |
| Resumable workflows com checkpoint | FUTURE — over-engineered para análises atuais |
| Audio ingestion | FUTURE — nenhum serviço de transcrição disponível |
| YouTube ingestion | FUTURE — nenhum cliente YouTube disponível |

---

## ESTIMATIVAS DE ESFORÇO (ordens de magnitude)

| Fase | Escopo | Esforço estimado |
|---|---|---|
| SHOW-01A | Demo dataset seeder | 1-2 dias |
| SHOW-01B | Context-copilot fix | 0,5 dia |
| SHOW-02 | Evidence layer | 2-3 dias |
| SHOW-03 | IVE Verdict + Gate | 2-3 dias |
| SHOW-04 | Showcase UX Shell | 5-7 dias |
| SHOW-05 | Demo Reliability | 2-3 dias |
| SHOW-06 | Repository Boundary | 3-5 dias |
| SHOW-07+ | Fases avançadas | > 20 dias |

**Total até Showcase funcional (SHOW-01 a SHOW-05):** ~14-18 dias úteis  
**Suposição:** Um desenvolvedor sênior Flutter + acesso ao Supabase.

---

## SHOW-01 — PRECONDIÇÕES FORMAIS (GO / NO-GO checklist)

Para que SHOW-01 comece, o seguinte deve ser verdadeiro:

| Precondição | Estado atual |
|---|---|
| SHOW-00 documentos entregues e revisados | ✅ em andamento |
| Branch `claude/insightvalues-showcase-audit-ebsqhi` criada | ✅ existe |
| Repositório em estado limpo (nenhuma alteração não commitada) | ✅ confirmado |
| Aprovação arquitetural dos 6 documentos de SHOW-00 | ⏳ aguarda revisão humana |
| Decisão: Showcase dentro do repo principal por agora (Opção A) | ⏳ aguarda confirmação |
| Não há PR aberto conflitante com a feature showcase/ | ⏳ verificar |
| Acesso ao Supabase DB para seed de dados demo | ⏳ confirmar ambiente |
| Feature flag `showcase_mode_enabled` pode ser adicionada sem migração de emergência | ⏳ verificar migration slot |

---

## NOTA SOBRE O QUANT

O repositório Quant não estava disponível nesta auditoria. Qualquer fase que dependa de integração com o Quant (SHOW-12+) está bloqueada até:
1. Acesso ao repositório Quant ser concedido
2. Contratos de API do Quant serem definidos
3. Estratégias do Quant que podem ser expostas no Showcase (vs. que devem permanecer privadas) serem classificadas

O Showcase de SHOW-01 a SHOW-05 não depende do Quant.

---

## DOCUMENTO VIVO

Este roadmap deve ser atualizado ao final de cada fase com:
- O que foi implementado vs. o que foi planejado
- Gaps encontrados durante a implementação
- Ajustes de prioridade baseados em feedback real
- Novas dependências identificadas

**Responsável pela atualização:** Arquiteto de sistema designado para o Showcase.
