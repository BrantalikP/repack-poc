#!/usr/bin/env bash
#
# Full native Android build. Only needed when the fingerprint has no cached APK.
# Leaves the result at artifacts/app.apk.

set -euo pipefail

npx expo prebuild --platform android --clean
./android/gradlew -p android assembleRelease --no-daemon

mkdir -p artifacts
cp android/app/build/outputs/apk/release/app-release.apk artifacts/app.apk
