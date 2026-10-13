# Production Promotion Bundle — FASE B (rev 2026-10-13)
# IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01
# SHA base: 7fb2dd0 | atualizado de 6bd4663 (adição migration 00015 + correção SHAs 00013/00014)
# Autoridade: Agente Martins + Paulo | PRODUCTION PROTECTION ACTIVE

---

## Pré-condições

Antes de iniciar qualquer passo:
- [ ] Owner confirma janela de manutenção aberta
- [ ] Supabase Dashboard acessível (Owner)
- [ ] Stripe Dashboard acessível em modo TEST (não ativar LIVE)
- [ ] Edge Functions CLI (`supabase functions deploy`) disponível
- [ ] Todos os commits presentes em origin/main (SHA atual: `7fb2dd0`)

---

## Passos Obrigatórios (em ordem estrita — não pular)

### PASSO 1 — Criar Vault secret para reconciler (Owner)
**Pré-requisito para migração 00013**

No Supabase SQL Editor da instância de PRODUÇÃO:
```sql
SELECT vault.create_secret(
  '<STRONG_RANDOM_SECRET_MIN_32_CHARS>',  -- gerar com: openssl rand -base64 32
  'entitlement_reconcile_secret',
  'Dedicated auth token for pg_cron → entitlement-reconcile Edge Function (EA-01)'
);
```
Verificar:
```sql
SELECT id, name FROM vault.secrets WHERE name = 'entitlement_reconcile_secret';
-- deve retornar exatamente 1 linha
```
⚠️ O valor do secret NUNCA aparece em logs. Copiar para o passo 7.

---

### PASSO 2 — Aplicar migration 00010 (null_event_id_tiebreak_fix)
```sql
-- Conteúdo: supabase/migrations/20261016000010_null_event_id_tiebreak_fix.sql
-- SHA-256: 121f2d4a464a3e71d8b538cfaaf0d71576568b275319118f96fc420529c44fad
```
Verificar: `SELECT * FROM pg_proc WHERE proname = 'upsert_product_subscription'` — confirmar que EXISTS.

---

### PASSO 3 — Aplicar migration 00011 (reconciler_http_exception_guard)
```sql
-- Conteúdo: supabase/migrations/20261016000011_reconciler_http_exception_guard.sql
-- SHA-256: 52f0790b9c1dace7f2d6e747e66cd8eb7a57c58aeab6795b88ac1ee2eb72f7c0
```

---

### PASSO 4 — Aplicar migration 00012 (localization_quota_reservation)
```sql
-- Conteúdo: supabase/migrations/20261016000012_localization_quota_reservation.sql
-- SHA-256: 5cb12495114f5af438876c48d1f21cc6a01d1649b1c39279c4d78928f606f8a9
```
Verificar RPC disponível (OBRIGATÓRIO antes do passo 8):
```sql
SELECT public.try_reserve_localization_slot(
  '00000000-0000-0000-0000-000000000001'::uuid,
  1
);
-- deve retornar: false (sem usuário real, cap=1 já atingida ou usuário inexistente)
-- QUALQUER retorno sem EXCEPTION = RPC disponível
```
**SE este teste lançar EXCEPTION → NÃO aplicar migration 00012 e PARAR.**

---

### PASSO 5 — Aplicar migration 00013 (vault_reconciler_auth)
**Depende do PASSO 1 (Vault secret criado)**
```sql
-- Conteúdo: supabase/migrations/20261016000013_vault_reconciler_auth.sql
-- SHA-256: be3c5a03a7154d9693ecfc565ae46c76da50958a4e7ce6d4ceadef2880551dae
```
Verificar:
```sql
SELECT routines.routine_name, routine_definition
FROM information_schema.routines
WHERE routine_name = 'invoke_entitlement_reconciler';
-- confirmar que a definição referencia 'entitlement_reconcile_secret' (não app.service_role_key)
```

---

### PASSO 6 — Aplicar migration 00014 (aef_hardening_ea02)
```sql
-- Conteúdo: supabase/migrations/20261016000014_aef_hardening_ea02.sql
-- SHA-256: b43f6a4bba834c5f88d21c19e42e8b33a108afbab0507965cdeb588a4b4fcc84
```
Teste de smoke (verificar novos failure codes):
```sql
-- Usuário inexistente deve retornar AEF_CALLER_INACTIVE
SELECT public.aef_submit_action(
  gen_random_uuid(), 'test-corr', '00000000-0000-0000-0000-000000000001'::uuid,
  gen_random_uuid(), 'impact-lab', 'REQUEST_MANUAL_VERIFICATION',
  gen_random_uuid(), gen_random_uuid(), 'READ_ONLY', now(),
  'AUTHORIZED', '1.0', 'test', NULL, NULL,
  gen_random_uuid(), repeat('a', 64), 'AUTHORIZED', now()
);
-- expected: {"ok": false, "code": "AEF_CALLER_INACTIVE"}
```

---

### PASSO 7 — Aplicar migration 00015 (security_definer_grant_hardening)
**Independente — pode ser aplicada em qualquer ponto após PASSO 2**
```sql
-- Conteúdo: supabase/migrations/20261016000015_security_definer_grant_hardening.sql
-- SHA-256: 6b64e9021a06c70248d487aefa8ccf02dce07e0cbea241ce5ed3c76a7b1b9380
```
Contexto: REVOKE EXECUTE from PUBLIC/anon/authenticated nas funções trigger-only
(handle_new_user, validate_asset_id_ownership, validate_asset_parent_ownership,
validate_asset_resource_ownership). Fecha a superfície REST /rpc/<name>. Idempotente.

Verificar após aplicar:
```sql
SELECT has_function_privilege('anon', 'public.handle_new_user()', 'EXECUTE');
-- expected: false

SELECT has_function_privilege('authenticated', 'public.validate_asset_id_ownership()', 'EXECUTE');
-- expected: false
```
⚠️ is_admin_user() e get_current_user_role() NÃO devem ser revogados — usados em RLS
sem cláusula TO (quebra queries em todas as tabelas). Codex D validou esse escopo em 4 rodadas.

---

### PASSO 8 — Configurar env var ENTITLEMENT_RECONCILE_SECRET no Edge Function
No Supabase Dashboard → Edge Functions → entitlement-reconcile → Environment Variables:
```
ENTITLEMENT_RECONCILE_SECRET = <mesmo valor criado no PASSO 1>
```
⚠️ Não incluir o valor do secret em logs ou relatórios.

---

### PASSO 9 — Fazer deploy do Edge Function `localize-content`
**Depende do PASSO 4 — RPC smoke test passou**
```bash
supabase functions deploy localize-content --project-ref <project-ref>
```
Smoke test pós-deploy:
```bash
curl -X POST https://<project>.supabase.co/functions/v1/localize-content \
  -H "Authorization: Bearer <user-anon-token>" \
  -H "Content-Type: application/json" \
  -d '{"table":"impact_investigations","ids":[],"language":"pt-BR"}'
# expected: {"items":{}}  (200 OK)
```
**SE retornar 503 com `quota_rpc_unavailable` → migration 00012 NÃO foi aplicada. Parar e aplicar PASSO 4.**

---

### PASSO 10 — Fazer deploy do Edge Function `entitlement-reconcile`
**Depende do PASSO 8 — env var configurada**
```bash
supabase functions deploy entitlement-reconcile --project-ref <project-ref>
```
Smoke test pós-deploy (verificar autenticação com novo token):
```bash
curl -X POST https://<project>.supabase.co/functions/v1/entitlement-reconcile \
  -H "Authorization: Bearer <ENTITLEMENT_RECONCILE_SECRET>" \
  -d '{}'
# expected: 200 com { "ok": true, ... }
```

---

### PASSO 11 — Remover GUC legado (após confirmar deploy OK)
**Opcional mas recomendado para eliminar o risco EA-01 completamente**
No Supabase SQL Editor:
```sql
-- Verificar que invoke_entitlement_reconciler NÃO lê mais app.service_role_key
-- antes de executar este comando:
ALTER DATABASE <db_name> RESET app.service_role_key;
```
⚠️ Verificar primeiro se algum outro objeto usa `current_setting('app.service_role_key')`:
```sql
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_definition ILIKE '%service_role_key%';
-- SE retornar linhas além de invoke_entitlement_reconciler → NÃO executar RESET
```

---

### PASSO 12 — Atualizar pg_cron schedule (se já existia com service_role_key)
Se o schedule do pg_cron estava passando o service_role_key como Bearer token:
```sql
-- Verificar schedule atual:
SELECT * FROM cron.job WHERE jobname = 'invoke-entitlement-reconciler';

-- Se precisar atualizar (agora usa a função que lê do Vault):
-- O pg_cron chama invoke_entitlement_reconciler() diretamente (SQL, não HTTP)
-- Nenhuma alteração no schedule é necessária — a função já lê do Vault.
```

---

### PASSO 13 — Atualizar migration_manifest.tsv com status APPLIED_PRODUCTION
Após confirmar todos os passos acima:
```tsv
20261016000010_null_event_id_tiebreak_fix.sql                APPLIED_PRODUCTION
20261016000011_reconciler_http_exception_guard.sql           APPLIED_PRODUCTION
20261016000012_localization_quota_reservation.sql            APPLIED_PRODUCTION
20261016000013_vault_reconciler_auth.sql                     APPLIED_PRODUCTION
20261016000014_aef_hardening_ea02.sql                        APPLIED_PRODUCTION
20261016000015_security_definer_grant_hardening.sql          APPLIED_PRODUCTION
```

---

## Rollback de Emergência

### Se migration 00012 causar problemas:
```sql
DROP FUNCTION IF EXISTS public.try_reserve_localization_slot(uuid, int);
DROP TABLE IF EXISTS public.localization_quota_log;
```
Então re-deploy do Edge Function `localize-content` para a versão anterior (sem `reserveOneSlot`).

### Se migration 00013 causar problemas:
Restaurar do backup da função `invoke_entitlement_reconciler` (conteúdo da migration 00011).

### Se migration 00014 causar problemas:
Restaurar do backup da função `aef_submit_action` (conteúdo da migration 20261007000002).

### Se migration 00015 causar problemas:
Restaurar os GRANTs removidos:
```sql
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_asset_id_ownership() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_asset_parent_ownership() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_asset_resource_ownership() TO PUBLIC;
```
⚠️ Isso reexpõe o surface REST dessas funções trigger. Aplicar rollback apenas se
houver evidência de que o REVOKE quebrou alguma trigger de produção (improvável —
PostgreSQL não verifica EXECUTE grants em invocações de trigger).

---

## Estado Final Esperado

```
Migration 00010: APPLIED_PRODUCTION — null event_id tie-break corrigido
Migration 00011: APPLIED_PRODUCTION — pg_net exception guard
Migration 00012: APPLIED_PRODUCTION — quota reservation atômica
Migration 00013: APPLIED_PRODUCTION — Vault credential para reconciler
Migration 00014: APPLIED_PRODUCTION — AEF is_active + entitlement + current_period_end
Migration 00015: APPLIED_PRODUCTION — SECURITY DEFINER trigger functions revoked (REST surface fechada)
Edge Function localize-content: DEPLOYED (fail-closed, atomic quota)
Edge Function entitlement-reconcile: DEPLOYED (aceita ENTITLEMENT_RECONCILE_SECRET)
GUC app.service_role_key: REMOVED (após PASSO 11)
```

---

## Autoridade de Aprovação

PRODUCTION PROTECTION ACTIVE — este bundle requer gate AM+Paulo antes de execução.
NÃO aplicar sem autorização explícita de Agente Martins e Paulo.
