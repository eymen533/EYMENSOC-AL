# SOC

Kişisel Tesla BLE companion uygulaması (SwiftUI, iPhone, yatay kullanım). Numa benzeri sürüş paneli + VIN ile araç eşleştirme.

SOC, Tesla Fleet API kullanmaz. Araçla yalnızca Bluetooth Low Energy üzerinden konuşur (`TeslaBLEKeyKit`).

## Gereksinimler

- Mac + Xcode 16+
- iOS 17+ iPhone
- Apple Developer hesabı (cihaza imzalayıp yüklemek için)
- Desteklenen Tesla (Phone Key / BLE protokolü): Model 3/Y ve 2021 sonrası S/X

## Kurulum (iPhone’a yükleme)

```bash
git clone <bu-repo>
cd EYMENSOC-AL
./scripts/bootstrap-mac.sh
open SOC.xcodeproj
```

1. Xcode’da target **SOC** → **Signing & Capabilities** → kendi **Team**’ini seç.
2. Bundle ID gerekirse değiştir: `com.eymenisin.soc`
3. iPhone’unu seç → **Run** (▶️).

> Not: XcodeGen yüklüyse `project.yml` üzerinden proje üretir; değilse `scripts/generate_xcodeproj.py` kullanılır.

## iPad (Swift Playgrounds)

Mac yoksa iPad’de **Swift Playgrounds** ile de çalıştırabilirsin.

1. Bu repodaki `SOC.swiftpm` paketini iPad’e indir (ZIP / AirDrop / Files).
2. Swift Playgrounds ile aç → **Run ▶️**
3. Bluetooth + konum izni ver, iPad’i yatay kullan.

Detay: [docs/IPAD_PLAYGROUNDS.md](docs/IPAD_PLAYGROUNDS.md)

## İlk eşleştirme

1. Arabaya bin, **Park**.
2. Uygulamada **Before You Start** → **I am ready to begin**.
3. Tesla uygulamasından VIN’i kopyala, SOC’a yapıştır.
4. Araç bulununca key card’ı konsol okuyucusuna dokundur.
5. Dashboard açılır; BLE oturumu hız, vites, batarya, lastik, odo ve rota verilerini çeker.

## Özellikler

- Yatay Numa-benzeri dashboard (araç / medya / trip panelleri, hız göstergesi, 3D MapKit harita)
- VIN ile BLE tarama ve `addKey` eşleştirme
- Keychain’de cihaza özel P-256 anahtar (iCloud’a gitmez)
- Now Playing medya bilgisi
- Konum + pusula ile harita kamerası
- Reconnect / unpair ayarları

## Mimari

```
SOC/
  App/           # SOCApp, AppModel, RootView
  Features/
    Pairing/     # Before You Start, VIN, Key Card
    Dashboard/   # Sol panel, gauge, harita
    Settings/
  Services/      # TeslaBLEService, VehicleStore, Location, Media
  Resources/     # Info.plist, Assets
```

BLE protokolü: [TeslaBLEKeyKit](https://github.com/misakatao/TeslaBLEKeyKit) (SPM).

## Uyarılar

- Yalnızca kendi aracın / kişisel kullanım.
- Anahtar kaybı = yeniden eşleştirme (Keychain cihaz-only).
- Gerçek araç üzerinde doğrulama senin sorumluluğunda; Infotainment uykudayken bazı sorgular gecikebilir.

## Lisans

Kişisel proje. TeslaBLEKeyKit MIT lisanslıdır.
