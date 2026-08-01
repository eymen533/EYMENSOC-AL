# Pulse Phone Key — Android APK

## Install

1. On the phone open Pulse → `/phone-key` (PIN unlock)  
2. Tap **Android APK indir**  
   or download [`releases/PulsePhoneKey.apk`](../releases/PulsePhoneKey.apk) from the repo  
3. Allow install from that source → Install **Pulse Key**  
4. Open app → VIN → **Bluetooth ile eşleştir**  
5. Key Card on **console** → Pair / Confirm on the car  

Permissions: Nearby devices / Bluetooth + Location (BLE scan).

## What it does

Same VCSEC `SIGNATURE_TYPE_PRESENT_KEY` add-key envelope as
`tesla-control -ble add-key-request` and the iOS companion.

## Rebuild

```bash
export ANDROID_HOME=$PWD/.android-sdk   # or your SDK
cd android/PulsePhoneKey
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleRelease
# zipalign + apksigner → releases/PulsePhoneKey.apk
```
