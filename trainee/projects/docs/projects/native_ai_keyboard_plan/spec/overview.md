# Native AI Keyboard — Project Analysis

## Project Overview

**Native AI Keyboard** is an AI-powered custom keyboard extension for Android and iOS that feels close to the system keyboard experience. While composing messages or emails, users can fix typos, shorten, expand, or rewrite text using modes and actions on the keyboard—without copying text into an external AI app.

Text transformation is powered by the **Google Gemini API**; API keys are stored only on the **NestJS backend**.

## Problem Statement

When writing messages or emails in daily life and at work, people often face:

- Spelling mistakes and grammar issues
- Tone mismatches (too formal or too casual)
- Ambiguous phrasing and incomplete sentences

A common workaround is pasting text into an AI tool and repeating prompts such as:

- *"Fix spelling errors"*
- *"Write a longer version"*
- *"Make it shorter and clearer"*
- *"Rewrite in professional business language"*

This workflow is **slow**, **disruptive** (app switching), causes **loss of context**, and requires typing the same prompts over and over.

## Solution

Native AI Keyboard brings AI-assisted editing **where you type**:

| Feature | Description |
|--------|-------------|
| **4 core actions** | Correct · Rewrite · Shorten · Expand |
| **Keyboard modes** | Work · Friends · Family · Flirt (tone and prompt templates change) |
| **Color themes** | Light / dark and customizable palettes |
| **Native look & feel** | UI aligned with Android Material and iOS keyboard patterns |
| **Centralized AI** | Gemini via backend—secure and measurable |

## Goals

- Edit user text in one tap based on selected mode and action
- Remove the need to switch to external AI apps
- Deliver consistent UX on Android and iOS
- Centralize API keys and prompt logic on the backend
- Support Turkish and English text in the MVP

## Non-Goals (out of MVP scope)

- Full-screen chat app outside the keyboard
- User-defined free-form prompts (Phase 2)
- Offline / on-device models
- Windows or macOS system keyboards

## Target Audience

- Professionals who write emails and messages daily
- Users who want fast, accurate writing
- People already using AI with prompts who want that flow inside the keyboard

## Target Platforms & Languages

| Component | Platform | Language / Technology |
|-----------|----------|------------------------|
| Keyboard (Android) | Android 8+ (API 26+) | **Kotlin** — `InputMethodService` |
| Keyboard (iOS) | iOS 15+ | **Swift** — Keyboard Extension |
| Backend API | Cloud (Docker) | **TypeScript — NestJS** |
| AI service | Google AI | **Gemini API** |
| Settings app | Phase 2 | Native companion or minimal settings Activity |

See also: [day_01/analysis.md](../day_01/analysis.md) · [architecture.md](./architecture.md) · [api_endpoints.md](./api_endpoints.md) · [ui_design.md](./ui_design.md) · [roadmap.md](./roadmap.md)

## UI Preview

Reference mockup (Day 01 — light theme, default keyboard):

![Default keyboard — light theme](../assets/mockups/keyboard_default_light.png)

*Work-mode variant mockup (`keyboard_work_mode.png`) is planned for a later design pass.*

## Technical Stack

- **Mobile (keyboard):** Platform-native (Kotlin + Swift)
- **Backend:** NestJS, REST API
- **Database:** PostgreSQL (settings, usage logs)
- **Cache / rate limit:** Redis
- **AI:** Google Gemini (`gemini-2.0-flash` or current flash model)

## System Architecture

```mermaid
sequenceDiagram
  participant User
  participant Keyboard
  participant Backend
  participant Gemini

  User->>Keyboard: Types or selects text
  User->>Keyboard: Selects mode and action
  Keyboard->>Backend: POST /v1/transform
  Backend->>Backend: Build prompt template
  Backend->>Gemini: generateContent
  Gemini-->>Backend: Transformed text
  Backend-->>Keyboard: JSON response
  Keyboard->>User: Updates text in field
```

## Backend Architecture (Summary)

```mermaid
flowchart TB
  subgraph clients [Mobile]
    AndroidKB[Android Keyboard]
    iOSKB[iOS Keyboard]
  end

  subgraph api [NestJS Backend]
    GW[Auth Guard]
    Transform[Transform Module]
    Prompt[Prompt Template Service]
    GeminiSvc[Gemini Client]
    Usage[Rate Limit]
    Settings[Settings Module]
  end

  subgraph external [External]
    Gemini[Google Gemini API]
    DB[(PostgreSQL)]
    Redis[(Redis)]
  end

  AndroidKB --> GW
  iOSKB --> GW
  GW --> Transform
  Transform --> Prompt
  Transform --> Usage
  Transform --> GeminiSvc
  GeminiSvc --> Gemini
  Settings --> DB
  Usage --> Redis
```

| Module | Responsibility |
|--------|----------------|
| **Auth** | Device token / JWT; MVP uses device ID + quota |
| **Transform** | text + mode + action → Gemini → result |
| **Prompt Template** | Mode × action system prompts |
| **Gemini Client** | Model calls, timeout, retry |
| **Usage** | Daily request limits |
| **Settings** | Theme, default mode, locale |

## AI Integration (Gemini)

- All requests go through the backend; **no API keys on mobile clients**
- Each request: `systemPrompt(mode, action, locale)` + user text
- Validate empty or overly long responses before returning to the keyboard
- User-friendly errors on timeout or quota exceeded

### Mode × Action matrix (example tone)

| Mode | Correct | Rewrite | Shorten | Expand |
|------|---------|---------|---------|--------|
| **Work** | Formal, clear, fix spelling | Professional alternative phrasing | Concise business tone | Detailed, respectful |
| **Friends** | Casual fixes | Natural, everyday language | Short message style | Slightly more conversational |
| **Family** | Warm and clear | Soft phrasing | Brief update | More explanatory |
| **Flirt** | Engaging, not overdone | Warm alternate wording | Short flirt tone | Slightly longer, warm |

## UX / Main Flows

### Flow 1: Quick correction

1. User types in WhatsApp / Mail / Slack
2. Selects **Work** mode on the keyboard
3. Taps **Correct**
4. Backend returns edited text; keyboard inserts it into the field

### Flow 2: Tone change

1. User selects existing text
2. Chooses **Friends** → **Rewrite**
3. Result keeps meaning with a friendlier tone

### Flow 3: Theme

1. User changes theme from settings or keyboard
2. Light / dark palette applies immediately

## Keyboard Modes & Actions

### Modes

- `work` — Work
- `friends` — Friends
- `family` — Family
- `flirt` — Flirt

### Actions

- `correct` — Correct
- `rewrite` — Rewrite
- `shorten` — Shorten
- `expand` — Expand

## Security & Privacy

- HTTPS required
- Gemini API key only in server environment variables
- Text logs: short TTL or masking; not used for model training
- iOS **Full Access** requirement explained clearly to users
- Play Store / App Store privacy policy and keyboard permission copy

## Timeline

**Duration:** 14 days — **7 days Android + backend**, then **7 days iOS**, then shared ship/QA.

| Day | Topic |
|-----|--------|
| 01 | Repo, docs, NestJS scaffold, health |
| 02 | Gemini + prompt templates (TR/EN; theme/tone hooks) |
| 03 | `POST /v1/transform`, auth stub, rate limit |
| 04 | Android IME skeleton, QWERTY, locale |
| 05 | Android AI bar + API |
| 06 | Android modes + light/dark + long-press alternates |
| 07 | Android replace + preview accept/cancel + smoke QA |
| 08 | iOS Keyboard Extension skeleton |
| 09 | iOS layout (parity with Android) |
| 10 | iOS AI bar + API |
| 11 | iOS modes + themes + long-press alternates |
| 12 | iOS replace + preview accept/cancel |
| 13 | Settings persistence + cross-platform QA |
| 14 | Documentation, demo, delivery |

Details: [roadmap.md](./roadmap.md)

## Core Directives

1. **Native keyboard:** Keyboard UI is Kotlin (Android) and Swift (iOS); Flutter does not support keyboard extensions.
2. **Backend required:** All AI calls go through NestJS.
3. **Centralized prompts:** Mode and action templates are versioned on the backend.
4. **Privacy first:** Minimum data collection, transparent permissions.
5. **MVP focus:** TR/EN locales and 4 modes first; expand in later phases.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| iOS keyboard constraints (Full Access) | Early testing; clear onboarding |
| API latency | Loading state, timeout, retry |
| Gemini cost | Rate limits, flash model, max text length |
| Poor AI output | Max length checks, empty response handling |
| Store rejection (privacy) | Data policy and minimal logging |

## Future Enhancements

- Custom user prompts
- Edit history
- Subscription and premium modes
- Certificate pinning
- Custom blended modes (e.g. work + flirt)

## Related Documents

- [README.md](../README.md) — Plan index: purpose, stack, MVP features, daily analysis links
- [architecture.md](./architecture.md) — System and backend architecture
- [api_endpoints.md](./api_endpoints.md) — REST API
- [ui_design.md](./ui_design.md) — UI mockup gallery
- [roadmap.md](./roadmap.md) — 14-day development plan
- [day_01/analysis.md](../day_01/analysis.md) … [day_14/analysis.md](../day_14/analysis.md) — per-day implementation notes
