# Pulse Phone Key (iOS)

iPhone’da Safari **Web Bluetooth desteklemez**. Bu küçük SwiftUI uygulama CoreBluetooth ile
Tesla’ya resmi `add-key-request` (VCSEC `SIGNATURE_TYPE_PRESENT_KEY`) gönderir.

## Arabada hemen (Xcode yokken)

1. [Tesla](https://apps.apple.com/app/tesla/id582007658) uygulamasını aç  
2. **Security → Set Up Phone Key** (veya ana ekranda Set Up Phone Key)  
3. Key Card’ı **orta konsola / telefon şarj yuvasına** koy  
4. Araç ekranında **Pair / Confirm**

Pulse web’deki `/phone-key` sayfası iPhone’da bu adımlara tek dokunuşla yönlendirir.

## Bu uygulamayı telefona yükle (Mac + Xcode)

1. Mac’te Xcode 16+ kur  
2. Bu klasörü aç: **File → New → Project → App** (SwiftUI, iOS 17+)  
   veya aşağıdaki kaynakları yeni bir App target’ına ekle  
3. `Info.plist` içine ekle:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Tesla aracıyla Phone Key eşleşmesi için Bluetooth gerekir.</string>
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>
</array>
```

4. Signing: kişisel Apple ID (free) ile Team seç  
5. iPhone’u USB ile bağla → Run  
6. Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştiriciyi güven  

### Kaynak dosyalar

| Dosya | Rol |
|--------|-----|
| `Sources/PulsePhoneKeyApp.swift` | App giriş |
| `Sources/ContentView.swift` | VIN + eşleştir UI |
| `Sources/KeyStore.swift` | P-256 Keychain |
| `Sources/VCSECPayload.swift` | add-key protobuf |
| `Sources/BLEPairer.swift` | CoreBluetooth yazma |

### Kullanım

1. VIN gir (kayıtlıysa otomatik)  
2. **Eşleştir** → Bluetooth izni ver  
3. Araç bulununca istek gider  
4. Key Card → konsol → Pair  

Anahtar iPhone Keychain’de kalır (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
