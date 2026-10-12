# MockTester v2 — kya naya hai (UI redesign, Phase 1)

`flutter_app/` (v1) **bilkul chhua nahi gaya**. Sab kuch `flutter_app_v2/` me hai,
build alag workflow (`build_apk_v2.yml`) se hota hai, aur v1 se compare karne ke
liye dono APK ek hi phone pe install ho sakte hain (demo wala naam
**"MockTester v2 Demo"** dikhata hai).

---

## 1. Design system (naya)

| File | Kya deta hai |
|---|---|
| `core/theme/app_tokens.dart` | Radius (`AppRadii`), spacing (`AppSpacing`), motion (`AppMotion`), shadow (`AppElevation`) — poore app ke liye ek hi scale |
| `core/theme/app_gradients.dart` | Ek gradient library: `brand`, `brandDeep`, `study`, `success`, `warm`, `midnight`, `aurora`, `glass` |
| `core/theme/app_theme.dart` | Light + dark theme — **har** Material component ek jagah style hota hai (app bar, navigation bar, card, input, chip, dialog, bottom sheet, snackbar, switch, tab, scrollbar) |
| `core/widgets/brand_mark.dart` | `BrandMark` / `BrandWordmark` — logo ke 3 purane alag-alag versions ki jagah ek |
| `core/widgets/aurora_background.dart` | Animated aurora background (splash + onboarding) |

Purana dard: v1 me har screen apna colour khud set karti thi — isliye app bar
kahin slate tha kahin white, aur dialog seed-colour ki wajah se purple aa jata
tha. Ab screens colours dete hi nahi.

---

## 2. Screen-by-screen (ab tak)

### Splash
* Pehle: ek icon + text + spinner.
* Ab: aurora field, logo scale-in animation, gradient tagline, real progress bar,
  aur neeche exam list.

### Onboarding (pehla flow — jise aapne "same" kaha tha)
* Same 2 steps, same texts, same prefs/Supabase registration logic (naam,
  district, mobile — wahi keys).
* Naya: brand mark + gradient wordmark, 3 feature tiles (Live CBT mocks,
  Daily current affairs, AI doubt solver), exam pills, "SETUP 1/2" chip,
  progress dots + 01/02 counter.
* Form ab ek translucent sheet me hai, shared field treatment, "02 YOUR PROFILE"
  label, aur gradient CTA with glow.

### App shell (jab app khulti hai)
* App bar: brand mark + "MockTester" + subtitle "BPSC • BSSC • Bihar Police";
  purane do actions (⚡ cache purge, school = Learn Hub) jaise the waise hi.
* Navigation bar: same 5 tabs, naya indicator pill + icon/label styling.
* Drawer: gradient header (naam, district chip, "Aspirant" badge) — Material ke
  boring avatar header ki jagah.
* Loading skeleton ab theme ke hisaab se chamakta hai (pehle dark mode me bhi
  white blocks dikhte the).

### Home (tab 1)
* Sabse upar **naya greeting card**: "Good morning, <naam>", aaj ki date,
  streak pill (🔥 n days), aur live numbers — Questions, Accuracy, Mocks
  (`UserStatsService` se; kuch naya record nahi hota).
* Do action buttons: **Learn Hub** aur **Daily Challenge** (pull-to-refresh se
  numbers refresh hote hain).
* Uske neeche v1 ka poora content jaisa tha waisa hi (ticker, trust banner,
  coaching hub, jobs, bulletin, PDF vault …).

### Demo launcher (tester build)
* Naya gradient hero, boot status chips (Firebase/Supabase), colour-coded action
  tiles (Widget Gallery / Screen Directory / Smoke Test / Launch real app),
  baaki controls wahi.

---

## 3. Jo abhi bhi v1 jaisa hai (agle phase me)

Theme ki wajah se inke buttons/cards/inputs/dialogs naye lagenge, par inke andar
ka layout abhi purana hai:

* Home ke section cards (jobs, bulletin, current affairs, hall of fame, PDF vault…)
* Revision tab, Sectional CBT (≈2950 lines), Community, Profile
* Learn Hub + chat, Challenge screens, AI chat, PDF vault, tools (photo resizer,
  doc merger), result sheets

Aage ka kaam: ek-ek tab utha kar usi token system pe redesign karna — behaviour,
routes aur prefs keys bilkul same rakhte hue.

---

## 4. Build / test

```bash
# demo APK (tester tool)
flutter build apk --release -t lib/tools/demo/demo_tool.dart \
  --dart-define=DEMO_TOOL=true

# production APK
flutter build apk --release
```

CI (`.github/workflows/build_apk_v2.yml`) audit → analyze (gate) → tests →
prod APK → demo APK → dono ZIP Telegram pe. Green run ka example:
`MockTester_v2_Build_18` (sha `cc4b5bb`).
