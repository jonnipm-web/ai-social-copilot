-- ============================================================
-- 010_phase10a_chain_fixes.sql
-- Corrigir cadeias FK quebradas: analysis→lab→action→roi
-- ============================================================

-- ── 1. Vincular opportunity_lab à análise de mercado de origem ──
ALTER TABLE public.opportunity_lab
  ADD COLUMN IF NOT EXISTS market_analysis_id UUID
    REFERENCES public.market_analyses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_opportunity_lab_analysis
  ON public.opportunity_lab(market_analysis_id);

-- ── 2. Vincular action_queue ao item do Opportunity Lab de origem ──
ALTER TABLE public.action_queue
  ADD COLUMN IF NOT EXISTS opportunity_lab_id UUID
    REFERENCES public.opportunity_lab(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_action_queue_opportunity
  ON public.action_queue(opportunity_lab_id);
