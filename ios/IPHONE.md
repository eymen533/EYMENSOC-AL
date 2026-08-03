# iPhone / iPad — Pulse Key (Xcode)

## Klasör yoksa (No such file or directory)

```bash
cd ~
git clone -b cursor/hud-day-night-doors-02d8 https://github.com/eymen533/EYMENSOC-AL.git
cd EYMENSOC-AL
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift   # → xcode-ble-28
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

## Klasör zaten varsa

```bash
cd ~/EYMENSOC-AL   # veya find ile bulduğun yol
bash pull-pulse.sh
```

`pull-pulse.sh` yoksa:

```bash
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

Xcode: **Clean Build Folder** → eski Pulse’u sil → Run.  
İkon **Pulse28**, yeşil **xcode-ble-28**.

## Yanlış olanlar

- `cursor/ble-pair-fix-02d8` → eski
- `ios/PulsePhoneKey.swiftpm` → Playgrounds (tam BLE değil)
