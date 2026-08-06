#!/bin/bash
# Prefer install-pulse28.sh for a clean clone. This updates an existing tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
git fetch origin
git checkout cursor/hud-day-night-doors-02d8
git reset --hard origin/cursor/hud-day-night-doors-02d8
echo ""
echo "=== buildId (must be xcode-ble-86) ==="
grep -n 'buildId =' ios/PulsePhoneKey/Sources/BLEPairer.swift
cat BUILD_ID.txt | head -4
open -a Xcode "$ROOT/ios/PulsePhoneKey/PulsePhoneKey.xcodeproj"
echo "Open the NEW home-screen icon: Pulse28"
