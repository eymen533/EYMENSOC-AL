# Pulse Phone Key (Android APK)

Native Android app that sends Tesla VCSEC **add-key-request** over Bluetooth LE,
then you tap the Key Card on the **console** and confirm **Pair** on the car screen.

## Download

Signed APK (repo root):

- [`releases/PulsePhoneKey.apk`](../../releases/PulsePhoneKey.apk)

Or from the running Pulse server: **`/downloads/PulsePhoneKey.apk`**

## Install on phone

1. Transfer the APK to the phone  
2. Settings → allow install from unknown sources for the file app / browser  
3. Open APK → Install  
4. Open **Pulse Key** → enter VIN → **Bluetooth ile eşleştir**  
5. Key Card → **console** → Pair / Confirm  

Grant **Nearby devices / Bluetooth** and **Location** (needed for BLE scan on Android).

## Build from source

```bash
export ANDROID_HOME=/path/to/Android/Sdk
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleRelease
# sign with apksigner
```

Requires JDK 17+, Android SDK 34.
