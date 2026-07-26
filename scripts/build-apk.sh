#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -d "$HOME/android-sdk" ]]; then
    export ANDROID_HOME="$HOME/android-sdk"
  elif [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  fi
fi

if [[ -z "${ANDROID_HOME:-}" || ! -d "$ANDROID_HOME" ]]; then
  echo "ANDROID_HOME bulunamadı. Android SDK kurulu olmalı." >&2
  exit 1
fi

export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

npm install
npm run build

if [[ ! -d android ]]; then
  npx cap add android
fi

npx cap sync android
echo "sdk.dir=$ANDROID_HOME" > android/local.properties
chmod +x android/gradlew
(cd android && ./gradlew assembleDebug --no-daemon)

mkdir -p artifacts
cp android/app/build/outputs/apk/debug/app-debug.apk artifacts/BalonPatlat.apk
echo "APK hazır: artifacts/BalonPatlat.apk"
