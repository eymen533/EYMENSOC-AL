# Çökme düzeltmesi (önemli)

Playgrounds’ta Bluetooth izni **şöyle** tanımlanmalı:

```swift
capabilities: [
    .bluetoothAlways(purposeString: "Tesla Phone Key eslesmesi icin Bluetooth gerekir.")
]
```

Sadece `Info.plist` yetmez — iPadOS uygulamayı öldürür (“çöktü”).

## Senin yapman gereken

1. **Eski** PulsePhoneKey projesini Playgrounds’tan sil  
2. Yeni zip’i indir / aç  
3. Sol üst → App Settings → **Signing** (Apple ID)  
4. Capabilities’te **Bluetooth** göründüğünü kontrol et  
5. **Run ▶**

Hâlâ çökerse: Playgrounds’ta **yeni boş App** oluştur → Capabilities → + → Bluetooth Always ekle → sonra bu klasördeki `.swift` dosyalarını kopyala (`MANUAL.md`).
