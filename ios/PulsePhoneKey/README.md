# Pulse Key — Xcode native (gerçek BLE LIVE)

Swift Playgrounds’ta BLE AES telemetri **çöküyordu**. Bu paket **Mac + Xcode** ile telefona/iPad’e kurulur — Dashla gibi araç BLE’sinden hız / vites / lastik / medya / GPS.

Ekranda sürüm: **`xcode-ble-1`**

## İndir

- Zip: [`releases/PulsePhoneKey-xcode.zip`](../../releases/PulsePhoneKey-xcode.zip)
- GitHub raw: https://github.com/eymen533/EYMENSOC-AL/raw/cursor/ble-pair-fix-02d8/releases/PulsePhoneKey-xcode.zip

## Kurulum (Mac zorunlu)

1. Mac’te **Xcode 16+** kur (App Store)
2. Zip’i aç → `PulsePhoneKey.xcodeproj` çift tıkla
3. Sol üstte hedefi **kendi iPhone / iPad** seç
4. **Signing & Capabilities** → Team = kendi Apple ID (ücretsiz Personal Team olur)
5. ▶ **Run**
6. Telefonda: Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştiriciyi güven

Ücretsiz Apple ID ile imza ~7 günde biter; Xcode’dan tekrar Run yeter.

## Arabada kullanım

1. Uygulamada **`xcode-ble-1`** gör
2. **Pair Vehicle** → VIN → Tesla’ya dokun
3. Key Card’ı **konsola** koy → Pair
4. **Cluster HUD** aç
5. Köşede **BLE** / **CANLI TESLA** = gerçek araç verisi

Dash URL + token Settings’te yedek (BLE yoksa).

## Ne içerir

| Dosya | Rol |
|-------|-----|
| `TeslaBLESession.swift` | AES-GCM imzalı oturum |
| `BLETelemetry.swift` | Hız/vites/lastik/medya poll |
| `BLEPairer.swift` | Phone Key pair + telemetri |
| `NativeHUDView.swift` | Cluster HUD |
| `HUDModel.swift` | BLE öncelik, Dash yedek |

## Playgrounds?

Playgrounds zip’i sadece stabil Pair+demo içindir. **Gerçek BLE = bu Xcode proje.**
