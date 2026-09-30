#!/usr/bin/env bash
# IV-IMPACT-I4 (I3F-03) — two concurrent sessions: (1) the same file ingested
# twice at once under different refs through the atomic RPC — exactly one
# source + one artifact survive, the loser leaves NO orphan source; (2) the
# same dossier content registered twice at once — one registration, the
# other is a unique violation (the Lab turns it into an idempotent replay).
# Runs after impact_dossier_rls_test.sql (fixtures IG / UG).
# Usage: impact_dossier_race_test.sh <psql command prefix...>
set -euo pipefail
P=("$@")
IG="90000000-0000-0000-0000-000000000009"
UG="99999999-0000-0000-0000-000000000009"

bundle() { # $1 ref, $2 hash char
  echo "SELECT public.impact_ingest_artifact('$IG', pg_temp.pg_temp_src('$1', '$2'), pg_temp.pg_temp_art('$1', '$2'), '[]'::jsonb);"
}
# Session-local helpers (temp functions do not cross sessions): inline the rows.
helpers="CREATE FUNCTION pg_temp.pg_temp_src(r text, h text) RETURNS jsonb LANGUAGE sql AS \$\$ SELECT jsonb_build_object('investigation_id','$IG','ref',r,'source_type','USER_DOCUMENT','publisher','User upload','retrieved_at','2026-09-20T00:00:00Z','retention','HASH_ONLY','content_hash',repeat(h,64),'acquisition_method','USER_UPLOAD','user_submitted',true,'created_by','$UG') \$\$;
CREATE FUNCTION pg_temp.pg_temp_art(r text, h text) RETURNS jsonb LANGUAGE sql AS \$\$ SELECT jsonb_build_object('investigation_id','$IG','ref',r,'source_ref',r,'artifact_type','TEXT','origin_type','USER_UPLOAD','original_filename','r.txt','media_type','text/plain','size_bytes',10,'file_hash',repeat(h,64),'hash_algorithm','SHA-256','version',1,'extraction_status','SUCCESS','extractor_version','impact-extractor/1','extraction_summary',jsonb_build_object('type','TEXT','status','SUCCESS','extractorVersion','impact-extractor/1','lines',2,'segments',2,'notes','[]'::jsonb),'ingested_at','2026-09-20T00:00:00Z','created_by','$UG') \$\$;"
snap() { # $1 hash char
  echo "INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by) SELECT '$IG', 'dossier-' || repeat('$1', 24), 'impact-dossier/1', repeat('$1', 64), 'INCOMPLETE', 0, e.seq, e.hash, '2026-09-24T00:00:00Z', '$UG' FROM public.impact_audit_events e WHERE e.investigation_id = '$IG' AND e.seq = 1;"
}

race() { # $1 = first (holds its locks), $2 = second, $3 = expected error of the second
  PGAPPNAME=impact-dossier-race-holder "${P[@]}" -c "BEGIN; $helpers SET LOCAL ROLE service_role; $1 SELECT pg_sleep(3); COMMIT;" >/dev/null 2>&1 &
  local holder=$!
  local tries=0
  until [ "$("${P[@]}" -tA -c "SELECT count(*) FROM pg_stat_activity WHERE application_name = 'impact-dossier-race-holder' AND wait_event = 'PgSleep'")" = "1" ]; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then echo "IMPACT_DOSSIER_RACE: FAIL (holder never reached its sleep)"; wait "$holder" || true; exit 1; fi
    sleep 0.1
  done
  local out
  if out="$("${P[@]}" -c "BEGIN; $helpers SET LOCAL ROLE service_role; $2 COMMIT;" 2>&1)"; then
    echo "IMPACT_DOSSIER_RACE: FAIL (second writer succeeded)"; wait "$holder"; exit 1
  fi
  wait "$holder"
  echo "$out" | grep -q "$3" || { echo "IMPACT_DOSSIER_RACE: FAIL (wrong error: $out)"; exit 1; }
}
# (1) same bytes, two refs, at once: the second bundle waits, then hits the per-investigation hash unique.
race "$(bundle art-race-1 9)" "$(bundle art-race-2 9)" 'impact_artifacts_hash_key'
# (2) the same dossier content registered twice at once.
race "$(snap 9)" "$(snap 9)" 'impact_dossier_snapshots_[a-z]*_key'

got="$("${P[@]}" -tA -c "SELECT (SELECT count(*) FROM public.impact_sources WHERE investigation_id = '$IG' AND ref LIKE 'art-race-%') || '/' || (SELECT count(*) FROM public.impact_artifacts WHERE investigation_id = '$IG' AND ref LIKE 'art-race-%') || '/' || (SELECT count(*) FROM public.impact_dossier_snapshots WHERE investigation_id = '$IG' AND content_hash = repeat('9', 64)) || '/' || public.impact_audit_chain_ok('$IG');")"
[ "$got" = "1/1/1/true" ] || { echo "IMPACT_DOSSIER_RACE: FAIL (state $got — an orphan source or a duplicate survived)"; exit 1; }
echo "IMPACT_DOSSIER_RACE: PASS 2 races"
