-- Rollback for 20261015000000_r16_content_localizations.sql.
-- Safe: the table only holds derived, re-creatable translations; no source
-- data lives here.
DROP TABLE IF EXISTS public.content_localizations;
