# SOC’u iPad Swift Playgrounds’ta çalıştırma

Evet — ama mevcut `SOC.xcodeproj` doğrudan Playgrounds’ta açılmaz. Bunun için hazırladığımız **`SOC.swiftpm`** App Playground paketini kullan.

## Gereksinimler

- iPadOS 17+ (tercihen 18+)
- App Store’dan **Swift Playgrounds** (güncel sürüm)
- Apple ID (ücretsiz yeterli)
- iPad’de Bluetooth + konum izni

## 1) Projeyi iPad’e al

**Kolay yol (GitHub → Files):**

1. Safari’de aç:  
   https://github.com/eymen533/EYMENSOC-AL/tree/cursor/tesla-ble-companion-4163
2. **Code → Download ZIP**
3. ZIP’i Files’ta aç / çıkar
4. Klasörde `SOC.swiftpm` dosya/klasörünü bul  
   (Finder/Files’ta tek dosya gibi görünebilir)

**Alternatif:** Mac’ten AirDrop ile `SOC.swiftpm` klasörünü iPad’e gönder.

## 2) Swift Playgrounds’ta aç

1. **Swift Playgrounds** uygulamasını aç
2. **Lokasyonlar / Locations** → Files içinden `SOC.swiftpm` seç  
   veya dosyaya basılı tut → **Share / Paylaş** → **Swift Playgrounds**
3. İlk açılışta Swift Package (`TeslaBLEKeyKit`) indirilir — Wi‑Fi açık olsun
4. Sağ üstten **Run ▶️**

## 3) İzinler

İlk çalıştırmada:

- **Bluetooth** → İzin Ver
- **Konum** → Uygulamayı Kullanırken

Playgrounds içinde gerekirse: sol menü **App Settings → Capabilities** altında Bluetooth / Location olduğundan emin ol (`Package.swift` içinde tanımlı).

## 4) iPad’de kullan

1. iPad’i **yatay** çevir (araç mount için ideal)
2. Arabada **Park**’ta eşleştirme yap (VIN + key card)
3. Dashboard açılır; BLE + Apple Maps çalışır

Uygulama Playgrounds’tan “Install” / ana ekrana ekleme ile iPad’de ayrı app gibi de kalabilir (Playgrounds sürümüne göre **App Settings** veya Run sonrası kalıcı kurulum).

## Sınırlar (Xcode’a göre)

| | Swift Playgrounds (iPad) | Xcode (Mac) |
|---|---|---|
| Bu iPad’de çalıştırma | Evet | Evet (simülatör/cihaz) |
| iPhone’a doğrudan yükleme | Genelde hayır* | Evet |
| App Store / TestFlight | Playgrounds’tan mümkün (Apple Developer) | Evet |
| Debug / imzalama | Daha sınırlı | Tam |

\*iPhone’a almak için genelde Mac+Xcode veya TestFlight gerekir.

## Sorun çıkarsa

- **Package çözülmüyor:** Wi‑Fi + tekrar aç; Package dependency URL’si `TeslaBLEKeyKit`
- **Bluetooth yok:** Capabilities’te Bluetooth Always
- **Harita boş:** Konum izni + dışarıda / araçta dene
- **Signing hatası:** Playgrounds’ta Apple ID ile giriş yap
