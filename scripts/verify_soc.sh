#!/usr/bin/env bash
# Structural + offline-dependency verification for SOC (run before shipping).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTPM="$ROOT/SOC.swiftpm"
FAIL=0

note() { echo "✓ $*"; }
bad() { echo "✗ $*"; FAIL=1; }

echo "== SOC verification =="

# 1) Required playground files
[[ -f "$SWIFTPM/Package.swift" ]] && note "Package.swift exists" || bad "Package.swift missing"
[[ -f "$SWIFTPM/App/SOCApp.swift" ]] && note "SOCApp.swift exists" || bad "SOCApp.swift missing"
[[ -d "$SWIFTPM/Assets.xcassets/AppIcon.appiconset" ]] && note "AppIcon asset exists" || bad "AppIcon missing"
[[ -f "$SWIFTPM/Assets.xcassets/TeslaModel3Top.imageset/TeslaModel3Top.png" ]] && note "Model 3 image exists" || bad "Model 3 image missing"

# 2) No remote package URLs in Playgrounds Package.swift (prevents iPad spinner)
if grep -E 'package\(url:\s*"https?://' "$SWIFTPM/Package.swift" >/dev/null; then
  bad "Package.swift still has remote package URL(s) — Playgrounds will hang"
else
  note "Package.swift has no remote package URLs"
fi

# 3) Vendored deps present and offline
[[ -f "$SWIFTPM/Packages/TeslaBLEKeyKit/Package.swift" ]] && note "Vendored TeslaBLEKeyKit" || bad "TeslaBLEKeyKit not vendored"
[[ -f "$SWIFTPM/Packages/swift-protobuf/Package.swift" ]] && note "Vendored swift-protobuf" || bad "swift-protobuf not vendored"

if grep -E 'package\(url:\s*"https?://' "$SWIFTPM/Packages/TeslaBLEKeyKit/Package.swift" >/dev/null; then
  bad "Vendored TeslaBLEKeyKit still points at remote URL"
else
  note "TeslaBLEKeyKit uses local protobuf path"
fi

# 4) AppModule excludes Packages/ (avoids compiling vendor twice)
grep -q '"Packages"' "$SWIFTPM/Package.swift" && note "Packages/ excluded from AppModule" || bad "Packages/ not excluded"

# 5) Swift source count sanity
COUNT=$(find "$SWIFTPM" -path "$SWIFTPM/Packages" -prune -o -name "*.swift" -print | wc -l)
[[ "$COUNT" -ge 15 ]] && note "App Swift files: $COUNT" || bad "Too few app Swift files: $COUNT"

# 6) @main exactly once in app module (not in Packages)
MAIN_COUNT=$(grep -R --include='*.swift' -l '^@main' "$SWIFTPM/App" "$SWIFTPM/Features" "$SWIFTPM/Services" "$SWIFTPM/Models" "$SWIFTPM/Utilities" 2>/dev/null | wc -l)
[[ "$MAIN_COUNT" -eq 1 ]] && note "Single @main entry point" || bad "@main count=$MAIN_COUNT"

# 7) Build vendored protobuf on Linux (sanity that vendor tree is intact)
if command -v swift >/dev/null 2>&1; then
  export PATH="${HOME}/swift/usr/bin:${PATH}"
  if (cd "$SWIFTPM/Packages/swift-protobuf" && swift build --product SwiftProtobuf >/tmp/soc-protobuf-build.log 2>&1); then
    note "swift-protobuf builds on Linux"
  else
    bad "swift-protobuf failed to build — see /tmp/soc-protobuf-build.log"
    tail -20 /tmp/soc-protobuf-build.log || true
  fi
else
  echo "(skip) swift not installed — protobuf build check skipped"
fi

# 8) Preview HTML uses absolute image URL (works when hosted)
if grep -Eq 'cdn\.jsdelivr\.net/.*/tesla-model3-topdown\.png|raw\.githubusercontent\.com/.*/tesla-model3-topdown\.png' "$ROOT/docs/preview.html"; then
  note "preview.html uses absolute Model 3 image URL"
else
  bad "preview.html Model 3 image URL is not absolute"
fi

# 9) Produce zip and verify layout
mkdir -p "$ROOT/dist"
ZIP="$ROOT/dist/SOC-iPad.swiftpm.zip"
rm -f "$ZIP"
(
  cd "$ROOT"
  zip -qr "$ZIP" SOC.swiftpm \
    -x 'SOC.swiftpm/Packages/*/.build/*' \
    -x 'SOC.swiftpm/Packages/*/.swiftpm/*' \
    -x 'SOC.swiftpm/**/.DS_Store'
)
[[ -f "$ZIP" ]] && note "Wrote $ZIP ($(du -h "$ZIP" | awk '{print $1}'))" || bad "zip failed"

# Unzip to temp and confirm Package.swift at expected path
TMP=$(mktemp -d)
unzip -q "$ZIP" -d "$TMP"
[[ -f "$TMP/SOC.swiftpm/Package.swift" ]] && note "Zip extracts to SOC.swiftpm/Package.swift" || bad "Zip layout wrong"
[[ -d "$TMP/SOC.swiftpm/Packages/TeslaBLEKeyKit" ]] && note "Zip includes vendored TeslaBLEKeyKit" || bad "Zip missing vendor"
rm -rf "$TMP"

# 10) Preview file content smoke (no long-lived server)
if grep -q 'SOC Dashboard Preview' "$ROOT/docs/preview.html"; then
  note "preview.html contains expected title"
else
  bad "preview.html missing title"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "CHECKS FAILED"
  exit 1
fi
