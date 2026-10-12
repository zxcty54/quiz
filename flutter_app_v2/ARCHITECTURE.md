# Architecture notes — MockTester v2

## Why a rewrite instead of in-place edits

The v1 tree worked, but the dependency direction had collapsed:

* `services/` imported `screens/` (e.g. `current_affairs_service` →
  `revision_practice_screen`), so no service could be tested alone.
* `widgets/` contained two full screens (`exam_photo_resizer_screen`,
  `exam_doc_merger_screen`) and several widgets imported screens.
* `profile_screen` imported `../main.dart` for the global theme notifier.
* 15 files were unreachable from `main.dart` — two of them imported services
  that were never committed (`offline_llm_service.dart`,
  `knowledge_base_service.dart`), so they could not compile at all.
* `sectional_cbt_screen.dart` had grown to **2,910 lines**; six more files
  passed 1,000 lines.
* The same JSON-fetch-with-5-mirrors block existed in six places, the Telegram
  bot token in three, and 34 files hardcoded CDN URLs.

## Layering

```
lib/
├── core/                       # knows nothing about features
│   ├── bootstrap/              # shared start-up sequence (app + demo + tests)
│   ├── config/                 # endpoints, secrets (--dart-define), remote config service
│   ├── constants/              # palette
│   ├── models/                 # Question (shared by quiz, sectional, revision, profile)
│   ├── network/                # JsonFetcher, LocalCache
│   ├── services/               # notifications, telemetry (Telegram), stats, api
│   ├── theme/                  # AppTheme + ThemeController
│   ├── utils/                  # subtopic engine, bihar location data, content guard, ui helper
│   └── widgets/                # math/latex text, dialogs shared by ≥2 features
└── features/<name>/
    ├── data/                   # services + repositories for that feature
    ├── domain/                 # models owned by that feature
    └── presentation/           # screens, tabs, widgets
```

`core` → nothing, `features` → `core` (+ other features only where the product
requires it: creator studio ↔ coaching ↔ sectional, community ↔ profile).

## Data flow

```
GitHub raw / jsDelivr mirrors ──► JsonFetcher (api.github → mirrors)
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
          RemoteConfigService                   feature data services
      (app_config, sectional_data,        (challenge_service, bpsc_rotation,
       subject_mapping, home_data)         current_affairs, …)
                    │                                   │
                    ▼                                   ▼
                LocalCache (SharedPreferences JSON)  feature screens
                    │
                    ▼
             HomeShellScreen (cache-first paint, then live refresh)
```

`AppBootstrap.run()` performs Firebase → Supabase → theme → onboarding flag and
kicks off the remote-config refresh without blocking the first frame. Both
environments (Firebase, Supabase) are optional: a build without secrets starts
and every cloud call degrades gracefully.

## Conventions

* **One loader**: all network JSON goes through `JsonFetcher`
  (`fetchRobust`, `fetchRacing`, `fetchList`, `fetchRawText`).
* **One cache**: `LocalCache` keeps the *same* SharedPreferences keys as v1, so
  users keep their cached config across the upgrade.
* **One theme source**: `ThemeController.mode` (a `ValueNotifier`); screens
  never write `is_dark_mode` themselves.
* **Secrets**: `AppSecrets` with `--dart-define` + v1 defaults as fallback; an
  empty define never wipes the default.
* **Naming**: `*_screen.dart` for routes, `*_widget.dart` for reusable widgets,
  `*_service.dart` for data access.

## The demo tool

`lib/tools/demo/` compiles as a separate entry point (`demo_tool.dart`) or via
`--dart-define=DEMO_TOOL=true` (`main.dart` reads `kDemoBuild`). It reuses the
production bootstrap, theme and screens — nothing is mocked at the app level;
only the *data* is swapped for fixtures, so QA can walk the whole UI offline and
still run a live smoke test against the real CDNs, Supabase and the AI worker.

## Known follow-ups

* `sectional_cbt_screen.dart` (≈2,950 lines) is next in line to be split into
  engine / palette drawer / question body / result sheet.
* `AppSecrets` defaults exist for compatibility; rotate them and move the
  values into GitHub secrets once v2 replaces v1.
* `google-services.json` in `android_overlay/` still declares the old package
  `com.testing` while the app id is `com.mocktester.app` — regenerate it from
  the Firebase console before the release build (Firebase init is guarded, so a
  mismatch only disables push, it does not crash).
