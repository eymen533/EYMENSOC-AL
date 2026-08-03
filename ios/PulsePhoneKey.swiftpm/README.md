# Pulse Key — Xcode native (`xcode-ble-27`)

## Güncel kodu al + aç

**Doğru branch:** `cursor/hud-day-night-doors-02d8`  
**Doğru proje:** `ios/PulsePhoneKey/PulsePhoneKey.xcodeproj`  
(`ios/PulsePhoneKey.swiftpm` Playgrounds — gerçek BLE için Xcodeproj kullan)

```bash
cd ~/EYMENSOC-AL
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

Xcode: **Product → Clean Build Folder** (⇧⌘K), telefondaki eski Pulse’u sil, sonra **Run**.

Ana ekranda yeşil kapsül: **xcode-ble-27** görünmeli.
