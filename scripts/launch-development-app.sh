#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
APP="$PWD/dist/debug/vRemote9451.app"
PROFILE="$PWD/.local/runtime"
[[ -d "$APP" ]] || { print -u2 'Build the debug App first.'; exit 1; }
# Refuse parallel instances, including the installed App with the same identity.
if /usr/bin/pgrep -x vRemote >/dev/null; then
  print -u2 'Quit the running vRemoter before launching the development App.'
  exit 1
fi
python3 - "$PROFILE" <<'PY'
import pathlib,plistlib,sys
root=pathlib.Path(sys.argv[1]); root.mkdir(parents=True,exist_ok=True)
prefs=root/'Preferences.plist'
if not prefs.exists():
    prefs.write_bytes(plistlib.dumps({
        'inputTriggerKey':'function','functionHoldEnabled':True,
        'macInputEnabled':False,'remoteInputEnabled':True,
        'loggingEnabled':True,'recordingEnabled':True,
        'vRemoter.automaticUpdates':False,
        'vRemoter.hasCompletedX6MicTest':True,
    }))
PY
open -n --env "VREMOTER_DATA_ROOT=$PROFILE" --env MIA_DIAGNOSTICS=1 "$APP"
print "Development profile: $PROFILE"
print 'Use the validation text window. Check actual Doubao input is vRemoteDr 2ch.'
