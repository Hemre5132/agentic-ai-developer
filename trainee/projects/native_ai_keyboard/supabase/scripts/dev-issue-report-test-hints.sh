#!/usr/bin/env bash
# Prints one-off commands for same-day issue-report testing (dev only).
# iOS: ensure AIKeyboard/Info.plist has AIKeyboardIssueReportBypassDailyLimit = true (repo default for dev).
set -euo pipefail
cat <<'EOF'
Issue report — dev test (same calendar / UTC day)

Run this file from either directory:

  Monorepo root (folder that contains trainee/):
  ./trainee/projects/native_ai_keyboard/supabase/scripts/dev-issue-report-test-hints.sh

  native_ai_keyboard package root (folder that contains supabase/):
  ./supabase/scripts/dev-issue-report-test-hints.sh

Do not paste shell lines that include " # turkish comment" at the end — zsh may error. Put comments on a new line or omit them.

---

1) iOS (already in repo for dev): AIKeyboard/Info.plist → AIKeyboardIssueReportBypassDailyLimit = true
   → Rebuild host app. Orange banner appears in the sheet.

2) Supabase hosted — skip UTC-day server limit (testing ONLY; remove before App Store).
   Run these two lines on their own (no trailing comment on the same line):

   supabase secrets set ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT=true
   supabase functions deploy submit-issue-report

3) Turn OFF when done:
   - plist: AIKeyboardIssueReportBypassDailyLimit → false
   - Dashboard → Edge → Secrets: delete ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT or set to false, redeploy function

EOF
