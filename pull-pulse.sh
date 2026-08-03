#!/bin/bash
# Pulse Key — doğru branch'e çek ve buildId doğrula
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
echo ""
echo "=== buildId (şunu görmelisin: xcode-ble-28) ==="
grep -n 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
echo ""
echo "=== commit ==="
git log -1 --oneline
echo ""
echo "Xcode açılıyor…"
open -a Xcode "$ROOT/ios/PulsePhoneKey/PulsePhoneKey.xcodeproj"
