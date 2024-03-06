# Garage Opener

Garage opener application in Flutter.

NOTE: This application is based on a proprietary protocol and so not applicable for generic connected garage doors.

# Compile the app

To compile it, run the following command in the terminal:
```
 $ flutter build apk
```

The APK is generated in the following path: `build/app/outputs/flutter-apk/app-release.apk`. The APK can be downloaded and installed on the device.

The app version is defined directly in the gradle file in `android/app/build.gradle` (and not taken from `local.properties`).

## How to use it

A few quick instructions:
 - double tap on the state to refresh
 - long press on the state to access the settings
 - settings are saved when the "Save" button is pressed and not by going back.
