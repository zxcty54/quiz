# Android launch screen (the "MT logo" screen you see on launch)

This is NOT Dart code. It lives in the Android resource folder:

    android/app/src/main/res/

Files to put there (all new in this project - it has no res/ folder yet):

| File | What it does |
| --- | --- |
| values/colors.xml | `launch_background` = #FFFFFF (white, like the screenshot) |
| values/styles.xml | LaunchTheme / NormalTheme, light |
| values-night/styles.xml | identical to values/styles.xml (screen is white in both) |
| drawable/launch_background.xml | white surface + centred MT logo |
| drawable-v21/launch_background.xml | same file, API 21+ (identical on purpose) |
| drawable-xhdpi/launch_logo.png | the MT logo, drawn at ~320dp (big, like the screenshot, but not cropped) |

Do NOT also put launch_logo.png into drawable/ - there it renders at ~512dp and
the left/right edges get cut off.

Note: the native launch screen only shows while the process starts (often a few
hundred ms). The guaranteed ~1 second of the MT screen comes from
lib/screens/splash_screen.dart, which paints the same white background + the
same logo (assets/data/icon/launch_logo.png) in Flutter. Keep the two in sync
if you change the colour or the logo.

Want the dark look instead? Set `launch_background` in values/colors.xml to
#FF070B14, use `Theme.Black.NoTitleBar` in both styles.xml files, and set
`_bg` in splash_screen.dart to Color(0xFF070B14).

After copying the files, run `flutter clean` and rebuild - resource changes do
not show up on hot reload/hot restart.
