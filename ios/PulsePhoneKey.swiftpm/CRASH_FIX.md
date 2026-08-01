# Playgrounds “Phone Key çöktü” — düzeltme

Bu **kod bug’ı değil**; iPadOS şunu yapıyor:

> Bluetooth kullanılırken `NSBluetoothAlwaysUsageDescription` yoksa uygulamayı öldürür.

Playgrounds bazen `Info.plist` satırını Package.swift’ten siler → Run deyince çöker.

## Düzelt (2 dk)

1. Swift Playgrounds’ta projeyi aç  
2. Sol üstte **PulsePhoneKey** (veya App Settings / dişli)  
3. **Capabilities** → **+** → **Bluetooth**  
4. Açıklama yaz: `Tesla Phone Key eşleşmesi için Bluetooth gerekir`  
5. Sol dosya listesinde `Package.swift` aç — şu satır **olmalı**:

```swift
additionalInfoPlistContentFilePath: "Info.plist"
```

Yoksa `.iOSApplication(` bloğunun son parametresi olarak ekle (üst satıra virgül koy).  
6. `Info.plist` dosyası proje kökünde dursun (zip’te var).  
7. **Run ▶** — artık açılışta çökmemeli. Kırmızı uyarı varsa **İzin kontrolünü yenile**.

## Sonra Pair

Arabayı uyandır → Tesla app kapat → **Bluetooth ile eşleştir** → Log’da `İstek gönderildi ✓` → Key Card **konsola**.
