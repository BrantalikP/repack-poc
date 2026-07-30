#!/usr/bin/env bash
#
# Swaps a freshly built JS bundle into the cached native APK. Valid only when the
# fingerprint matches the source binary -- see README.
# Reads artifacts/app.apk, writes artifacts/repacked.apk.

set -euo pipefail

npx --yes @expo/repack-app@latest \
  --platform android \
  --source-app artifacts/app.apk \
  --output artifacts/repacked.apk \
  --verbose
