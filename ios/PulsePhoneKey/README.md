# Pulse Phone Key — iPhone **and iPad** (real BLE)

Yes — on an **iPad** this Swift app can do **real** Tesla Phone Key pairing over CoreBluetooth  
(same VCSEC `add-key-request` as `tesla-control` / the Android APK).

Safari / Chrome on iPad **cannot** do this (no Web Bluetooth). You need this native app.

## What you need

| Item | Required? |
|------|-----------|
| iPad (Bluetooth on) near the car | Yes |
| Mac with **Xcode 16+** | Yes (to build & install) |
| Free Apple ID (Signing → Personal Team) | Yes |
| Cable or wireless debugging | Yes |
| Key Card for console | Yes |

This Linux cloud agent **cannot** compile or install the iPad app for you.

## Install on iPad (Mac)

```bash
# optional: generate .xcodeproj
brew install xcodegen
cd ios/PulsePhoneKey
xcodegen   # creates PulsePhoneKey.xcodeproj
open PulsePhoneKey.xcodeproj
```

Or manually:

1. Xcode → **File → New → Project → App**  
   - Interface: **SwiftUI**  
   - Language: **Swift**  
   - Destinations: **iPhone + iPad**  
2. Delete the template `ContentView` / `App` files  
3. Drag in everything under `Sources/` + use `Info.plist`  
4. Signing & Capabilities → your **Team** (personal Apple ID)  
5. Select your **iPad** as run destination → **Run** ▶  
6. On iPad: **Settings → General → VPN & Device Management** → trust your developer  

App expires after ~7 days with a free Apple ID (re-Run from Xcode to refresh).

## Use in the car

1. Open **Pulse Key** on the iPad  
2. VIN is prefilled (or enter yours)  
3. Tap **Bluetooth ile eşleştir** → allow Bluetooth  
4. Wait until status says put the card on the console  
5. Put Key Card on the **console reader** (not on the iPad)  
6. Confirm **Pair** on the vehicle screen  

## Without Xcode (right now)

Use the official **Tesla** app on the iPad:  
**Security → Set Up Phone Key** → card on console → Pair.

## Files

| File | Role |
|------|------|
| `Sources/PulsePhoneKeyApp.swift` | App entry |
| `Sources/ContentView.swift` | UI (iPad-friendly) |
| `Sources/KeyStore.swift` | P-256 in Keychain |
| `Sources/VCSECPayload.swift` | add-key protobuf |
| `Sources/BLEPairer.swift` | CoreBluetooth |
| `Info.plist` | Bluetooth usage + iPad orientations |
| `project.yml` | XcodeGen recipe |
