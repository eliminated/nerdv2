# NerdyApp Companion

> A study companion that helps learners hold focus, stay consistent, and see the work they actually did.

**Build iteration: V2** · **Release version: v0.1.0 (pre-alpha)** · **Status: in development**

<!-- TODO: add badges once the repo is public — build status, license, release -->

---

## Table of contents

- [Overview](#overview)
- [About "V2"](#about-v2)
- [Challenges this addresses](#challenges-this-addresses)
- [Features](#features)
- [Who it serves](#who-it-serves)
- [Tech stack](#tech-stack)
- [Focus enforcement — platform reality](#focus-enforcement--platform-reality)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Roadmap](#roadmap)
- [Development workflow](#development-workflow)
- [Privacy](#privacy)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Overview

NerdyApp is a study companion built for students and self-directed learners. It helps you hold your attention on one thing at a time, keep a study habit alive past the first week, and see real progress in the subjects you care about.

It isn't tied to a school timetable. Whether you're revising for a university exam, working through a Udemy course, or teaching yourself something with no syllabus at all, NerdyApp treats it the same way: a goal, a plan, and a record of the work you actually did.

## About "V2"

This project tracks two separate numbers. They are not the same thing.

| | What it means | Current |
|---|---|---|
| **Build iteration** | Which attempt at building this app the codebase represents. Increments only when the project is restarted from scratch. | **V2** |
| **Release version** | Standard [SemVer](https://semver.org/) version of the shipped software. | **v0.1.0** |

**V2** means this is the second attempt at making NerdyApp functional and usable — not a sequel to a released product. Nothing has shipped publicly yet. If this iteration is abandoned and restarted, the next one becomes V3, while the release version resets accordingly.

### Iteration history

| Iteration | Period | Outcome | Lessons carried forward |
|---|---|---|---|
| V1 | <!-- TODO --> | <!-- TODO: why it was restarted --> | <!-- TODO --> |
| V2 | 2026 – present | In progress | — |

<!-- Worth filling in properly. A short, honest post-mortem of V1 is one of the most
     credible things a README can contain, and it stops you repeating the same mistake. -->

## Challenges this addresses

- **Focus breaks within minutes**, and getting back into a locked-in state is hard.
- **Consistency collapses after a few days**, and there's no visible cost to stopping.
- **Progress is invisible**, so the effort feels wasted.
- **Most capable study tools are institution-bound** — tied to a school account, a course platform, or a usage quota.

## Features

Legend: ✅ Shipped · 🔨 In progress · 📋 Planned · 💡 Idea

| Feature | Description | Status |
|---|---|---|
| **Session timer** | The core loop: pick a subject, start a session, log the work. | 📋 Planned |
| **Focused mode** | Light-touch session mode — suppresses notifications and reduces on-screen distraction. | 📋 Planned |
| **Ultra-Focus mode** | Hard lockdown. Blocks app switching and exit attempts, suppresses all notifications, and keeps you inside the app with built-in companion tools. See [platform reality](#focus-enforcement--platform-reality). | 📋 Planned |
| **Post-session survey** | Short check-in after each session rating focus quality and difficulty. Feeds streak quality and topic evaluation — this is the app's core signal, not a side feature. | 📋 Planned |
| **Interruption log** | Records what pulled you away and how often, so analytics point at a cause rather than a number. | 📋 Planned |
| **Streak & consistency tracking** | Consecutive active days, weighted by session quality rather than raw time. | 📋 Planned |
| **Goal setting** | Define a target, break it into a plan, divide the plan into sessions. | 📋 Planned |
| **Topics & subtopics planner** | Organize a subject into a topic tree, evaluated against post-session feedback. | 📋 Planned |
| **Progress analytics** | Time studied per subject and topic, trends over weeks. | 📋 Planned |
| **In-app editor, notepad, music** | Companion tools so Ultra-Focus mode doesn't require leaving the app. Music via third-party service integration. | 📋 Planned |
| **Offline-first** | Full functionality with no connection; syncs when available. | 📋 Planned |
| **Data export** | Export study logs as CSV/JSON. Your data stays yours. | 📋 Planned |
| **Spaced repetition** | Schedule topic reviews from the existing topic tree and session feedback. | 💡 Idea |
| **External course tracking** | Track Udemy / Coursera / self-study progress alongside formal subjects. | 💡 Idea |
| **Accountability / social** | Shared streaks or study groups. | 💡 Idea |

## Who it serves

- **Secondary and university students** managing several subjects at once.
- **Self-taught learners** working through online courses with no external accountability.
- **Anyone** trying to turn studying into a habit rather than a panic response before a deadline.

## Tech stack

<!-- TODO: confirm. These are recommendations based on the cross-platform +
     OS-level-blocking requirement, not final decisions. -->

| Layer | Technology | Why |
|---|---|---|
| Client | Flutter (Dart) | One codebase for Android and desktop; platform channels give a clean path down to native code for lockdown features. |
| Native modules | Kotlin (Android), C++/Win32 (Windows) | Required for Ultra-Focus enforcement. |
| Backend | FastAPI (Python) | Fast to build, good async story, straightforward REST. |
| Database | PostgreSQL | Relational fits the subject → topic → session → survey model well. |
| Local storage | SQLite (Drift) | Offline-first source of truth on device. |
| Platforms | Android, Windows | Desktop-first for study sessions, mobile for tracking and review. |

> **Decide this before writing feature code.** The Ultra-Focus requirement constrains the client
> framework more than any other feature, so choosing the stack around it avoids a rewrite later.

## Focus enforcement — platform reality

Ultra-Focus mode is the app's differentiator, and it's a platform-permissions problem more than a coding problem. Capabilities differ sharply per OS:

| Capability | Android | Windows |
|---|---|---|
| Suppress notifications | Do Not Disturb API (needs user grant) | Focus Assist API |
| Block app switching | Screen pinning / kiosk mode, or Accessibility Service | Low-level keyboard hooks (fragile) |
| Prevent app exit | Screen pinning | No reliable supported method |
| Detect escape attempts | Lifecycle callbacks | Window focus events |

**Play Store caveat:** using an Accessibility Service for non-accessibility purposes is grounds for rejection unless clearly justified. Screen pinning is the safer route.

**Recommended approach — soft enforcement first:**

1. Fullscreen + immersive mode, notifications suppressed.
2. A friction screen on exit attempts ("You have 12 minutes left — leave anyway?").
3. Log every escape attempt and surface it in the interruption log.

Soft enforcement covers most real use, ships far sooner, and carries no store risk. True lockdown lands later as an optional platform-specific module.

## Getting started

<!-- TODO: fill in once the build is runnable -->

### Prerequisites

```
# Flutter 3.x
# Python 3.11+
# PostgreSQL 16
```

### Installation

```bash
git clone https://github.com/<user>/nerdyapp.git
cd nerdyapp

# Client
cd app && flutter pub get

# Server
cd ../server && pip install -r requirements.txt
```

### Running locally

```bash
# Server
uvicorn app.main:app --reload

# Client
cd app && flutter run
```

## Project structure

```
nerdyapp/
├── app/                          # Flutter client
│   ├── lib/
│   │   ├── core/                 # theme, routing, constants, DI
│   │   ├── data/                 # repositories, local db, api client
│   │   ├── domain/               # entities, use cases
│   │   ├── features/
│   │   │   ├── session/          # timer, session lifecycle
│   │   │   ├── focus/            # focused + ultra-focus modes
│   │   │   ├── planner/          # subjects, topics, goals
│   │   │   ├── analytics/        # dashboard, streaks
│   │   │   └── settings/
│   │   └── main.dart
│   ├── android/                  # Kotlin: screen pinning, DND
│   ├── windows/                  # native focus-enforcement hooks
│   └── test/
├── server/
│   ├── app/
│   │   ├── api/v1/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   ├── migrations/
│   └── tests/
├── docs/
│   ├── architecture.md
│   ├── data-model.md
│   └── focus-enforcement.md      # per-platform capability matrix
├── .github/workflows/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

Feature-first folders inside `lib/` matter more than the layer names — they keep each feature self-contained as the app grows.

## Roadmap

Release versions below are the shipped-software clock, all within build iteration V2.

**v0.1.0 — Foundation**
- [ ] Project scaffold (client + server)
- [ ] Database schema and migrations
- [ ] Authentication
- [ ] CI pipeline (lint + test on push)

**v0.2.0 — Core loop**
- [ ] Subject creation
- [ ] Session timer
- [ ] Session logging and history

**v0.3.0 — Focused mode**
- [ ] Soft distraction reduction
- [ ] Post-session survey
- [ ] Interruption log

**v0.4.0 — Consistency**
- [ ] Streak tracking (quality-weighted)
- [ ] Topics & subtopics planner
- [ ] Goal setting

**v0.5.0 — Insight**
- [ ] Analytics dashboard
- [ ] Weekly summary
- [ ] Data export

**v0.6.0 — Ultra-Focus**
- [ ] Android screen pinning
- [ ] In-app editor, notepad, music
- [ ] Windows enforcement module

**v1.0.0 — Public release**
- [ ] Onboarding flow
- [ ] Polish pass
- [ ] Store listing

**Post-1.0**
- [ ] Spaced repetition
- [ ] External course tracking
- [ ] Accountability / social features

## Development workflow

- **Branching:** GitHub Flow. `main` stays deployable; short-lived branches (`feat/session-timer`, `fix/streak-reset`) merged via squash PR.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`, `refactor:`, `test:`. Enables automatic changelog generation.
- **Issues:** one per feature row above; link the issue number from the roadmap so status lives in one place.
- **CI:** lint and test on every push, from v0.1.0. Cheap now, painful to retrofit.
- **Releases:** tag every release, notes via GitHub Releases, changelog follows [Keep a Changelog](https://keepachangelog.com/).
- **Pre-1.0:** breaking changes in minor versions are expected and acceptable.

## Privacy

NerdyApp observes notification state and app-switching behaviour to make focus modes work. That is sensitive, so the commitment is stated plainly:

<!-- TODO: confirm and keep accurate as the implementation lands -->

- Session logs and survey responses are stored locally by default.
- No study content, notes, or interruption data is sold or shared with third parties.
- Sync is opt-in.
- All user data can be exported or deleted on request.

## Contributing

Contributions are welcome. Please open an issue before starting significant work so the approach can be agreed first.

<!-- TODO: add CONTRIBUTING.md covering code style, branch naming, and PR process -->

## License

<!-- TODO: choose one. MIT is the usual default for a project like this. -->

## Contact

**Maintainer:** <!-- TODO: name -->
**Email:** problemistergrey@gmail.com
**Issues:** [Issues](https://github.com/eliminated/nerdv2/issues)

## Changelog
**App Changelog**: [File Changelog](CHANGELOG.md)

**README changelog**:
<!-- REQUIRED: Update/Add changelog logs at the table below for any changes made to README.md -->

| Version | Changes | Author/Co-author |
| ------- | ------- | ---------------- |
| 1.0 | - Foundation | Claude\nIsaac |
| | |

