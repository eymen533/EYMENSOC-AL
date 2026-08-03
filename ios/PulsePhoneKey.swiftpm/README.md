# Pulse Key — Xcode native (`xcode-ble-28`)

## Tek komut

```bash
cd ~/EYMENSOC-AL
bash pull-pulse.sh
```

veya:

```bash
cd ~/EYMENSOC-AL
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift   # → xcode-ble-28
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

Clean Build → eski Pulse’u sil → Run.  
Ana ekran: yeşil **xcode-ble-28**. Ana ekran ikonu: **Pulse28**.
