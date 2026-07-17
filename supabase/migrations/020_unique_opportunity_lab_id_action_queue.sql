-- Migration 020: enforce idempotency for Opportunity → Action Engine flow
-- Prevents duplicate actions being created for the same opportunity.
-- Deduplication: for any opportunity_lab_id with multiple actions, keep newest.

-- Step 1: remove duplicate actions (keep the most recently created per opportunity)
DELETE FROM action_queue
WHERE opportunity_lab_id IS NOT NULL
  AND id NOT IN (
    SELECT DISTINCT ON (opportunity_lab_id) id
    FROM action_queue
    WHERE opportunity_lab_id IS NOT NULL
    ORDER BY opportunity_lab_id, created_at DESC NULLS LAST
  );

-- Step 2: partial unique index (NULL values are excluded, preserving manual actions)
CREATE UNIQUE INDEX IF NOT EXISTS action_queue_opportunity_lab_id_unique
  ON action_queue(opportunity_lab_id)
  WHERE opportunity_lab_id IS NOT NULL;
