# Day 03 Analysis: Transform API, Auth Stub & Rate Limit

## Objective

Expose **`POST /v1/transform`** (or `/v1/transform` aligned with [spec/api_endpoints.md](../spec/api_endpoints.md)), validate DTO (`text`, `mode`, `action`, `locale`, optional `theme`), apply **device Bearer** stub, enforce **Redis rate limit**, call Day 02 pipeline, return JSON `result` + metadata.

## Architecture & Packages

- **Module:** `transform/` — controller + service orchestrating prompt + Gemini + post-trim.
- **Module:** `auth/` — `DeviceAuthGuard` accepting `Authorization: Bearer` (MVP: register endpoint or static test token until Day 13 persistence).
- **Module:** `usage/` — Redis counter per device / hour.

### Backend Endpoints

- **New:** `POST /v1/transform` — contract per [spec/api_endpoints.md](../spec/api_endpoints.md).
- **Optional same day:** `POST /v1/device/register` returning `deviceToken` for real device flow.

## Tasks

1. DTO validation + max body size (e.g. 4 KB text).
2. Wire `TransformService` → `PromptTemplateService` → `GeminiClient`.
3. Map Gemini failures to `502` / `504` and validation to `400` per API doc.
4. Redis rate limit guard (e.g. 50 req/hour/device); return `429` + headers if specified in spec.
5. Postman / curl collection or `README` snippet for manual test.

## UI / Client Focus

- None (Android wires to this API on Day 05).

## Checklist

- [ ] `POST /v1/transform` returns 200 for valid sample TR text
- [ ] Invalid `mode`/`action` → 400 `INVALID_INPUT`
- [ ] Rate limit triggers 429 after threshold in dev
- [ ] Errors match documented codes

## Related

- [spec/api_endpoints.md](../spec/api_endpoints.md) · [spec/architecture.md](../spec/architecture.md)
