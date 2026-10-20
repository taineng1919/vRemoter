#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .local/tests .build/module-cache
SWIFTC=(swiftc -module-cache-path "$PWD/.build/module-cache")
"${SWIFTC[@]}" Sources/vRemote/BLERemoteIdentity.swift Tests/Identity/main.swift -o .local/tests/identity
.local/tests/identity
"${SWIFTC[@]}" Sources/vRemote/InputTrigger.swift Tests/Support/Storage.swift Tests/Trigger/main.swift -o .local/tests/trigger
.local/tests/trigger
"${SWIFTC[@]}" Sources/vRemote/WavRecorder.swift Sources/vRemote/InputTrigger.swift \
  Tests/Support/Storage.swift Tests/Recorder/main.swift -o .local/tests/recorder
.local/tests/recorder
"${SWIFTC[@]}" Sources/vRemote/AppPreferences.swift Tests/Preferences/main.swift -o .local/tests/preferences
.local/tests/preferences
./run-self-tests.sh
# Production session state machine is exercised by the complete debug binary.
APP_BIN="${1:-$PWD/dist/debug/vRemote9451.app/Contents/MacOS/vRemote}"
"$APP_BIN" --voice-session-self-test
