#!/bin/zsh
# Run ONLY after reviewing hardware acceptance and obtaining installation approval.
# Also serves as rollback: pass a previous backup's vRemote.app as the source.
set -euo pipefail
cd "${0:A:h}/.."
[[ $# == 2 && "$1" == --approved ]] || {
  print -u2 'After user approval: scripts/swap-reviewed-app.sh --approved /absolute/path/to/reviewed.app'
  exit 1
}
SOURCE="${2:A}"
TARGET=/Applications/vRemote.app
[[ "$SOURCE" != "$TARGET" && -d "$SOURCE" && -d "$TARGET" ]] || {
  print -u2 'Source and installed target must be distinct existing App bundles.'; exit 1
}
if /usr/bin/pgrep -x vRemote >/dev/null; then
  print -u2 'Quit the installed and development Apps first.'; exit 1
fi
IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")
[[ "$IDENTIFIER" == local.simaqingfeng.vRemote ]] || { print -u2 'Unexpected source identity'; exit 1; }
codesign --verify --deep --strict "$SOURCE"
codesign -v -R '=identifier "local.simaqingfeng.vRemote"' "$SOURCE"
mkdir -p .local/backups
BACKUP=$(mktemp -d "$PWD/.local/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")
# A verified copy exists before anything in /Applications is renamed.
ditto "$TARGET" "$BACKUP/vRemote.app"
codesign --verify --deep --strict "$BACKUP/vRemote.app"
cmp "$TARGET/Contents/MacOS/vRemote" "$BACKUP/vRemote.app/Contents/MacOS/vRemote"
PREFS="$HOME/Library/Preferences/local.simaqingfeng.vRemote.plist"
[[ ! -f "$PREFS" ]] || cp -p "$PREFS" "$BACKUP/Preferences-before.plist"
ELEVATE=()
[[ -w /Applications ]] || ELEVATE=(sudo)
STAGE="/Applications/.vRemote-9451-stage-${BACKUP:t}.app"
[[ ! -e "$STAGE" ]] || { print -u2 'Staging path already exists'; exit 1; }
"${ELEVATE[@]}" ditto "$SOURCE" "$STAGE"
codesign --verify --deep --strict "$STAGE"
"${ELEVATE[@]}" mv "$TARGET" "$BACKUP/Previous-installed.app"
if ! "${ELEVATE[@]}" mv "$STAGE" "$TARGET"; then
  "${ELEVATE[@]}" mv "$BACKUP/Previous-installed.app" "$TARGET"
  print -u2 'Replacement failed; previous App restored.'
  exit 1
fi
if ! codesign --verify --deep --strict "$TARGET"; then
  "${ELEVATE[@]}" mv "$TARGET" "$BACKUP/Failed-replacement.app"
  "${ELEVATE[@]}" mv "$BACKUP/Previous-installed.app" "$TARGET"
  print -u2 'Post-swap verification failed; previous App restored.'
  exit 1
fi
print -r -- "$SOURCE" > "$BACKUP/Installed-source.txt"
print "Installed App only. Backup: $BACKUP"
print "Rollback after approval: scripts/swap-reviewed-app.sh --approved '$BACKUP/vRemote.app'"
print 'Driver, preferences, application data, Bluetooth and privacy settings were not replaced.'
