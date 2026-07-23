# Update Packs — Arquitetura de Próximas Entregas

**Data:** 2026-07-23
**Nota:** Estes packs descrevem o que PODE ser implementado em fases futuras.
Nenhum está ativo ainda. Cada pack requer autorização explícita antes de iniciar.

---

## PACK 01 — Asset Intelligence UI
**Pré-requisito:** Migrations 022/023/024 aplicadas (KI-001 resolvido)
**Escopo:**
- Tela principal: `features/asset_intelligence/asset_intelligence_screen.dart`
- Smart Import Hub UI (conectar ao AssetIngestionNotifier existente)
- Asset detail screen com AssetScore
- Hierarquia de assets (parent_asset_id)
- Integração com Opportunity Lab (asset_id em opp/action)

**Requer migrations:** 022, 023, 024

---

## PACK 02 — Score Explainability e Confiança
**Pré-requisito:** Dados de análise suficientes (A1–A5 concluídos)
**Escopo:**
- Campo `confidence` (HIGH/MEDIUM/LOW/INSUFFICIENT) no EcosystemScore
- UI card de score com breakdown visual (barra de componentes)
- Alerta "Dados insuficientes" quando has_enough_data=false
- Métrica de `data_completeness` (0–100%) por projeto
- Versionamento de metodologia (`methodology_version` no score)

**Não requer migrations** (apenas código Flutter + service layer)

---

## PACK 03 — Agent Mode Release
**Pré-requisito:** OPENAI_API_KEY + INTERNAL_TESTER_IDS configurados; deploy autorizado
**Escopo:**
- Deploy de `ive-agent-runner` para produção
- Ativar `ive_agent_mode_tester_<uid>` para usuários beta
- Testes E2E com agent mode ativo
- Monitoramento de latência e custo (correlation_id + logExecution)
- Rollback plan: desativar feature flag DB row

**NÃO requer:** flag global ON, uid no payload Flutter, INTERNAL_TESTER_IDS no client

---

## PACK 04 — Reliability Dashboard
**Pré-requisito:** PACK 02 concluído
**Escopo:**
- Dashboard de saúde do portfólio (score médio, % projetos com dados)
- Alerta de projetos "órfãos" (criados há >30 dias sem análise)
- History de scores por projeto (trend ao longo do tempo)
- Export de relatório de scores

---

## PACK 05 — AutoBootstrap Melhorado
**Pré-requisito:** Inventário de projetos sem análise concluído (A1–A3)
**Escopo:**
- Bootstrap sob demanda da tela de projeto
- Progresso visual durante bootstrap (steps individuais)
- Retry inteligente para edge functions que falharam
- Notificação quando bootstrap completa em background

---

## PACK 06 — Módulos Futuros (Fora do Escopo Atual)
**NOTA:** Estes itens estão EXPLICITAMENTE fora do escopo atual e NUNCA devem ser implementados sem autorização clara:

- InsightValues migration para nova arquitetura
- IVE Research Engine (agentes especialistas)
- Living Thesis (memória persistente de agente)
- Predictive Intelligence
- SaaS / Billing / Multi-tenant
- Streaming de respostas do copilot
- Memória de longo prazo entre sessões
