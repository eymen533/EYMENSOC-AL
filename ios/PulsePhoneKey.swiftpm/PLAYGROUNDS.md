# iPad · Swift Playgrounds ile gerçek BLE Pair

Mac / Xcode **gerekmez**. App Store’daki **Swift Playgrounds** ile bu `.swiftpm` App projesini açıp çalıştırırsın.

## 1) iPad’e al

**Kolay yol — zip:**

1. iPad Safari’de (PIN sonrası): `/downloads/PulsePhoneKey-playground.zip`
2. **Dosyalar** uygulamasında zip’i aç → `PulsePhoneKey.swiftpm` klasörü çıksın
3. Dosyaya bas → **Swift Playgrounds** ile Aç

**Git yolu:** Working Copy / repo’dan `ios/PulsePhoneKey.swiftpm` klasörünü Playgrounds’a kopyala.

## 2) Playgrounds ayarları

1. Sol üstte proje adına dokun → **App Settings**
2. Apple ID ile **Signing** (Personal Team yeterli)
3. Bluetooth izin metni `Info.plist` içinde; yine de Settings’te Capabilities varsa Bluetooth’u kontrol et
4. Üstteki **Run ▶** — önizleme değil, gerçek uygulama penceresi

İlk çalıştırmada Bluetooth izni iste → **Allow**.

## 3) Arabada

1. Arabayı **uyandır** (kapı aç / ekran) — uykuda S…C görünmez
2. Resmi **Tesla uygulamasını kapat** (app switcher’dan sil)
3. iPad Bluetooth açık, araç yakında
4. **Bluetooth ile eşleştir** — Log’da `İstek gönderildi ✓` bekle
5. Key Card’ı **konsol okuyucuya** koy (iPad’e değil)
6. Araç ekranında **Pair / Confirm**

### “Bluetooth’ta göründü sonra kayboldu”

Bu çoğu zaman **hata değil**: bağlanınca iOS Ayarlar listesinden gizler.  
Asıl başarı Log’daki `Write ACK` / `İstek gönderildi ✓` satırıdır.  
Pair diyaloğu ancak istek gittikten + kart konsola konunca çıkar.

## Önemli

| | |
|--|--|
| Safari’de Web Bluetooth | Yok — işe yaramaz |
| Playgrounds **App** projesi (`.swiftpm`) | Evet — CoreBluetooth gerçek |
| Eski “Playground Book” / tek sayfa playground | BLE Pair için uygun değil |
| Ücretsiz Apple ID | ~7 günde yeniden Run gerekir |

## Elle oluşturmak istersen

1. Swift Playgrounds → **App** oluştur  
2. Bu klasördeki `Sources/*.swift` dosyalarını ekle  
3. `Info.plist` ekle ve `Package.swift` içine  
   `additionalInfoPlistContentFilePath: "Info.plist"` yaz  
4. Run
