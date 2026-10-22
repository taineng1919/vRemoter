#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .local/tests .build/module-cache
swiftc -module-cache-path "$PWD/.build/module-cache" \
  Sources/vRemote/ChromecastRemoteReportState.swift Tests/ChromecastHID/main.swift \
  -o .local/tests/chromecast-hid
.local/tests/chromecast-hid
