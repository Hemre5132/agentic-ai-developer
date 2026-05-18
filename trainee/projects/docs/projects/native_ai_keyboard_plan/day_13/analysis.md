# Day 13 Analysis: Settings Persistence & Cross-Platform QA

## Objective

Persist **default mode**, **theme**, and **locale** across keyboard relaunch: Android `SharedPreferences`, iOS App Group **UserDefaults**. Implement or finalize **`GET/PUT /settings`** on backend if in scope. Run **cross-platform QA**: empty text, max length, offline, timeout, rate limit, wrong token.

## Architecture & Packages

- **Backend:** `settings` module + DB tables per [spec/architecture.md](../spec/architecture.md).
- **Clients:** sync on launch and after change; debounce writes.

### Backend Endpoints

- **Used:** `GET /v1/settings`, `PUT /v1/settings` (per [spec/api_endpoints.md](../spec/api_endpoints.md)); `POST /v1/transform` for regression.

## Tasks

1. Wire settings API to PostgreSQL `settings` row per device.
2. Android: read/write prefs + optional sync from server.
3. iOS: App Group suite; migrate local-only keys if any.
4. QA matrix spreadsheet: 10 rows min (both platforms).
5. Fix P0/P1 bugs found; defer P2 with tickets.

## UI / Client Focus

- Minimal settings UI can live in keyboard overflow menu or companion stub activity.

## Checklist

- [ ] Settings survive process kill on both OSes
- [ ] Server settings round-trip (if enabled)
- [ ] QA matrix attached to PR or wiki

## Related

- [spec/api_endpoints.md](../spec/api_endpoints.md) · [spec/architecture.md](../spec/architecture.md)
