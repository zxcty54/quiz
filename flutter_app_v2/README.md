# MockTester v2 (`flutter_app_v2`)

Feature-first rewrite of the MockTester Android app. **The legacy `flutter_app/`
is untouched and still fully functional** — this folder is the candidate for the
next release: same features, new structure, tests, and a demo build for QA.

```
flutter_app_v2/
├── android_overlay/        # our Android layer, copied over `flutter create` output in CI
├── assets/                 # app_config / home_data / learn_data / sectional_data / subject_mapping + icons
├── lib/
│   ├── app.dart            # MaterialApp + theme + first route
│   ├── main.dart           # bootstrap → runApp (demo flag aware)
│   ├── core/               # config, network, theme, constants, utils, shared widgets, services
│   ├── features/           # one folder per feature: data/ domain/ presentation/
│   └── tools/demo/         # tester build: widget gallery, screen directory, API smoke report
├── test/                   # unit + architecture tests (run in CI)
└── tool/audit.py           # static audit: imports, layering, delimiter balance
```

## Quick start

```bash
cd flutter_app_v2
flutter pub get
flutter test                      # unit + architecture tests
python3 tool/audit.py             # import / layering audit
flutter analyze

# run the app
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# build the QA/demo APK (widget gallery + screen directory + API smoke test)
flutter build apk --release -t lib/tools/demo/demo_tool.dart \
  --dart-define=DEMO_TOOL=true
```

CI (`.github/workflows/build_apk_v2.yml`) does all of the above, then zips each
APK on its own (Telegram refuses documents over 50 MB) and sends both zips to
the chat in `TELEGRAM_TO` — the **demo zip first**, since that is the build a
tester installs. The same files stay downloadable from the run's
`MockTester_v2_Build_<n>` artefact.

## Architecture rules (enforced by `test/architecture_test.dart`)

| Rule | Why |
| --- | --- |
| Every import is absolute (`package:mocktester_v2/...`) | `../..` chains were the #1 source of breakage in v1 |
| Remote URLs only in `core/config/app_endpoints.dart` | 34 files hardcoded 5 different mirror URLs before |
| Secrets only in `core/config/app_secrets.dart` (`--dart-define`) | the Telegram bot token was duplicated in 3 files |
| `core/` never imports `features/` | keeps config/network/theme reusable and testable |
| One JSON loader (`core/network/json_fetcher.dart`) | v1 had 6 copies of the same mirror-fallback code |

## Features (all ported from v1)

`ai` · `bihar_events` · `bihar_gk` · `bulletin` · `challenge` · `coaching` ·
`community` · `creator` (studio) · `current_affairs` · `first_in_india` ·
`hall_of_fame` · `home` · `jobs` · `learn` · `onboarding` · `pdf_vault` ·
`profile` · `quiz` · `revision` · `sectional` (CBT engine) · `shell` · `tools`

## Demo build (for testers)

`lib/tools/demo/` is compiled either as its own target or with
`--dart-define=DEMO_TOOL=true`. It starts on a launcher with:

1. **🎨 Widget gallery** — every reusable widget rendered with fixture data
   (`tools/demo/demo_fixtures.dart`), dark/light switch, name filter.
2. **📱 Screen directory** — all 34 routes, each openable with fixtures.
3. **🩺 API & data smoke test** — live pass/fail list: bundled assets, cache
   round-trip, CDN mirrors, question banks, current affairs, challenge
   generator, Know-Your-Bihar card, AI worker, Supabase, Telegram bots, website.
4. **🚀 Launch the real app** — the production shell inside the demo build.

## Where things used to be

Every ported file keeps a `// v1 source: flutter_app/lib/...` header, so the
mapping between old and new locations is always one search away.
