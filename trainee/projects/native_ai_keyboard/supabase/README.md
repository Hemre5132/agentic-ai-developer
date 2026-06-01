# Supabase project (implementation)

| Path | Role |
|------|------|
| `migrations/` | Versioned SQL applied with `supabase db push` |
| `seed/` | Optional local fixtures |
| `schemas/` | Optional DDL documentation (migrations remain canonical) |
| `functions/` | Edge Functions (Deno / TypeScript) |

See [../examples/README.md](../examples/README.md) for `.env.example` templates.

Plan cross-links: [native_ai_keyboard_plan/spec/supabase_repo_layout.md](../../docs/projects/native_ai_keyboard_plan/spec/supabase_repo_layout.md).

## Issue reports (hosted checklist)

After linking the project (`supabase link`):

1. **Migrations** — ensure `issue_reports` exists (migration `20250521120000_issue_reports.sql`):

   ```bash
   supabase db push
   ```

   If the Edge function is deployed but the app still cannot save reports, the hosted database is often missing `public.issue_reports` — run **`supabase db push`** (or apply migrations in the Dashboard) **before** or right after the first function deploy.

2. **Deploy Edge** — including `submit-issue-report`:

   ```bash
   supabase functions deploy register-device
   supabase functions deploy transform
   supabase functions deploy submit-issue-report
   ```

3. **Secrets** (optional email; DB insert still succeeds without Resend):

   ```bash
   supabase secrets set RESEND_API_KEY=... REPORT_TO_EMAIL=you@example.com
   # optional:
   supabase secrets set RESEND_FROM="Verified Sender <onboarding@yourdomain>"
   ```

   **Same-day retesting (dev only):** With **`AIKeyboardIssueReportBypassDailyLimit`** = `true` in `ios-keyboard/AIKeyboard/Info.plist`, also set the Edge secret so the server accepts more than one report per UTC day:

   ```bash
   supabase secrets set ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT=true
   supabase functions deploy submit-issue-report
   ```

   Hints (from **monorepo root** `one-hundered-days/`):

   ```bash
   ./trainee/projects/native_ai_keyboard/supabase/scripts/dev-issue-report-test-hints.sh
   ```

   From **`trainee/projects/native_ai_keyboard`** only:

   ```bash
   ./supabase/scripts/dev-issue-report-test-hints.sh
   ```

   Turn both plist + Edge secret off before production.

4. **Contract smoke** (local stack or set `SUPABASE_FUNCTIONS_BASE` to your project’s `…/functions/v1`):

   ```bash
   chmod +x supabase/scripts/smoke-submit-issue-report.sh
   ./supabase/scripts/smoke-submit-issue-report.sh
   ```
