#!/usr/bin/env bash
# IV-IMPACT-I5 — two concurrent sessions of the SAME caller hit the same
# rate-limit window: the second waits on the row lock and must see count 2
# (never a lost update). Runs after impact_rate_limit_test.sql.
# Usage: impact_rate_limit_race_test.sh <psql command prefix...>
set -euo pipefail
P=("$@")
U="55555555-0000-0000-0000-000000000005"
"${P[@]}" -c "INSERT INTO auth.users (id, email) VALUES ('$U', 'user-race@test.invalid') ON CONFLICT (id) DO NOTHING;" >/dev/null
as_user="SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$U', true); SELECT set_config('request.jwt.claim.role', 'authenticated', true);"

PGAPPNAME=impact-rl-holder "${P[@]}" -c "BEGIN; $as_user SELECT hit_count FROM public.impact_rate_limit_hit('dossier_export', 3600); SELECT pg_sleep(3); COMMIT;" >/dev/null 2>&1 &
holder=$!
tries=0
until [ "$("${P[@]}" -tA -c "SELECT count(*) FROM pg_stat_activity WHERE application_name = 'impact-rl-holder' AND wait_event = 'PgSleep'")" = "1" ]; do
  tries=$((tries + 1))
  if [ "$tries" -gt 100 ]; then echo "IMPACT_RATE_LIMIT_RACE: FAIL (holder never reached its sleep)"; wait "$holder" || true; exit 1; fi
  sleep 0.1
done
second="$("${P[@]}" -tA -c "BEGIN; $as_user SELECT 'COUNT=' || hit_count FROM public.impact_rate_limit_hit('dossier_export', 3600); COMMIT;" | grep '^COUNT=' || true)"
wait "$holder"
[ "$second" = "COUNT=2" ] || { echo "IMPACT_RATE_LIMIT_RACE: FAIL (second session saw '$second', expected COUNT=2)"; exit 1; }
total="$("${P[@]}" -tA -c "SELECT sum(hit_count) FROM public.impact_rate_limits WHERE user_id = '$U' AND bucket = 'dossier_export';")"
[ "$total" = "2" ] || { echo "IMPACT_RATE_LIMIT_RACE: FAIL (stored count $total)"; exit 1; }
echo "IMPACT_RATE_LIMIT_RACE: PASS no lost update"
