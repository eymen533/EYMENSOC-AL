# iPhone’da gerçek uygulama (Safari değil)

Safari / web **Bluetooth kullanamaz**. Bu proje iPhone’da **yerel uygulama** olarak çalışır: CoreBluetooth ile Pair, sonra cluster HUD.

Bu Linux ortamından App Store’a imzalı `.ipa` yayınlanamaz. iPhone’a kurmanın yolu **Swift Playgrounds** (ücretsiz Apple ID) veya Mac + Xcode’dur.

## Yol A — Swift Playgrounds (Mac şart değil)

1. App Store → **Swift Playgrounds** kur (iPhone destekler).
2. Zip indir: `/downloads/PulsePhoneKey-playground-build14.zip` (veya `…-playground.zip`).
3. Dosyalar’da zip’i aç → `PulsePhoneKey.swiftpm` klasörüne dokun → **Playgrounds’ta Aç**.
4. App Settings → **Signing** → kendi Apple ID’n.
5. Capabilities → **Bluetooth Always** açık olsun (Package.swift’te gömülü).
6. **Run ▶** — uygulama iPhone’a native kurulur (Ana Ekran’a eklenir). Safari değildir.
7. Ayarlar → Dash server = canlı tunnel URL · PIN = `428462`.
8. **Pair Vehicle** → VIN → listeden `🔑 Tesla …` → Key Card’ı **konsola** → Confirm → **Open Cluster HUD**.

Ücretsiz Personal Team ile kurulum ~7 günde yenilenir; tekrar Run yeterli.

Ana ekranda sürüm: `build-14-iphone` görünmeli. Eski sürümse zip’i yeniden indir.

## Yol B — Mac + Xcode (kalıcı geliştirici kurulumu)

1. Mac’te Xcode aç → `ios/PulsePhoneKey.swiftpm` veya `ios/PulsePhoneKey/`.
2. Signing → Personal Team / Apple Developer.
3. iPhone’u kabloyla bağla → Trust → Run.
4. iPhone: Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştiriciyi güven.

## Bağlantı hatası

- **BLE Pair** telefonda lokaldir; internet gerekmez.
- **HUD** Dash sunucusuna HTTP ister. Quick tunnel düşerse Settings’te URL güncelle veya **Varsayilan sunucuya don**.
- Settings → **Sunucu baglantisini test et** ile kontrol et.

## App Store / .ipa

İmzalı App Store paketi bu ortamda üretilmez. Kendi Mac + Apple Developer hesabınla Archive → Distribute gerekir.
