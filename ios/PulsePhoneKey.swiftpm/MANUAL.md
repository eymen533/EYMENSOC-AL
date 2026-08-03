# Elle kurulum (zip çökerse)

1. Swift Playgrounds → **App** oluştur (isim: PulseKey)  
2. App Settings → Capabilities → **+** → **Bluetooth** / Bluetooth Always  
   Metin: `Tesla Phone Key eslesmesi icin Bluetooth gerekir.`  
3. Signing → Apple ID  
4. Şu dosyaları projeye ekle / içeriğini yapıştır (template ContentView/App silinebilir):  
   - `PulsePhoneKeyApp.swift` (`@main` olan tek dosya kalsın)  
   - `ContentView.swift`  
   - `BLEPairer.swift`  
   - `VCSECPayload.swift`  
   - `KeyStore.swift`  
5. Run ▶  

Önce Capabilities, **sonra** Run — aksi halde çöker.
