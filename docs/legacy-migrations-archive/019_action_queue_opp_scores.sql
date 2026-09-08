-- Migration 019: preserve opportunity scores in action_queue
-- Adds market_score, confidence and market_analysis_id so the full
-- context from OpportunityLabItem is stored without loss.

ALTER TABLE action_queue
  ADD COLUMN IF NOT EXISTS market_score        INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS confidence          INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS market_analysis_id  UUID REFERENCES market_analyses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS action_queue_market_analysis_id_idx
  ON action_queue(market_analysis_id);
