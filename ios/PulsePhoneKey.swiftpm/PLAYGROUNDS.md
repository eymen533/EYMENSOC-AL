# iPad · Swift Playgrounds ile gerçek BLE Pair

Mac / Xcode **gerekmez**. App Store’daki **Swift Playgrounds** ile bu `.swiftpm` App projesini açıp çalıştırırsın.

## 1) iPad’e al

**Kolay yol — zip:**

1. iPad Safari’de (PIN sonrası): `/downloads/PulsePhoneKey-playground.zip`
2. **Dosyalar** uygulamasında zip’i aç → `PulsePhoneKey.swiftpm` klasörü çıksın
3. Dosyaya bas → **Swift Playgrounds** ile Aç

**Git yolu:** Working Copy / repo’dan `ios/PulsePhoneKey.swiftpm` klasörünü Playgrounds’a kopyala.

## 2) Playgrounds ayarları (çökme olmasın)

1. Sol üstte proje adına dokun → **App Settings**
2. Apple ID ile **Signing** (Personal Team yeterli)
3. **Capabilities → + → Bluetooth** ekle  
   Metin: `Tesla Phone Key eşleşmesi için Bluetooth gerekir`  
   (Yoksa iPadOS uygulamayı **öldürür** — “çöktü” der)
4. `Package.swift` içinde `additionalInfoPlistContentFilePath: "Info.plist"` kalsın
5. Üstteki **Run ▶** — önizleme değil

Ayrıntı: [`CRASH_FIX.md`](CRASH_FIX.md)

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
