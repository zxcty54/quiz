# Android launch screen (the "MT logo" screen you see on launch)

This is NOT Dart code. It lives in the Android resource folder:

    android/app/src/main/res/

Files to put there (all new in this project - it has no res/ folder yet):

| File | What it does |
| --- | --- |
| values/colors.xml | `launch_background` = #FF070B14 (brand midnight) |
| values/styles.xml | LaunchTheme / NormalTheme, dark |
| values-night/styles.xml | identical to values/styles.xml (screen is dark in both) |
| drawable/launch_background.xml | brand surface + centred MT logo |
| drawable-v21/launch_background.xml | same file, API 21+ (identical on purpose) |
| drawable-xhdpi/launch_logo.png | the MT logo, drawn at ~320dp (big, like the screenshot, but not cropped) |

Do NOT also put launch_logo.png into drawable/ - there it renders at ~512dp and
the left/right edges get cut off.

Note: the logo in `drawable-xhdpi` is the *native* launch screen, which only
shows while the process starts (often a few hundred ms). The guaranteed ~1
second of the MT screen comes from lib/screens/splash_screen.dart, which paints
the same background + the same logo (assets/data/icon/launch_logo.png) in
Flutter. Keep the two in sync if you change the colour or the logo.

Want the light look instead (white screen)? Set `launch_background` in
values/colors.xml to #FFFFFF, use `Theme.Light.NoTitleBar` in both styles.xml
files, and put the logo in `drawable/`.

After copying the files, run `flutter clean` and rebuild - resource changes do
not show up on hot reload/hot restart.
