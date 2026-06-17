#!/usr/bin/env bash
# Live iPad <-> browser collaboration: starts a relay, joins a browser
# (Playwright) and the real iOS-simulator app to the same room, and asserts each
# side sees the other's element. Proves the two real apps collaborate end-to-end.
#
# Usage: web/scripts/collab-live.sh   (run from anywhere)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="${REPO_ROOT}/web"
PORT="${PORT:-4399}"
ROOM="live-$$"
RELAY_URL="ws://127.0.0.1:${PORT}"
SIM="${SIM:-iPhone 15}"
RELAY_BUNDLE="/tmp/xs-relay-$$.cjs"
WEB_LOG="/tmp/collab-web-$$.log"
RELAY_LOG="/tmp/collab-relay-$$.log"
ESB="${WEB}/node_modules/.pnpm/node_modules/.bin/esbuild"

RELAY_PID=""
WEB_PID=""
cleanup() {
  [ -n "${WEB_PID}" ] && kill "${WEB_PID}" 2>/dev/null
  [ -n "${RELAY_PID}" ] && kill "${RELAY_PID}" 2>/dev/null
  rm -f "${RELAY_BUNDLE}"
}
trap cleanup EXIT

echo ">> Bundling relay"
"${ESB}" "${WEB}/server/src/run.ts" --bundle --platform=node --format=cjs --outfile="${RELAY_BUNDLE}" >/dev/null || exit 1

echo ">> Starting relay on port ${PORT}"
PORT="${PORT}" node "${RELAY_BUNDLE}" >"${RELAY_LOG}" 2>&1 &
RELAY_PID=$!
sleep 1
grep -q "relay listening" "${RELAY_LOG}" || { echo "relay failed:"; cat "${RELAY_LOG}"; exit 1; }

echo ">> Starting browser peer (Playwright) in room ${ROOM}"
( cd "${WEB}" && XS_RELAY="${RELAY_URL}" XS_ROOM="${ROOM}" \
  pnpm --filter excalidraw-web-app exec playwright test -g "browser shares one room" ) \
  >"${WEB_LOG}" 2>&1 &
WEB_PID=$!

echo ">> Generating Xcode project + running the iOS simulator app"
cd "${REPO_ROOT}"
xcodegen generate >/dev/null 2>&1
# Pick a concrete, valid simulator the scheme supports (the app is iPad-only).
DEST_ID=$(xcodebuild -showdestinations -scheme ExcalidrawApp -project ExcalidrawSwift.xcodeproj 2>/dev/null \
  | grep -E 'platform:iOS Simulator' | grep -vE 'placeholder|unavailable|Any iOS' \
  | grep -oE 'id:[0-9A-Fa-f-]+' | head -1 | cut -d: -f2)
echo ">> Using simulator id: ${DEST_ID}"
[ -z "${DEST_ID}" ] && { echo "no simulator destination found"; exit 1; }
TEST_RUNNER_COLLAB_RELAY="${RELAY_URL}" \
TEST_RUNNER_COLLAB_ROOM="${ROOM}" \
TEST_RUNNER_COLLAB_NAME="ipad" \
xcodebuild test \
  -project ExcalidrawSwift.xcodeproj \
  -scheme ExcalidrawApp \
  -destination "platform=iOS Simulator,id=${DEST_ID}" \
  -only-testing:ExcalidrawAppUITests/CollabLiveUITests \
  -resultBundlePath "/tmp/collab-ios-$$.xcresult" \
  2>&1 | grep -iE "Test Suite|Test Case|passed|failed|error:|shared element" | tail -25
IOS_RC=${PIPESTATUS[0]}

echo ">> Waiting for the browser peer to confirm convergence"
wait "${WEB_PID}"; WEB_RC=$?
WEB_PID=""

echo "-------- results --------"
echo "iOS simulator test : $([ ${IOS_RC} -eq 0 ] && echo PASS || echo FAIL)"
echo "Browser peer test  : $([ ${WEB_RC} -eq 0 ] && echo PASS || echo FAIL)"
[ ${WEB_RC} -ne 0 ] && { echo "-- browser log (tail) --"; tail -30 "${WEB_LOG}"; }
[ ${IOS_RC} -eq 0 ] && [ ${WEB_RC} -eq 0 ] && { echo "OK: iPad and browser collaborated live."; exit 0; }
exit 1
