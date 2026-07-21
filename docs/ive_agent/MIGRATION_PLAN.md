# IVE Agent Migration Plan — Blueprint v1.0

> Status: BLUEPRINT ONLY — Nenhuma implementação realizada.  
> Data: 2026-07-21  
> Princípio: Zero breaking changes — o usuário não percebe a migração.

---

## Estratégia: Provider Override por Feature Flag

A migração não substitui o código existente. Em vez disso, a nova implementação coexiste com a atual através de override de provider:

```
[Fase 1A] SupabaseIveCopilotGateway  ← estado atual, em produção
[Fase 1B] IveAgentGateway            ← nova implementação, inativa por padrão
[Fase 1C] IveAgentGateway            ← ativada via feature flag
[Fase 2]  SupabaseIveCopilotGateway  ← removido após validação completa
```

---

## Fases

### Fase 1A — Auditoria e Blueprint (CONCLUÍDA)

- [x] Mapear arquitetura completa (providers, gateway, contrato, Edge Function)
- [x] Identificar pontos de extensão
- [x] Definir Tool Registry V1
- [x] Definir Permission Model
- [x] Definir Security Threat Model
- [x] Documentar em `docs/ive_agent/`
- [x] Commit e push no branch de desenvolvimento

Resultado: Este conjunto de documentos.

---

### Fase 1B — POC: IveAgentGateway + Edge Function ive-agent-runner

**Pré-requisito:** Decisões D1, D2, D3 do `IVE_AGENT_ARCHITECTURE.md` tomadas.

**Arquivos a criar:**

| Arquivo | Tipo | Descrição |
|---|---|---|
| `lib/features/ive/services/ive_agent_gateway.dart` | Flutter | Nova implementação de `IveCopilotGateway` |
| `supabase/functions/ive-agent-runner/index.ts` | Deno | Nova Edge Function com agent loop |
| `supabase/functions/ive-agent-runner/tool_registry.ts` | Deno | Registro e execução das ferramentas V1 |
| `supabase/functions/ive-agent-runner/permission_engine.ts` | Deno | Validação JWT, project ownership, ENTITY_ISOLATION |
| `test/features/ive/ive_agent_gateway_test.dart` | Dart | Testes unitários do novo gateway |

**Arquivos a modificar (minimal):**

| Arquivo | Linha | Mudança |
|---|---|---|
| `lib/features/ive/services/ive_copilot_gateway.dart` | 11-13 | Adicionar condição de feature flag no `iveCopilotGatewayProvider` |

**Arquivos que NÃO devem ser modificados:**

- `lib/features/ive/domain/ive_copilot_contract.dart` — contrato imutável
- `lib/features/ive/domain/ive_action_proposal.dart` — lógica de proposta imutável
- `lib/providers/context_copilot_provider.dart` — notifier imutável
- `lib/providers/ive_context_provider.dart` — context data imutável
- `lib/shared/widgets/context_copilot_widget.dart` — UI imutável
- Todas as migrations SQL (022, 023, 024) — schema imutável

**Critérios de saída da Fase 1B:**

- [ ] `flutter test` passa com 100% dos testes existentes
- [ ] `flutter analyze` sem warnings
- [ ] IveAgentGateway implementa `IveCopilotGateway` sem modificar a interface
- [ ] `ive-agent-runner` retorna respostas no mesmo formato que `context-copilot`
- [ ] Tool `action.create` mantém deduplicação por `persistenceMarker`
- [ ] Tool `action.list` retorna apenas dados do projeto ativo
- [ ] Agent loop encerra em no máximo 5 iterações
- [ ] Timeout total de 25s respeitado
- [ ] Nenhum dado de outro projeto visível em nenhum tool

---

### Fase 1C — Ativação Controlada

**Pré-requisito:** Fase 1B aprovada em staging.

**Mecanismo de feature flag:**

```dart
// lib/features/ive/services/ive_copilot_gateway.dart
final iveCopilotGatewayProvider = Provider<IveCopilotGateway>((ref) {
  final useAgent = ref.watch(remoteConfigProvider).getBool('ive_agent_enabled');
  if (useAgent) {
    return IveAgentGateway(Supabase.instance.client);
  }
  return SupabaseIveCopilotGateway(Supabase.instance.client);
});
```

**Rollout gradual sugerido:**

```
Semana 1: 0% → 5% dos usuários (canary)
Semana 2: 5% → 25%
Semana 3: 25% → 75%
Semana 4: 75% → 100%
```

**Métricas de saúde a monitorar:**

- Taxa de erro da IVE (deve manter < 2%)
- Latência P95 (deve manter < 30s)
- Taxa de confirmação de proposta (não deve cair)
- Taxa de erro por tipo (especialmente 401 e 404)

---

### Fase 2 — Remoção do Gateway Legado

**Pré-requisito:** Fase 1C completa, 100% dos usuários no novo gateway, 2 semanas sem incidentes.

**Arquivos a remover:**

- `lib/features/ive/services/ive_copilot_gateway.dart` → manter apenas `IveAgentGateway`
- `supabase/functions/context-copilot/` → deprecar e remover após período de observação

**Mudanças de limpeza:**

- Remover `isV2` flag de `IveCopilotResponse` (sempre V2 agora)
- Remover `legacySuggestion` e `legacySources` de `IveCopilotResponse`
- Remover `fromSuggestion` factory de `IveActionProposal`
- Remover `CopilotActionSuggestion` de `copilot_turn.dart`

---

## Compatibilidade de Contrato

### Entrada (IveCopilotRequest.toMap) — sem alteração

O `ive-agent-runner` recebe exatamente o mesmo payload que `context-copilot`:

```json
{
  "message": "string",
  "project_id": "uuid",
  "route": "string",
  "screen_name": "string",
  "context_version": "2.0",
  "context": { "...hints opcionais..." },
  "history": [{ "role": "user|assistant", "content": "string" }],
  "recent_questions": ["string"],
  "client_correlation_id": "string"
}
```

### Saída (IveCopilotResponse.parse) — sem alteração

O `ive-agent-runner` retorna exatamente o mesmo formato V2:

```json
{
  "response_id": "uuid",
  "response_text": "string",
  "project_id": "uuid",
  "intent": "string",
  "evidence": [{ "source_type": "string", "source_id": "uuid", ... }],
  "proposed_action": { "tool_name": "action.create", "project_id": "uuid", ... },
  "limitations": ["string"],
  "system_confidence": 0-100,
  "model": "string",
  "prompt_version": "string",
  "server_timestamp": "ISO8601",
  "correlation_id": "string"
}
```

---

## Estimativas de Complexidade

| Fase | Complexidade | Tempo estimado | Risco |
|---|---|---|---|
| 1A (concluída) | Baixa | Concluída | — |
| 1B — IveAgentGateway Flutter | Baixa | 2-4h | Baixo |
| 1B — Edge Function ive-agent-runner | Alta | 2-3 dias | Médio |
| 1B — Tool Registry (5 tools) | Média | 1-2 dias | Baixo |
| 1B — Testes | Média | 1 dia | Baixo |
| 1C — Feature flag + rollout | Baixa | 4-8h | Médio (operacional) |
| 2 — Remoção legado | Baixa | 4-8h | Baixo |

**Total estimado para POC funcional (Fases 1B+1C):** 5-8 dias de desenvolvimento

---

## Riscos da Migração

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Agent loop excede timeout (25s) | Alta | Alto | `max_turns=5`, ferramentas read são rápidas |
| LLM produz tool_call inválido | Média | Médio | Schema validation antes de executar |
| Regressão em confirmação de proposta | Baixa | Alto | Testes existentes de Grupo 7 cobrem isso |
| Custo de LLM aumenta com múltiplas iterações | Média | Médio | Monitorar custo médio por conversa |
| Feature flag não desativa corretamente | Baixa | Alto | Teste de integração do provider override |

---

## Checklist Pré-Início da Fase 1B

Antes de escrever qualquer código da Fase 1B, confirmar:

- [ ] Decisão D1 tomada: qual LLM usar no ive-agent-runner
- [ ] Decisão D2 tomada: agent loop no Edge Function (recomendado)
- [ ] Decisão D3 tomada: streaming (não recomendado em V1 — simplifica muito)
- [ ] Decisão D4 tomada: mecanismo de feature flag
- [ ] Ambiente de staging disponível para testar sem afetar produção
- [ ] Backup do Edge Function context-copilot (já versionado no repositório)
