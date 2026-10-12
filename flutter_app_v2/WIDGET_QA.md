# Widget QA — what the head-less widget tests found, and what was fixed

This is the answer to "were the widgets' UI/UX actually fine?" — no, they were
not. The widget gallery's smoke test kept finding real layout defects, so the
defects were fixed at the source and the test is now part of CI.

## How widgets are verified

`test/widget_smoke_test.dart` renders **every** widget from the demo gallery
(`demoGalleryEntries`) with fixture data:

* 42 entries × light **and** dark theme = 84 renders;
* 390 × 844 logical pixels at dpr 3.0 (a common phone viewport);
* any framework error that is not environment noise (missing plugin, network,
  Supabase) fails the test, and the run prints one compact line per defect;
* CI publishes the whole defect list as a check run, so a red run shows
  *all* findings at once instead of just the first annotation.

`flutter test` renders text with a placeholder font whose glyphs are much wider
than real fonts, so anything that survives this test has headroom on a real
device and at larger system font scales. That is why these findings matter:
they are the narrow-width / large-font cases.

## Defects found and fixed

| Widget | Defect | Fix |
| --- | --- | --- |
| `ModernChatCard` (and 8 other scrolling widgets) | A `ListView` rendered unbounded inside the gallery's own `ListView` → "Vertical viewport was given unbounded height", i.e. a red error screen | gallery entries that scroll internally get a bounded height (`DemoGalleryEntry.height`) |
| `TrustHeroBannerWidget` | 244 px overflow — first the stats strip, then the two top pills | stats strip → `Expanded` + `FittedBox`, pills → `Wrap` |
| `EligibilityCheckerWidget` | 20 px overflow in the 1/2/3 step-badge row | badges `Flexible`, label ellipsises |
| `CoachingOnboardingCtaWidget` | 38 px overflow in the "INSTITUTE & TEACHERS" pill row and the CTA label | both shrink instead of overflowing |
| `ProPdfVaultCard` | 197 px, then 50 px — the title pushed the FREE badge out, and the bottom CTA label did not fit | header row shares width with `Expanded`, CTA label `Flexible` |
| `ChallengeCardWidget` | 50 px, two rows: top pills and the title | pills → `Wrap`, title ellipsises |
| `DonationWidget` | Two `spaceBetween` fund-meter rows overflowed | labels shrink with ellipsis |
| `RevisionHeroBanner` | 96 px — the SMART REVISION pill plus the exam tags on one line | `Wrap` |
| `RevisionCurrentAffairsCard` | 175 px — "Current Affairs Vault" + 2026 EDITION badge, and the month row | title and month label shrink |
| `AppGlobalFeedbackCard` | 190 px — title plus the DEV TEAM badge | `Wrap` |
| `EventCommunityUpdatesWidget` | 55 px — "Live Ground Updates & Tips" header | title shrinks |
| `LaunchRoadmapCard` | title overflowed its card | `Flexible` + ellipsis |

Two test-side problems were also fixed, so the suite tells the truth:
the onboarding test tapped a CTA that was below the fold (the tap silently
missed, which looked like a broken second page) and the greeting-header test
asserted `30%` while the accuracy tile correctly shows `71%` (30 of 42).

## Current state

CI run for build #26: **Analyze ✓, widget + unit tests ✓, release + demo APKs ✓,
zips uploaded to Telegram ✓**. The widget gallery inside the demo APK is the
visual counterpart: open every widget in both themes and compare.
