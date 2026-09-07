-- Migration 021 — Adiciona coluna 'plan' ao action_queue
-- A migration 017 criou esta coluna mas não foi aplicada em produção.
-- A migration 020 adicionou 'action_steps' por engano — mantemos ambas
-- para compatibilidade com futuros campos, mas 'plan' é o campo canônico
-- usado pelo modelo Dart ActionQueueItem.

ALTER TABLE action_queue
  ADD COLUMN IF NOT EXISTS plan JSONB DEFAULT '[]';

COMMENT ON COLUMN action_queue.plan IS 'Plano de execução em passos (lista de strings)';
