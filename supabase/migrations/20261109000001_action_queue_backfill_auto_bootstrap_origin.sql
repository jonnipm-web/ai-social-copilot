-- Actions created by AutoBootstrapService were stored without `origin`, so
-- they fell back to the column default 'manual' and the UI showed
-- "Adicionado manualmente" for system-created actions.
--
-- The only code path that writes origin='manual' together with an
-- opportunity_lab_id is that bootstrap (opportunity_lab -> 'opportunity_lab',
-- insight_service -> 'ive_analysis', manual creation has no opportunity).
-- The client now writes 'auto_bootstrap'; this fixes the existing rows.
-- Idempotent.
UPDATE public.action_queue
   SET origin = 'auto_bootstrap'
 WHERE origin = 'manual'
   AND opportunity_lab_id IS NOT NULL;
