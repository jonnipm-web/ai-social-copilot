-- ============================================================
-- FASE 11 — EXECUTIVE INTELLIGENCE: Schema Validation Script
-- Data: 2026-07-29
-- Execução: Supabase SQL Editor (dev/homologation)
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. VERIFICA TABELAS CRIADAS
-- ──────────────────────────────────────────────────────────

SELECT
  table_name,
  CASE WHEN table_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END AS status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('project_events', 'executive_contexts')
ORDER BY table_name;

-- ──────────────────────────────────────────────────────────
-- 2. VERIFICA COLUNAS: project_events
-- ──────────────────────────────────────────────────────────

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'project_events'
ORDER BY ordinal_position;

-- ──────────────────────────────────────────────────────────
-- 3. VERIFICA COLUNAS: executive_contexts
-- ──────────────────────────────────────────────────────────

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'executive_contexts'
ORDER BY ordinal_position;

-- ──────────────────────────────────────────────────────────
-- 4. VERIFICA ÍNDICES
-- ──────────────────────────────────────────────────────────

SELECT
  indexname,
  tablename,
  indexdef
FROM pg_indexes
WHERE tablename IN ('project_events', 'executive_contexts')
  AND schemaname = 'public'
ORDER BY tablename, indexname;

-- ──────────────────────────────────────────────────────────
-- 5. VERIFICA RLS HABILITADO
-- ──────────────────────────────────────────────────────────

SELECT
  tablename,
  rowsecurity,
  CASE WHEN rowsecurity THEN '✅ RLS ON' ELSE '❌ RLS OFF' END AS status
FROM pg_tables
WHERE tablename IN ('project_events', 'executive_contexts')
  AND schemaname = 'public';

-- ──────────────────────────────────────────────────────────
-- 6. VERIFICA POLICIES RLS
-- ──────────────────────────────────────────────────────────

SELECT
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('project_events', 'executive_contexts')
  AND schemaname = 'public'
ORDER BY tablename, policyname;

-- ──────────────────────────────────────────────────────────
-- 7. TESTA CONSTRAINT CHECK em project_events
-- ──────────────────────────────────────────────────────────
-- Deve retornar ERRO (violação de constraint):
-- INSERT INTO public.project_events (project_id, user_id, event_type, title)
-- VALUES (gen_random_uuid(), auth.uid(), 'INVALID_TYPE', 'Test');

-- ──────────────────────────────────────────────────────────
-- 8. TESTA IDEMPOTÊNCIA (unique partial index)
-- ──────────────────────────────────────────────────────────
-- Segunda inserção com mesmo idempotency_key deve retornar código 23505:
-- INSERT INTO public.project_events (project_id, user_id, event_type, title, idempotency_key)
-- VALUES (gen_random_uuid(), auth.uid(), 'check_in', 'Test', 'test-key-1');
-- INSERT INTO public.project_events (project_id, user_id, event_type, title, idempotency_key)
-- VALUES (gen_random_uuid(), auth.uid(), 'check_in', 'Test', 'test-key-1');
-- ^ Deve falhar com unique_violation (23505)

-- ──────────────────────────────────────────────────────────
-- 9. TESTA CONSTRAINT CHECK: priority_score em executive_contexts
-- ──────────────────────────────────────────────────────────
-- Deve retornar ERRO (violação de constraint):
-- INSERT INTO public.executive_contexts (project_id, user_id, priority_score)
-- VALUES (gen_random_uuid(), auth.uid(), 150);

-- ──────────────────────────────────────────────────────────
-- 10. VERIFICA CONTAGEM ATUAL DE REGISTROS
-- ──────────────────────────────────────────────────────────

SELECT
  'project_events' AS tabela,
  COUNT(*) AS total_registros
FROM public.project_events
UNION ALL
SELECT
  'executive_contexts' AS tabela,
  COUNT(*) AS total_registros
FROM public.executive_contexts;

-- ──────────────────────────────────────────────────────────
-- 11. SIMULAÇÃO DE EVENTO (executa como usuário autenticado)
-- ──────────────────────────────────────────────────────────
-- Substitua <PROJECT_UUID> por um UUID de projeto existente:
--
-- INSERT INTO public.project_events (
--   project_id, user_id, event_type, title, description, metadata
-- ) VALUES (
--   '<PROJECT_UUID>',
--   auth.uid(),
--   'check_in',
--   'Validação manual de schema',
--   'Inserção de teste para validação da Fase 11',
--   '{"validation": "fase11c"}'::jsonb
-- )
-- RETURNING id, event_type, created_at;

-- ──────────────────────────────────────────────────────────
-- RESULTADO ESPERADO
-- ──────────────────────────────────────────────────────────
-- ✅ project_events EXISTS
-- ✅ executive_contexts EXISTS
-- ✅ Todas as colunas presentes e com tipos corretos
-- ✅ Índices criados (project_id+created_at, user_id+created_at, idempotency_key unique partial)
-- ✅ RLS habilitado em ambas as tabelas
-- ✅ Policies: SELECT/INSERT/UPDATE/DELETE por user_id = auth.uid()
-- ✅ Constraint CHECK em event_type (valores snake_case)
-- ✅ Constraint CHECK em priority_score (0-100)
-- ✅ Unique partial index em idempotency_key
