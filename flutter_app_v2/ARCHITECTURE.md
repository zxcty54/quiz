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

## Design system

Visual language of v2 lives in `core/theme` and `core/widgets` — screens are not
allowed to invent colours, radii or shadows:

| File | What it owns |
|---|---|
| `core/theme/app_tokens.dart` | `AppRadii`, `AppSpacing`, `AppMotion`, `AppElevation` (radius/shadow/gap scale) |
| `core/theme/app_gradients.dart` | `AppGradients` — brand, brandDeep, study, success, warm, midnight, aurora, glass |
| `core/theme/app_theme.dart` | light + dark `ThemeData` with **every** Material component themed once (app bar, navigation bar, cards, inputs, chips, dialogs, sheets, snack bars, switches, tabs, scrollbars) |
| `core/widgets/brand_mark.dart` | `BrandMark` / `BrandWordmark` (one logo, three former variants) |
| `core/widgets/aurora_background.dart` | animated aurora field used by splash + onboarding |

The palette keeps v1's brand blue (`#2563EB`) so screens that have not been
migrated yet still sit in the same colour family; new surfaces get their depth
from gradients and hairlines instead of hardcoded `0xFF1E293B`/white pairs.

Redesign status:

* **done** — app theme, onboarding, splash, shell frame (app bar, navigation
  bar, drawer, loading skeleton), home header card, demo tool launcher.
* **next** — the five tab screens (Home sections, Revision, Sectional CBT,
  Community, Profile) and then the feature screens (Learn, Challenge, Jobs,
  PDF Vault, AI chat …). Each one keeps its behaviour and loses its inline
  colour literals in favour of the tokens above.

## Conventions

* **One loader**: all network JSON goes through `JsonFetcher`
  (`fetchRobust`, `fetchRacing`, `fetchList`, `fetchRawText`).
* **One mirror registry**: `core/config/app_endpoints.dart` (`mirrorUrls`,
  `githubContentsApi`) plus `core/config/content_sources.dart` (the URL builders
  the few widgets that need a concrete URL keep using). No feature file may
  hardcode a CDN host — enforced by `test/architecture_test.dart` and
  `tool/audit.py`.
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
  `com.testing` while the app id is `com.mocktester.app`. The Google Services
  plugin is therefore applied *conditionally* (`app/build.gradle.kts`): drop in
  a descriptor generated for `com.mocktester.app` and Firebase resources appear
  automatically; until then `AppBootstrap` reports `firebaseReady == false` and
  push stays off instead of breaking the build.

## Build pipeline

`.github/workflows/build_apk_v2.yml` (v1's `build_apk.yml` is untouched):

1. **Analyze & Test** — `tool/audit.py`, format check (informational), then
   `flutter analyze` as a *gate* (errors fail here, one annotation carries every
   error line) and `flutter test`.
2. **Build APKs** — `flutter create .` scaffold → `android_overlay/` copied over
   `android/` → google-services plugin declared → sanity greps → keystore
   decoded → production APK (arm64) → demo APK
   (`--target=lib/tools/demo/demo_tool.dart`) → one zip per APK → artefact →
   Telegram.
3. **Diagnostics** — both APK steps tee to `build_prod.log`/`build_demo.log`;
   on failure the tail is emitted as a single annotation and the whole log is
   republished as a *check run* (artefact downloads are not always reachable).
   `telegram_result.log` carries the Telegram API's JSON answers.

Two things the pipeline learnt the hard way and that must not be undone:

* **Never pin AGP/Kotlin versions** over the ones the installed Flutter release
  wrote into `settings.gradle.kts`: `dev.flutter.flutter-gradle-plugin` then
  fails to apply. Only the google-services id is added, with `apply false`.
* **Plugin `compileSdk` needs aligning.** The app module registers an
  `afterEvaluate` hook for every sibling module and raises `compileSdkVersion`
  to 36, because plugins such as `file_picker` ship an older `compileSdk` and
  their own AAR metadata check fails against `flutter_plugin_android_lifecycle`.
* Telegram's bot API caps documents at 50 MB, so each APK travels in its own
  zip (~45 MB); the demo zip is sent first because that is the build testers
  install.
