# Pulse28 — eski 23 kalırsa bunu yap

Eski **Pulse** ikonu hâlâ 23 gösterir. Yeni app ayrı: **Pulse28**.

```bash
cd ~
# tek satır kurulum
curl -fsSL https://raw.githubusercontent.com/eymen533/EYMENSOC-AL/cursor/hud-day-night-doors-02d8/install-pulse28.sh | bash
```

veya:

```bash
rm -rf ~/EYMENSOC-AL
cd ~
git clone -b cursor/hud-day-night-doors-02d8 https://github.com/eymen533/EYMENSOC-AL.git
cd EYMENSOC-AL
cat BUILD_ID.txt
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
open -a Xcode ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

1. Xcode **Product → Clean Build Folder**
2. Scheme / ürün: **Pulse28**
3. Run
4. Ana ekranda **Pulse28** ikonunu aç (eski Pulse değil)
5. Sarı kapsül: **xcode-ble-29**
