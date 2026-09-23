#!/usr/bin/env bash
# IV-IMPACT-I3 (Codex I3F-01) — two concurrent sessions, both orders: an
# artifact insert and a free-form evidence insert on the SAME source must be
# serialized; the second writer must fail. Runs after impact_evidence_rls_test.sql
# on the disposable database (fixtures IE / UE / c2 / org-wellspring).
# Usage: impact_evidence_race_test.sh <psql command prefix...>
set -euo pipefail
P=("$@")
IE="e3333333-0000-0000-0000-00000000000e"
UE="eeeeeeee-0000-0000-0000-00000000000e"
SUMMARY='{"type":"TEXT","status":"SUCCESS","extractorVersion":"impact-extractor/1","lines":1,"segments":1,"notes":[]}'

art() { echo "INSERT INTO public.impact_artifacts (investigation_id, ref, source_ref, artifact_type, origin_type, original_filename, media_type, size_bytes, file_hash, extraction_status, extractor_version, extraction_summary, ingested_at, created_by) VALUES ('$IE','$1','$1','TEXT','USER_UPLOAD','x.txt','text/plain',1,repeat('$2',64),'SUCCESS','impact-extractor/1','$SUMMARY','2026-09-20T00:00:00Z','$UE');"; }
ev() { echo "INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by) VALUES ('$IE','$1','c2','$2','org-wellspring','CONTEXTUALIZES','HUMAN_ASSESSED','NONE','2026-09-22T00:00:00Z','$UE');"; }

"${P[@]}" -c "SET ROLE service_role; INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, user_submitted, created_by) VALUES
  ('$IE','art-race1','USER_DOCUMENT','u','2026-09-20T00:00:00Z','HASH_ONLY',repeat('6',64),'USER_UPLOAD',true,'$UE'),
  ('$IE','art-race2','USER_DOCUMENT','u','2026-09-20T00:00:00Z','HASH_ONLY',repeat('7',64),'USER_UPLOAD',true,'$UE');" >/dev/null

race() { # $1 = first (holds the lock 2 s), $2 = second, $3 = expected error of the second
  "${P[@]}" -c "BEGIN; SET LOCAL ROLE service_role; $1 SELECT pg_sleep(2); COMMIT;" >/dev/null 2>&1 &
  local holder=$!
  sleep 0.7
  local out
  if out="$("${P[@]}" -c "SET ROLE service_role; $2" 2>&1)"; then
    echo "IMPACT_EVIDENCE_RACE: FAIL (second writer succeeded)"; wait "$holder"; exit 1
  fi
  wait "$holder"
  echo "$out" | grep -q "$3" || { echo "IMPACT_EVIDENCE_RACE: FAIL (wrong error: $out)"; exit 1; }
}
race "$(art art-race1 6)" "$(ev e-race1 art-race1)" 'IMPACT_ARTIFACT_EVIDENCE_INVALID'
race "$(ev e-race2 art-race2)" "$(art art-race2 7)" 'IMPACT_ARTIFACT_SOURCE_INVALID'

got="$("${P[@]}" -tA -c "SELECT (SELECT count(*) FROM public.impact_artifacts WHERE ref LIKE 'art-race%') || '/' || (SELECT count(*) FROM public.impact_evidence WHERE ref LIKE 'e-race%') || '/' || public.impact_audit_chain_ok('$IE');")"
[ "$got" = "1/1/true" ] || { echo "IMPACT_EVIDENCE_RACE: FAIL (state $got)"; exit 1; }
echo "IMPACT_EVIDENCE_RACE: PASS 2 orders"
