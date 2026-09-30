# InsightValues — Development & Release Governance

> Estabelecido em IV-MAIN-RECONCILIATION-01 (2026-09-30).
> Este documento descreve o fluxo obrigatório de desenvolvimento e deploy.

---

## RULE 1 — main é a canonical integration baseline

`main` é a única fonte de verdade do produto.
Todo código aprovado e testado deve viver em `main`.

## RULE 2 — branches são temporárias

Branches existem para desenvolvimento em andamento.
Nenhuma branch pode ser usada como baseline permanente de produção.

## RULE 3 — macro missão autoriza merge sem microgates adicionais

Uma missão aprovada pelo Owner autoriza:

```
branch → commit → push → PR → CI → audit → fix → merge
```

Sem gates adicionais intermediários além dos definidos pela missão.

## RULE 4 — merge ≠ deploy

Integrar em `main` não implica deploy automático de produção.

Merge e deploy são eventos separados e deliberados.

Use feature flags, entitlements e release gates para controlar exposição
de funcionalidades integradas mas não ainda lançadas comercialmente.

## RULE 5 — feature incompleta usa feature flag, não divergência de branch

Uma funcionalidade incompleta deve permanecer em `main` sob:

- feature flag desabilitada em produção;
- entitlement admin-only;
- release gate explícito.

Nunca manter branch ativa indefinidamente apenas porque a feature não está
pronta para o público.

## RULE 6 — deploy normal requer código integrado em main

Não fazer deploy de produção a partir de branch não integrada em `main`,
exceto via procedimento de deploy excepcional (RULE 7).

## RULE 7 — deploy excepcional requer registro explícito

Um deploy feito fora do pipeline canônico (ex: a partir de branch, via
conector MCP, via shim de commit imutável) deve registrar:

| Campo        | Valor                           |
|--------------|---------------------------------|
| reason       | motivo técnico/operacional      |
| source_sha   | SHA exato do artefato deployado |
| artifact     | URL ou identificador do artefato|
| authorization| missão ou decisão que autorizou |
| rollback     | procedimento de rollback        |
| reconciliation_plan | quando main será reconciliada |

## RULE 8 — produção deve ser rastreável a main

O SHA da build em produção deve ser ancestral direto do HEAD de `main`.

Se não for, existe uma divergência que precisa de reconciliação formal.

## RULE 9 — missão não termina PASS com branch aprovada indefinidamente à frente de main

Uma missão só recebe veredito PASS ou CONDITIONAL_PASS se, ao final,
`main` contém o trabalho aprovado — ou existe um plano formal de
reconciliação com data definida.

## RULE 10 — branches com estado não integrado devem ser explicitamente classificadas

Branches que não serão mergeadas devem receber status explícito:

- `EXPERIMENTAL` — em investigação, sem compromisso
- `BLOCKED` — aguardando dependência ou decisão
- `FROZEN` — preservada para referência, não mais ativa
- `REJECTED` — descartada formalmente

Branches sem classificação devem ser investigadas antes de limpeza.

## RULE 11 — CI/audit green + macro authorization = merge automático

Quando uma missão autoriza merge e todos os gates técnicos estão verdes,
Claude executa o merge sem solicitar nova confirmação do Owner.

Stop conditions que impedem merge automático:
- P0/P1 sem solução técnica segura
- perda potencial de dados
- operação financeira LIVE
- alteração destrutiva de produção

## RULE 12 — release readiness é separado de development integration

Integrar código em `main` ≠ estar pronto para lançamento comercial.

Release readiness requer adicionalmente:
- Owner Physical Gate (teste manual)
- Smoke test pós-deploy
- Confirmação de integridade de produção

---

## Fluxo padrão

```
mission branch
  → implementation
  → tests
  → independent audit (Codex ou equivalente)
  → corrections
  → CI green
  → merge main
  → verify main
  → release/deploy gate    ← evento separado
  → production
```

---

## Classificação de migrations

O arquivo `supabase/migration_manifest.tsv` usa três status:

| Status             | Significado                                         |
|--------------------|-----------------------------------------------------|
| APPLIED_PRODUCTION | Aplicada em produção. Conteúdo FROZEN.              |
| LAB                | Não aplicada fora de bancos descartáveis.           |
| DO_NOT_APPLY       | Bloqueada permanentemente. Requer missão para reclassificar. |

**Nunca** aplicar migrations `LAB` ou `DO_NOT_APPLY` em produção sem
reclassificação explícita em missão autorizada pelo Owner.

---

## Migrations DO_NOT_APPLY em vigor

| Migration                              | Motivo                           |
|----------------------------------------|----------------------------------|
| 20261014000000_free_quota_15.sql       | FREE quota commercial decision pending Owner — servidor em FREE=5 |

---

*Documento estabelecido por IV-MAIN-RECONCILIATION-01 · 2026-09-30*
