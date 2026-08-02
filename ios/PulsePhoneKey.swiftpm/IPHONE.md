# iPhone’da gerçek uygulama (Safari değil)

Safari / web **Bluetooth kullanamaz**. Bu proje iPhone’da **yerel uygulama** olarak çalışır: CoreBluetooth ile Pair, sonra cluster HUD.

Bu Linux ortamından App Store’a imzalı `.ipa` yayınlanamaz. iPhone’a kurmanın yolu **Swift Playgrounds** (ücretsiz Apple ID) veya Mac + Xcode’dur.

## Yol A — Swift Playgrounds (Mac şart değil)

1. App Store → **Swift Playgrounds** kur (iPhone).
2. Zip indir: `/downloads/PulsePhoneKey-playground-build14.zip`
3. **Dosyalar** uygulamasında zip’e dokun → **Aç** (sıkıştırmayı kaldır).
4. Açılan klasörde **`PulsePhoneKey.swiftpm`** klasörüne **basılı tut** → **Paylaş** → **Swift Playgrounds’ta Aç**  
   (Sadece klasöre tek dokunuş yetmeyebilir — Paylaş yolu daha güvenilir.)
5. Playgrounds → App Settings → **Signing** → Apple ID.
6. Capabilities → **Bluetooth Always**.
7. **Run ▶** — Ana Ekran’a yerel uygulama kurulur.
8. Ana ekranda sürüm: **`build-14-iphone`** olmalı.
9. Settings → Dash server + PIN `428462`.
10. **Pair Vehicle** → VIN → `🔑 Tesla …` → Key Card **konsola** → HUD.

### Zip açılmıyorsa

- Eski zip’i sil, **build14** indir (Safari önbelleği eski dosya verebilir).
- Alternatif: `/downloads/PulsePhoneKey-swift-files.zip` → Playgrounds’ta **Yeni App** → dosyaları yapıştır ([`MANUAL.md`](MANUAL.md)).
- “Unable to open” → Signing / Apple ID gir, Bluetooth capability açık olsun.
- Ücretsiz Personal Team ~7 günde yenilenir; tekrar Run.

## Yol B — Mac + Xcode

1. `ios/PulsePhoneKey.swiftpm` aç → Signing → iPhone’a Run.
2. Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştiriciyi güven.

## Bağlantı hatası

- **BLE Pair** lokaldir.
- **HUD** Dash URL ister. Settings → test / varsayılana dön.

## App Store / .ipa

Bu ortamda imzalı IPA üretilmez.
