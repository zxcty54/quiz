# Android launch screen (the "MT logo" screen you see for a second on launch)

This is NOT Dart code. It lives in the Android resource folder:

    android/app/src/main/res/

Files to put there (all new in this project - it has no res/ folder yet):

| File | What it does |
| --- | --- |
| drawable/launch_background.xml | dark brand surface + centred logo |
| drawable-v21/launch_background.xml | same file, API 21+ (identical on purpose) |
| values/colors.xml | `launch_background` = #FF070B14 (brand midnight) |
| values/styles.xml | LaunchTheme / NormalTheme, dark |
| values-night/styles.xml | identical to values/styles.xml (screen is dark in both) |
| drawable-xxhdpi/launch_logo.png | the MT logo, drawn at ~170dp so it is fully visible |

Do NOT also put launch_logo.png in drawable/ - there it would render at ~512dp
and get cropped at the edges.

Optional: want the light look instead (white screen, like the earlier build)?
Set `launch_background` in values/colors.xml to #FFFFFF and put the logo in
`drawable/`.

After copying the files, run `flutter clean` and rebuild - resource changes do
not show up on hot reload/hot restart. The PNG is at
paste_into_main_app/android_res/launch_logo.png (also inside
drawable-xxhdpi/).
