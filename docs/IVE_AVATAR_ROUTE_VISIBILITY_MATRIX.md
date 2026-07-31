# IVE Avatar — Route Visibility Matrix
**Fase 11F | Branch:** `claude/ive-avatar-v2-production-integration`

## Regra geral

- Usuário não autenticado → **ocultar** (qualquer rota)
- Rotas de auth/onboarding → **ocultar**
- Chat modal aberto → **ocultar**
- Teclado sem espaço suficiente (< 200px) → **ocultar**
- Todas as outras rotas autenticadas → depende da coluna abaixo

## Matriz de visibilidade por rota

| Rota | Constante | Visibilidade | Modo | Observação |
|------|-----------|--------------|------|------------|
| `/` | `routeSplash` | **Ocultar** | — | Splash screen |
| `/login` | `routeLogin` | **Ocultar** | — | Auth screen |
| `/signup` | — | **Ocultar** | — | Auth screen |
| `/forgot-password` | — | **Ocultar** | — | Auth screen |
| `/reset-password` | — | **Ocultar** | — | Auth screen |
| `/advisor-onboarding` | `routeAdvisorOnboarding` | **Ocultar** | — | Onboarding flow |
| `/debug/ive-avatar-v2` | `routeIveAvatarShowcase` | **Ocultar** | — | Showcase tem avatar próprio |
| `/dashboard` | `routeDashboard` | **Mostrar** | Floating BR | Business OS principal |
| `/home` | `routeHome` | **Mostrar** | Floating BR | Home screen |
| `/executive-dashboard` | `routeExecutiveDashboard` | **Mostrar** | Floating BR | Dashboard executivo |
| `/projects` | `routeProjects` | **Mostrar** | Floating BR | Command Center — tem botão "Perguntar à IVE" → compact |
| `/opportunity-lab` | `routeOpportunityLab` | **Mostrar** | Compact | Tem FAB — usar compacto para não cobrir |
| `/opportunity-lab/:id` | `routeOpportunityDetail` | **Mostrar** | Compact | Detail view |
| `/action-engine` | `routeActionEngine` | **Mostrar** | Compact | Action queue |
| `/action-engine/:id` | `routeActionDetail` | **Mostrar** | Compact | Action detail |
| `/ecosystem` | `routeEcosystem` | **Mostrar** | Floating BR | Decision Center |
| `/ecosystem/briefing` | `routeEcosystemBriefing` | **Mostrar** | Floating BR | Executive Briefing |
| `/ecosystem/resources` | `routeEcosystemResources` | **Mostrar** | Compact | Resources view |
| `/market-intelligence` | `routeMarketIntelligence` | **Mostrar** | Compact | Intelligence hub |
| `/market-intelligence/**` | variantes | **Mostrar** | Compact | Sub-telas de inteligência |
| `/knowledge` | `routeKnowledge` | **Mostrar** | Compact | Knowledge Vault — tem FAB |
| `/knowledge/new` | `routeKnowledgeNew` | **Mostrar** | Compact | Upload form |
| `/knowledge/:id/**` | variantes | **Mostrar após insight** | Compact | Analysis/strategy views |
| `/personas` | `routePersonas` | **Mostrar** | Compact | Personas list — tem FAB |
| `/personas/:id/**` | variantes | **Mostrar** | Compact | Persona detail/training |
| `/content` | `routeContent` | **Mostrar** | Compact | Content library — tem FAB |
| `/content/**` | variantes | **Mostrar** | Compact | Content detail |
| `/campaigns` | `routeCampaigns` | **Mostrar** | Compact | Campaigns list |
| `/campaigns/**` | variantes | **Mostrar** | Compact | Campaign detail |
| `/intelligence-debug` | `routeIntelligenceDebug` | **Mostrar** | Compact | Debug hub — somente admin |
| `/admin` | `routeAdmin` | **Mostrar** | Compact | Admin panel |
| `/roi-tracker` | `routeRoiTracker` | **Mostrar** | Floating BR | ROI tracker |
| `/generate` | `routeGenerate` | **Mostrar durante processamento** | Compact | Geração de conteúdo — IVE ativa |
| `/result` | `routeResult` | **Mostrar** | Compact | Resultado gerado |
| `/history` | `routeHistory` | **Mostrar** | Compact | Histórico |
| `/history/:id` | `routeHistoryDetail` | **Mostrar** | Compact | Detalhe do histórico |
| `/calendar` | `routeCalendar` | **Mostrar** | Compact | Calendário — tem FAB |
| `/performance` | `routePerformance` | **Mostrar** | Compact | Performance screen |
| `/upgrade` | `routeUpgrade` | **Ocultar** | — | Paywall — não misturar com IVE |
| `/website-analyzer` | `routeWebsiteAnalyzer` | **Mostrar durante processamento** | Compact | Análise ativa |
| `/website-analyzer/:id` | `routeWebsiteAnalysisResult` | **Mostrar** | Compact | Resultado |

## Legenda de modos

| Modo | Descrição |
|------|-----------|
| **Floating BR** | Flutuante bottom-right, draggável |
| **Compact** | Compacto AppBar ou canto inferior, menor que padrão |
| **Mostrar após insight** | Aparece somente quando houver insight não lido |
| **Mostrar durante processamento** | Aparece somente quando operação ativa |
| **Ocultar** | Nunca renderizar nessa rota |
