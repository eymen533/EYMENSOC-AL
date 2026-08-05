#!/bin/bash
set -euo pipefail
echo "=== Pulse28 fresh install ==="
cd ~
if [ -d EYMENSOC-AL ]; then
  echo "Eski klasor siliniyor: ~/EYMENSOC-AL"
  rm -rf EYMENSOC-AL
fi
git clone -b cursor/hud-day-night-doors-02d8 https://github.com/eymen533/EYMENSOC-AL.git
cd EYMENSOC-AL
echo ""
echo "=== BUILD_ID.txt ==="
cat BUILD_ID.txt
echo ""
echo "=== BLEPairer.buildId ==="
grep 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
ID="$(grep -o 'xcode-ble-[0-9]*' ios/PulsePhoneKey/Sources/BLEPairer.swift | head -1)"
if [ "$ID" != "xcode-ble-75" ]; then
  echo "HATA: beklenen xcode-ble-75, bulunan: $ID"
  exit 1
fi
echo "OK — $ID"
open -a Xcode "$(pwd)/ios/PulsePhoneKey/PulsePhoneKey.xcodeproj"
echo ""
echo "Xcode acildi. Clean Build Folder, sonra Run."
echo "Telefonda YENI ikon: Pulse28  (eski Pulse/23 ikonuna dokunma)"
