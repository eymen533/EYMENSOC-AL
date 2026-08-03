# iPhone / iPad — Pulse Key (Xcode)

## Doğru komutlar (bunu kullan)

```bash
cd ~/EYMENSOC-AL
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8

# Doğrulama — şunu yazmalı: xcode-ble-28
grep -n 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift

open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

Xcode: **Product → Clean Build Folder** → telefondaki eski **Pulse**’u sil → Run.

Ana ekranda yeşil: **xcode-ble-28**. Uygulama adı: **Pulse28**.

## Yanlış olanlar

- `cursor/ble-pair-fix-02d8` → eski (ble-12), kullanma
- `ios/PulsePhoneKey.swiftpm` → Playgrounds demo, tam BLE değil
- Sadece `git pull` (yanlış branch’teyken) → eski build kalır
