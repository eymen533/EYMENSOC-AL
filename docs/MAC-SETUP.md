# Pulse Key — Mac’te ilk kurulum / klasör yoksa

`~/EYMENSOC-AL` yoksa önce clone et:

```bash
cd ~
git clone -b cursor/hud-day-night-doors-02d8 https://github.com/eymen533/EYMENSOC-AL.git
cd EYMENSOC-AL
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
# → static let buildId = "xcode-ble-28"
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

Klasör başka isimdeyse bul:

```bash
find ~ -maxdepth 4 -type d -name 'EYMENSOC-AL' 2>/dev/null
# veya
mdfind -name 'PulsePhoneKey.xcodeproj'
```

Bulunca:

```bash
cd /bulunan/yol/EYMENSOC-AL
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
bash pull-pulse.sh
```

Xcode: Clean Build Folder → telefondaki eski Pulse’u sil → Run.  
İkon: **Pulse28** · ekran: **xcode-ble-28**.
