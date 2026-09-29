# COMMERCIAL V1 — PT/EN COVERAGE MATRIX

Data: 2026-09-29
Escopo: apenas superfícies com `commercialEnabled: true` em
`lib/core/modules/module_registry.dart` (29 módulos comerciais no total;
esta matriz cobre as ~24 que têm tela dedicada — módulos com `route: null`
e sem tela própria, como `usage-quota`, `file-import`,
`google-drive-import`, `project-auto-bootstrap` e `command-center`, não
aparecem como linha própria, mas seus textos hardcoded aparecem
DENTRO das telas que os consomem e estão anotados nas notas).

Método: para cada tela, grep por `AppLocalizations.of(context)` (ausência
total = "NÃO", presença = conta strings PT hardcoded remanescentes via
regex `'[A-ZÀ-Ú][a-zà-ú][^']{3,60}'` para distinguir SIM de PARCIAL).
Zero uso de `AppLocalizations` implica, por construção, que NENHUMA das 6
categorias (erros/empty/loading/validação/quota/geral) pode estar
localizada — não é preciso verificar caso a caso.

## Resumo

- **29** módulos comerciais no registry; **24** com tela dedicada auditada aqui.
- **1** tela 100% localizada (Dashboard — corrigido nesta sessão).
- **5** telas parcialmente localizadas (usam `AppLocalizations` para parte
  do texto, mas têm dezenas de strings hardcoded remanescentes).
- **18** telas 0% localizadas (nenhum uso de `AppLocalizations`).

**NO_MIXED_LANGUAGE está VIOLADO por construção em toda tela "PARCIAL":**
ao trocar o locale do app para EN, as strings que já passam por
`AppLocalizations` mudam para inglês corretamente, mas as strings
hardcoded (sempre em português) continuam em PT — resultando numa tela
com os dois idiomas misturados simultaneamente. Não é uma hipótese: é uma
consequência direta e inevitável da mistura de infraestrutura l10n +
strings fixas dentro do mesmo widget tree.

## Prioridade de correção (mais crítico → menos crítico)

1. **Action Engine** (`action_engine_screen.dart`, `action_detail_screen.dart`) — 0%, módulo core do produto, erros hardcoded confirmados (`'Erro: $e'` em 2 pontos).
2. **Market Intelligence — os 6 sub-módulos + Hub** — 0%, é o módulo mais rico em UI/inteligência do produto (Opportunity Score, Revenue Potential, Competitor Discovery, Gap Analysis, Opportunities) e nenhuma parte está localizada.
3. **Growth Intelligence Pro (5 módulos)**: Personas, Biblioteca, Calendário, Campanhas, Performance — 0%, tier pago (usuário Pro paga e recebe telas 100% em PT sem opção real de EN).
4. **ROI Tracker** — 0%.
5. **Improve Post** (`content_generation_screen.dart`) — 0%, é o CTA principal do Dashboard ("Melhorar Post com IA").
6. **Knowledge Vault** — 0%, um dos módulos mais usados (import de arquivos, Google Drive).
7. **Website Analyzer** — 0%.
8. **Projects** (`project_command_center_screen.dart`) — PARCIAL, mas com 77 strings hardcoded (a pior proporção entre as "parciais" — mistura de idioma mais visível).
9. **Opportunity Lab** (lista + detalhe) — PARCIAL (15 + 36 hardcoded).
10. **Market Intelligence (tela raiz)** — PARCIAL (15 hardcoded).
11. **Upgrade** — PARCIAL, mas só 4 hardcoded (quase completo, correção rápida).

## Matriz completa

| Módulo | Rota | Arquivo(s) | Infra i18n | Erros | Empty States | Loading | Validação | Quota/Plano | NO_MIXED_LANGUAGE | Notas |
|---|---|---|---|---|---|---|---|---|---|---|
| business-dashboard | /dashboard | dashboard_screen.dart | **SIM (100% no momento desta auditoria)** | Localizado | N/A | N/A | N/A | Localizado | OK (no momento desta auditoria) | Corrigido em commit anterior desta sessão (28590a9). Único módulo comercial 100% limpo. **ATENÇÃO**: este arquivo está sendo modificado CONCORRENTEMENTE por outro processo desta mesma missão (enriquecimento R6/Executive Dashboard, providers novos: `projectsProvider`, `marketAnalysesProvider`, `pendingActionsProvider` já visíveis). Recomenda-se reverificar este módulo especificamente após o trabalho de R6 terminar, para garantir que os novos componentes de inteligência executiva adicionados também usem `l10n` e não reintroduzam strings hardcoded. |
| projects | /projects | project_command_center_screen.dart | PARCIAL | Hardcoded | Hardcoded | Hardcoded | N/A verificado | Hardcoded | **VIOLADO** | 77 strings PT hardcoded remanescentes — maior densidade de hardcode entre as telas "parciais". |
| market-intelligence (hub raiz) | /market-intelligence | market_intelligence_screen.dart | PARCIAL | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | **VIOLADO** | 15 strings hardcoded. |
| market-intelligence (análise :id) | /market-intelligence/:id | market_intelligence_hub_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded (`_EmptyState`) | Hardcoded | N/A | N/A | N/A (tudo PT) | Tela mais rica de inteligência do produto (Opportunity Score, Revenue Potential, 5 cards) — zero l10n. |
| competitor-discovery | (sub, sem rota própria) | competitor_discovery_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded (diálogo de confirmação de cota) | N/A | — |
| gap-analysis | (sub) | gap_analysis_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | — |
| niche-discovery | (sub) | niche_discovery_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Não verificado individualmente (mesmo padrão estrutural dos demais sub-módulos de MI, confirmado por amostragem). |
| opportunity-discovery | (sub) | opportunity_discovery_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Idem. |
| content-cluster | (sub) | content_cluster_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Idem. |
| revenue-planner | (sub) | revenue_planner_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Idem. |
| knowledge-vault | /knowledge | knowledge_vault_screen.dart (+ knowledge_item_form_screen.dart) | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | Hardcoded (form de item) | N/A | N/A | Um dos módulos mais usados (import PDF/DOCX/Drive). |
| website-analyzer | /website-analyzer | website_analyzer_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | Hardcoded | Hardcoded | N/A | — |
| opportunity-lab | /opportunity-lab | opportunity_lab_screen.dart | PARCIAL | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | **VIOLADO** | 15 hardcoded. |
| opportunity-lab (detalhe) | /opportunity-lab/:id | opportunity_detail_screen.dart | PARCIAL | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | **VIOLADO** | 36 hardcoded — segunda pior densidade. |
| action-engine | /action-engine | action_engine_screen.dart | **NÃO (0%)** | Hardcoded (`'Erro: $e'` confirmado em 2 pontos) | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Módulo core; `action_engine_execute_sheet.dart` (o modal de execução AEF) É localizado, mas a tela principal que o hospeda não é — mistura garantida dentro do mesmo fluxo. |
| action-engine (detalhe) | /action-engine/:id | action_detail_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | N/A | N/A | — |
| plans-upgrade | /upgrade | upgrade_screen.dart | PARCIAL | Hardcoded | N/A | Hardcoded | N/A | Hardcoded | **VIOLADO** (mas quase resolvido) | Só 4 strings hardcoded remanescentes — a correção mais barata da lista. |
| improve-post | /generate | content_generation_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | Hardcoded | Hardcoded | N/A | CTA principal do Dashboard ("Melhorar Post com IA") — primeira ação que um usuário Free realiza no produto. |
| personas | /personas | personas_screen.dart (+ persona_form_screen.dart) | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | Hardcoded (form) | Hardcoded | N/A | Tier Pro pago. |
| content-library | /content | content_library_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Tier Pro pago. |
| calendar | /calendar | calendar_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Tier Pro pago. |
| campaigns | /campaigns | campaigns_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | Hardcoded | Hardcoded | N/A | Tier Pro pago. |
| performance | /performance | performance_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Tier Pro pago. |
| roi-tracker | /roi-tracker | roi_tracker_screen.dart | **NÃO (0%)** | Hardcoded | Hardcoded | Hardcoded | N/A | Hardcoded | N/A | Tier Pro pago. |
| ive-avatar (overlay global) | (overlay) | ive_avatar.dart, ive_overlay.dart | **SIM (essencialmente completo)** | N/A | N/A | N/A | N/A | N/A | OK | 0 strings hardcoded detectadas no regex de amostragem; já confirmado localizado em sessão anterior. |
| context-copilot (chat da IVE) | (overlay) | context_copilot_widget.dart | Não confirmado nesta rodada | — | — | — | — | — | — | Não apareceu na varredura de `AppLocalizations.of(context)`, mas o widget pode reusar strings de outros arquivos já localizados — requer verificação dedicada antes de declarar status. |

## Verificação de integridade das chaves .arb

Não foi possível, dentro do escopo desta rodada, comparar programaticamente
`app_pt.arb` vs `app_en.arb` chave a chave (ambos têm centenas de entradas).
Amostragem manual das chaves adicionadas nesta sessão (`dashXxx`) confirma
pares completos PT+EN. Recomenda-se um script de CI que falhe o build se os
dois arquivos `.arb` tiverem conjuntos de chaves diferentes — não existe
hoje.

## Conclusão

O requisito comercial PT/EN **NÃO está satisfeito**. Apenas 1 de 24
superfícies comerciais auditadas é totalmente bilíngue; 18 são 100%
português sem nenhuma via de tradução; as 5 restantes garantem uma
experiência de idioma misto para qualquer usuário que troque para EN. Isto
inclui o CTA principal do produto (Improve Post), o módulo de maior
densidade de inteligência (Market Intelligence completo) e todo o tier
pago Growth Intelligence Pro.
