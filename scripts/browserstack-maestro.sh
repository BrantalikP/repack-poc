#!/usr/bin/env bash
#
# Runs the Maestro suite from .maestro/ against an APK on BrowserStack.
#
#   scripts/browserstack-maestro.sh artifacts/repacked.apk
#
# Env: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY, DEVICE (optional)
# See README "Gotchas" for why the zip layout and the flow count check matter.

set -euo pipefail

APK=${1:?usage: $0 <apk>}
: "${BROWSERSTACK_USERNAME:?missing}" "${BROWSERSTACK_ACCESS_KEY:?missing}"

AUTH="$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY"
API=https://api-cloud.browserstack.com/app-automate/maestro/v2
DEVICE=${DEVICE:-Google Pixel 7-13.0}
PROJECT=repack-poc

marker=$(sed -n "s/^const JS_MARKER = '\(.*\)';$/\1/p" App.tsx)
echo "app=$APK device=$DEVICE marker=$marker"

# Flows go in a parent folder, with the expected marker substituted in.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/flows"
cp .maestro/*.yaml "$work/flows/"
sed -i.bak "s/__MARKER__/$marker/g" "$work/flows"/*.yaml
rm -f "$work/flows"/*.bak
(cd "$work" && zip -qr suite.zip flows)

execute=$(cd "$work/flows" && ls *.yaml | jq -R . | jq -sc .)
echo "flows=$execute"

app_url=$(curl -fsS -u "$AUTH" -X POST "$API/app" \
  -F "file=@$APK" -F "custom_id=$PROJECT" | jq -r .app_url)
suite_url=$(curl -fsS -u "$AUTH" -X POST "$API/test-suite" \
  -F "file=@$work/suite.zip" -F "custom_id=$PROJECT-flows" | jq -r .test_suite_url)
echo "uploaded app=$app_url suite=$suite_url"

response=$(curl -fsS -u "$AUTH" -X POST "$API/android/build" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg a "$app_url" --arg t "$suite_url" --arg d "$DEVICE" \
              --arg p "$PROJECT" --argjson e "$execute" \
        '{app: $a, testSuite: $t, project: $p, execute: $e, devices: [$d]}')")

build_id=$(echo "$response" | jq -r '.build_id // .buildId // empty')
if [ -z "$build_id" ]; then
  echo "build did not start: $response"
  exit 1
fi
echo "build_id=$build_id"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "build_id=$build_id" >> "$GITHUB_OUTPUT"
fi

status=unknown
for _ in $(seq 1 60); do
  status=$(curl -fsS -u "$AUTH" "$API/builds/$build_id" | jq -r .status)
  echo "status=$status"
  case "$status" in
    queued | running) sleep 15 ;;
    *) break ;;
  esac
done

if [ "$status" != passed ]; then
  echo "build did not pass: $status"
  exit 1
fi

# A build reports "passed" even when it ran only part of the suite.
expected=$(echo "$execute" | jq length)
ran=$(curl -fsS -u "$AUTH" "$API/builds/$build_id" \
  | jq '[.devices[].sessions[].testcases.count] | add // 0')
echo "flows expected=$expected ran=$ran"
if [ "$ran" != "$expected" ]; then
  echo "only $ran of $expected flows ran"
  exit 1
fi
