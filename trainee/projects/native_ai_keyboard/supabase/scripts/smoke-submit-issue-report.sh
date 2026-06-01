#!/usr/bin/env bash
# End-to-end smoke for submit-issue-report (local or hosted).
# Local default: SUPABASE_FUNCTIONS_BASE=http://127.0.0.1:54321/functions/v1
# Hosted: SUPABASE_FUNCTIONS_BASE=https://<project-ref>.supabase.co/functions/v1
set -euo pipefail
BASE="${SUPABASE_FUNCTIONS_BASE:-http://127.0.0.1:54321/functions/v1}"
echo "Using BASE=$BASE"

reg=$(curl -sS -X POST "$BASE/register-device" -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"smoke-issue-$(date +%s)\",\"platform\":\"ios\",\"locale\":\"tr\"}")
echo "$reg" | python3 -m json.tool
TOKEN=$(echo "$reg" | python3 -c "import sys,json; print(json.load(sys.stdin)['deviceToken'])")

payload='{"body":"Smoke test issue report body (>=10 chars).","appVersion":"0","build":"smoke","osVersion":"17.0","localeIdentifier":"tr_TR","preferredLanguages":"tr-TR"}'

echo "--- First submit (expect 201) ---"
first=$(curl -sS -w "\n%{http_code}" -X POST "$BASE/submit-issue-report" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$payload")
code=$(echo "$first" | tail -n1)
body=$(echo "$first" | sed '$d')
echo "$body" | python3 -m json.tool
test "$code" = "201" || { echo "Expected HTTP 201, got $code"; exit 1; }

echo "--- Second submit same UTC day (expect 429) ---"
second=$(curl -sS -w "\n%{http_code}" -X POST "$BASE/submit-issue-report" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$payload")
code2=$(echo "$second" | tail -n1)
body2=$(echo "$second" | sed '$d')
echo "$body2" | python3 -m json.tool
test "$code2" = "429" || { echo "Expected HTTP 429, got $code2"; exit 1; }

echo "OK: submit-issue-report smoke passed."
