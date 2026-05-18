# Day 02 Analysis: Gemini Client & Prompt Templates

## Objective

Integrate **Google Gemini** in the NestJS backend and implement **PromptTemplateService** so every combination of `mode`, `action`, `locale`, and optional **`theme`** (light/dark) maps to a deterministic system prompt. TR and EN template sets.

## Architecture & Packages

- **Module:** `gemini/` — thin client: timeout, single retry on 5xx, `GEMINI_API_KEY` from env.
- **Module:** `prompt/` — `PromptTemplateService`; templates in code or JSON; inputs: `mode`, `action`, `locale`, `theme?`.

### Backend Endpoints

- **None new for clients today** (optional internal `GET /prompts/preview` behind dev flag per [spec/api_endpoints.md](../spec/api_endpoints.md)).
- **Consumed internally:** Gemini `generateContent` from a test script or temporary controller (remove or guard before production).

## Tasks

1. Add `@google/generative-ai` (or chosen SDK) dependency; configure model id (e.g. flash).
2. Implement `GeminiClient.generate(systemPrompt, userText)` with max output length guard.
3. Implement all **mode × action × locale** matrix rows; add **theme-aware** phrasing where product requires different tone for dark vs light (document in template comments).
4. Unit-test at least 2 template paths (e.g. `work` + `correct` + `tr` + `light`).
5. Document env vars in `backend/.env.example` (no real keys).

## UI / Client Focus

- None.

## Checklist

- [ ] Gemini call succeeds from backend with test prompt
- [ ] All MVP mode/action/locale combinations return non-empty system strings
- [ ] Theme hook present in template API (even if same string for MVP)
- [ ] No API key in repo

## Related

- [spec/architecture.md](../spec/architecture.md) · [spec/overview.md](../spec/overview.md) (AI Integration section)
