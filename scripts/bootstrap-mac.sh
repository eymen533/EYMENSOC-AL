#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v xcodegen >/dev/null 2>&1; then
  echo "→ Generating project with XcodeGen..."
  xcodegen generate
else
  echo "→ XcodeGen not found; regenerating project.pbxproj via Python..."
  python3 scripts/generate_xcodeproj.py
fi

echo "→ Open SOC.xcodeproj in Xcode, select your Team under Signing, then Run on your iPhone."
echo "   First launch: pair with VIN while sitting in the car (Park) with key card ready."
