# Tesla Pulse — Android APK (full app)

Full phone app:

1. **PIN** login to your Pulse server  
2. **BLE Phone Key** pair (`add-key-request` → Key Card on console → Pair)  
3. **Cluster HUD** in a landscape WebView  

## Download

- [`releases/TeslaPulse.apk`](../../releases/TeslaPulse.apk)  
- Live: `/downloads/TeslaPulse.apk` (after PIN)

## Flow

1. Install APK (allow unknown sources)  
2. Open **Tesla Pulse** → enter PIN  
3. Enter VIN → **Key Card ile eşleştir**  
4. Put Key Card on the **car console** → Confirm Pair  
5. HUD opens (or tap **HUD’u aç**)  

**Sunucu ayarı** on the login screen if the Cloudflare URL changes.

## Build

```bash
export ANDROID_HOME=/path/to/Sdk
cd android/PulsePhoneKey
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleRelease
# zipalign + apksigner → ../../releases/TeslaPulse.apk
```
