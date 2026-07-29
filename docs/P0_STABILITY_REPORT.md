# P0 Stability Report — Sprint Device Validation

**Data:** 2026-07-29
**Sprint:** P0 — Samsung S25 Ultra Device Validation

---

## P0-01 — BottomSheets Truncando Conteúdo

**Causa raiz:** `showModalBottomSheet` sem `useSafeArea: true` e `DraggableScrollableSheet` com `initialChildSize` muito pequeno (0.55). Em telas com `navigationBar` e notch, o conteúdo ficava cortado.

**Correção:**
- Adicionado `useSafeArea: true` em todos os `showModalBottomSheet` calls
- `initialChildSize` aumentado para 0.75 em `ive_detail_sheet.dart`
- `_ProjectPickerSheet` em `knowledge_vault_screen.dart` envolvido em `DraggableScrollableSheet` com scroll

**Arquivos:** `ive_detail_sheet.dart`, `context_copilot_widget.dart`, `knowledge_vault_screen.dart`

---

## P0-02 — Avatar IVE em Telas de Auth

**Causa raiz:** `IveOverlay` é montado globalmente no `Stack` do `app.dart` e não havia filtro de rota. Aparecia em `/login`, `/` (splash) e outros contextos indevidos.

**Correção:** Adicionado set `_hiddenRoutes = {'/login', '/', ''}` em `ive_overlay.dart`. `build()` retorna `SizedBox.shrink()` quando a rota atual está no set.

**Arquivo:** `lib/shared/widgets/ive_overlay.dart`

---

## P0-03 — IVE Respondendo Sem Dados

**Causa raiz:** `CopilotContextData` vazio era enviado para a Edge Function, que gerava respostas genéricas sem contexto real.

**Correção:** Guard adicionado em `ContextCopilotNotifier.send()`: se `context.isEmpty`, responde localmente com mensagem explicando o que falta (projetos, análises, ações).

**Arquivo:** `lib/providers/context_copilot_provider.dart`

---

## P0-04 — Recomendações Sem Origem

**Causa raiz:** `_RecCard` no Decision Center mostrava `rec.title` e `rec.reason` mas não exibia `rec.entityName` (nome do projeto/oportunidade de origem).

**Correção:** Adicionado `Text('Projeto: ${rec.entityName}')` abaixo do título em `_RecCard.build()`. Adicionado `IveEvidence(emoji: '📁', label: 'Projeto', value: rec.entityName!)` no detail sheet.

**Arquivo:** `lib/features/ecosystem/screens/executive_decision_center_screen.dart`

---

## P0-05 — Bloqueios Sem Explicação de Impacto

**Causa raiz:** `_ValidationGateCard` mostrava "BLOQUEADO" e motivos do bloqueio, mas não explicava o que aconteceria quando desbloqueado.

**Correção:** Adicionada seção "Ao desbloquear:" com `rec.expectedImpact` ou mensagem padrão explicando que a IVE poderá gerar a recomendação com dados reais.

**Arquivo:** `lib/features/ecosystem/screens/executive_decision_center_screen.dart`

---

## P0-06 — Refresh Incompleto

**Causa raiz:** Botão de refresh no Home Screen e Project Command Center invalidava apenas 2-3 providers, deixando dados desatualizados em outros módulos.

**Correção:**
- `home_screen.dart`: adicionado `projectsProvider`, `ecosystemHealthProvider`, `actionQueueProvider`, `opportunityLabProvider`
- `project_command_center_screen.dart`: adicionado `projectIntelligenceProfilesProvider`, `opportunityLabProvider`

**Arquivos:** `home_screen.dart`, `project_command_center_screen.dart`

---

## P0-07 — Market Intelligence Tela Preta

**Causa raiz 1:** `analyses.when(error:...)` exibia `Text('Erro: $e')` com texto pequeno numa tela escura — parecia tela em branco.
**Causa raiz 2:** `marketAnalysisByIdProvider` sem timeout podia ficar em loading indefinidamente se Supabase não respondesse.

**Correção:**
- `market_intelligence_screen.dart`: erro passa pelo `_friendlyError()` existente
- `market_analysis_provider.dart`: adicionado `.timeout(Duration(seconds: 15))` no `fetchById`

**Arquivos:** `market_intelligence_screen.dart`, `market_analysis_provider.dart`

---

## P0-09 — Auth Race Condition no Splash

**Causa raiz:** `splash_screen.dart` usava `Supabase.instance.client.auth.currentSession` diretamente após um `Future.delayed(800ms)`. Em cold start, a sessão não estava restaurada do secure storage ainda, retornando `null` e redirecionando para login mesmo com sessão válida.

**Correção:** Substituído por listener de `onAuthStateChange` com `Completer<Session?>` e timeout de 3 segundos. O primeiro evento de auth resolve o completer.

**Arquivo:** `lib/features/splash/splash_screen.dart`

---

## P0-10 — OpportunityLabNotifier After Dispose

**Causa raiz:** `OpportunityLabNotifier` é `StateNotifierProvider.autoDispose`. O método `load()` era chamado no constructor e poderia completar após o notifier ser descartado, causando `Bad state: Tried to use OpportunityLabNotifier after dispose()`.

**Correção:** Adicionado `if (!mounted) return;` antes de cada atribuição `state =` nos métodos assíncronos `load()`, `add()`, `approve()`, `delete()`.

**Arquivo:** `lib/providers/opportunity_lab_provider.dart`

---

## P0-11 — Stack Traces Brutos na UI

**Causa raiz 1:** `ContextCopilotNotifier.send()` propagava o erro bruto (incluindo classe de exceção e stack trace do Supabase) diretamente para o estado.
**Causa raiz 2:** `_empty()` no Debug Hub exibia `reportAsync.error.toString()` completo.

**Correção:**
- `context_copilot_provider.dart`: método `_friendlyError()` converte 429/401/timeout/network em mensagens amigáveis em PT
- `intelligence_debug_hub_screen.dart`: `_sanitizeDebugError()` trunca a primeira linha do erro em 120 caracteres

**Arquivos:** `context_copilot_provider.dart`, `intelligence_debug_hub_screen.dart`

---

## P0-12 — Strings PT/EN Misturadas

**Causa raiz:** Strings em inglês foram usadas durante desenvolvimento rápido e não substituídas.

**Correção — mapeamento:**
| Original (EN) | Substituído (PT) | Local |
|---------------|-----------------|-------|
| Decision Center | Central de Decisões | app_drawer, home_screen, dashboard, decision_center |
| OPPORTUNITY SCORE | PONTUAÇÃO DE OPORTUNIDADE | market_intelligence_hub |
| Learning Score | Aprendizado / Índice de Aprendizado | home_screen, _GateMetricRow |
| Knowledge Coverage | Cobertura de Conhecimento | _GateMetricRow |
| Intelligence Profile | Perfil de Inteligência | _GateMetricRow |

**Nota:** Termos nos IveDetailSheet titles (explicações técnicas educativas) foram mantidos para consistência com as explicações em PT dentro das sheets.

---

## Checkpoint Final

- [x] 0 erros no `flutter analyze`
- [x] 107/107 testes passando
- [x] P0-01 a P0-12 corrigidos (exceto P0-08 adiado)
- [x] Nenhuma feature nova adicionada
- [x] Nenhum módulo não relacionado refatorado
- [x] Commit e push na branch de desenvolvimento
