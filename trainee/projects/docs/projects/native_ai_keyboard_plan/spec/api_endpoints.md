# Native AI Keyboard — API Endpoints

REST API contract. Example MVP base URL: `https://api.native-ai-keyboard.example/v1`

## Authentication

MVP: Bearer auth using `device_token` returned after device registration.

```
Authorization: Bearer <device_token>
```

## 1. Health

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/health` | Service health check |

**Response 200:**

```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

## 2. Device Registration

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/device/register` | Register a new device |

**Request:**

```json
{
  "platform": "android",
  "locale": "tr"
}
```

**Response 201:**

```json
{
  "deviceId": "uuid",
  "deviceToken": "secret-token",
  "expiresAt": null
}
```

## 3. Transform (core)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/transform` | Transform text by mode and action via AI |

**Request:**

```json
{
  "text": "merhaba yarın toplantı var mısın müsait",
  "mode": "work",
  "action": "correct",
  "locale": "tr"
}
```

| Field | Type | Required | Values |
|-------|------|----------|--------|
| `text` | string | yes | 1–4000 characters |
| `mode` | string | yes | `work`, `friends`, `family`, `flirt` |
| `action` | string | yes | `correct`, `rewrite`, `shorten`, `expand` |
| `locale` | string | no | `tr`, `en` (default: `tr`) |

**Response 200:**

```json
{
  "result": "Merhaba, yarın toplantı için müsait misiniz?",
  "mode": "work",
  "action": "correct",
  "locale": "tr",
  "tokensUsed": 128,
  "latencyMs": 840
}
```

**Errors:**

| HTTP | Code | Description |
|------|------|-------------|
| 400 | `INVALID_INPUT` | Missing or invalid field |
| 401 | `UNAUTHORIZED` | Invalid token |
| 429 | `RATE_LIMIT_EXCEEDED` | Quota exceeded |
| 502 | `AI_UNAVAILABLE` | Gemini error |
| 504 | `AI_TIMEOUT` | Request timeout |

## 4. Modes & Actions (metadata)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/modes` | List supported modes |
| `GET` | `/actions` | List supported actions |

**GET /modes — Response:**

```json
{
  "modes": [
    { "id": "work", "label": { "tr": "İş", "en": "Work" } },
    { "id": "friends", "label": { "tr": "Arkadaş", "en": "Friends" } },
    { "id": "family", "label": { "tr": "Aile", "en": "Family" } },
    { "id": "flirt", "label": { "tr": "Flört", "en": "Flirt" } }
  ]
}
```

**GET /actions — Response:**

```json
{
  "actions": [
    { "id": "correct", "label": { "tr": "Düzelt", "en": "Correct" } },
    { "id": "rewrite", "label": { "tr": "Yeniden yaz", "en": "Rewrite" } },
    { "id": "shorten", "label": { "tr": "Kısalt", "en": "Shorten" } },
    { "id": "expand", "label": { "tr": "Uzat", "en": "Expand" } }
  ]
}
```

## 5. Settings

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/settings` | Get device settings |
| `PUT` | `/settings` | Update device settings |

**GET /settings — Response:**

```json
{
  "defaultMode": "work",
  "theme": "system",
  "locale": "tr"
}
```

**PUT /settings — Request:**

```json
{
  "defaultMode": "friends",
  "theme": "dark",
  "locale": "tr"
}
```

## 6. Prompt Preview (development only)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/prompts/preview` | Preview system prompt for mode + action |

**Query:** `?mode=work&action=correct&locale=tr`

> Must be disabled in production.

## Rate Limiting

- Headers: `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- MVP recommendation: 50 requests / hour / `device_token`
