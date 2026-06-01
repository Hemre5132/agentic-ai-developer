# Edge Functions

Implement handlers here, for example:

- `register-device/` — device registration; returns opaque `deviceToken`
- `transform/` — Gemini transform (`action`: `rewrite`, `correct` / improve, `shorten`, `expand`); requires `Authorization: Bearer <deviceToken>`
- `submit-issue-report/` — one issue per device per UTC day; inserts `issue_reports` and emails the owner via **Resend** when `RESEND_API_KEY` + `REPORT_TO_EMAIL` secrets are set

Deploy:

```bash
supabase functions deploy register-device
supabase functions deploy transform
supabase functions deploy submit-issue-report
```

Secrets (Dashboard → Edge → Secrets or `supabase secrets set`):

| Secret | Purpose |
|--------|---------|
| `RESEND_API_KEY` | Resend API key (free tier) |
| `REPORT_TO_EMAIL` | Inbox that receives copies (e.g. `aliozten92@gmail.com`) |
| `RESEND_FROM` | Optional verified sender; default Resend sandbox `onboarding@resend.dev` |
| `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT` | **`true` only for testing** — skips the “one report per device per UTC day” check on the server. Omit or set `false` in production. |

**Mail gelmiyorsa:** Dashboard → **Project Settings → Edge Functions → Secrets** içinde `RESEND_API_KEY` ve `REPORT_TO_EMAIL` gerçekten tanımlı mı kontrol et (`supabase secrets list`). Ardından Resend panelinde **Logs** / **Emails** bak. **`onboarding@resend.dev`** (varsayılan gönderici) ile Resend çoğu zaman yalnızca **Resend hesabını açtığın e-posta adresine** teslim eder; `aliozten92@gmail.com` farklıysa gelmez — ya **`REPORT_TO_EMAIL`**’i o hesaba eşitle ya da kendi domainini doğrula ve **`RESEND_FROM`** olarak kullan (`AI Keyboard <bildirim@senindomainin.com>`). Spam klasörünü de kontrol et. Edge yanıtındaki **`mailDetail`** ve Supabase **Function logs** (`[submit-issue-report] mail sent` / `mail not sent`) teşhis için yeterlidir. Kalıcı takip: [`docs/OPEN_ISSUES.md`](../../docs/OPEN_ISSUES.md) madde 1.

Shared modules can live under `_shared/`.

**Smoke test** (register → submit → expect 429 on second submit): from `trainee/projects/native_ai_keyboard`, run `./supabase/scripts/smoke-submit-issue-report.sh` (see [`../README.md`](../README.md) for `SUPABASE_FUNCTIONS_BASE` on hosted).
