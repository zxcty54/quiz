# Android launch screen (the "MT logo" screen you see for ~1 second on launch)

This is NOT Dart code. It lives in the Android resource folder:

    android/app/src/main/res/

Copy the folders below into `android/app/src/main/res/` of the app:

    drawable/launch_background.xml
    drawable-v21/launch_background.xml
    values/styles.xml
    values-night/styles.xml
    values/colors.xml
    <launch_logo.png>            -> see "Where does the PNG go?" below

Where does the PNG go?
* `drawable/`        -> logo drawn at ~512dp, i.e. big / slightly wider than the
                        screen (this is what the v2 build does today)
* `drawable-xxhdpi/` -> logo drawn at ~170dp, i.e. fully visible with margin
                        (recommended if you do not want the edges cropped)

Optional: for a dark launch screen that flows into the dark splash screen,
change `launch_background` in values/colors.xml from #FFFFFF to #070B14.

After copying, run `flutter clean` and rebuild - resource changes do not show
up on hot reload/hot restart.
