# Tesla Pulse — full Android APK

One app for the whole flow:

1. **PIN** → unlock Pulse server session  
2. **BLE + Key Card** → VCSEC `add-key-request`, card on **console**, Pair on car screen  
3. **Cluster HUD** → landscape WebView of the Dash UI  

## Download

- [`releases/TeslaPulse.apk`](../releases/TeslaPulse.apk)  
- Live (after PIN): `/downloads/TeslaPulse.apk`  

Also aliased as `/downloads/PulsePhoneKey.apk`.

## Install & use

1. Install APK (unknown sources)  
2. Open **Tesla Pulse**  
3. PIN (e.g. `428462`)  
4. VIN → **Key Card ile eşleştir**  
5. Key Card on console → Confirm Pair  
6. HUD opens automatically (or tap **HUD’u aç**)  

If the Cloudflare tunnel URL changes: login screen → **Sunucu ayarı**.

## Permissions

Bluetooth / Nearby devices + Location (required for BLE scan on Android).
