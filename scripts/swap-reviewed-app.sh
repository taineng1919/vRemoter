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
NEEDS_ADMIN_READ=0
for resource_file in "$TARGET"/**/*(DN.); do
  if [[ ! -r "$resource_file" ]]; then NEEDS_ADMIN_READ=1; break; fi
done
if (( NEEDS_ADMIN_READ )); then
  print 'macOS administrator authorization is needed to back up root-only App resources.'
  # Elevate only the copy, then give the user ownership of their backup.
  # Never chmod/chown the installed source. quoted form protects all paths.
  /usr/bin/osascript - "$TARGET" "$BACKUP/vRemote.app" "$(id -u)" "$(id -g)" <<'APPLESCRIPT'
on run argv
    set sourcePath to item 1 of argv
    set backupPath to item 2 of argv
    set ownerID to (item 3 of argv) & ":" & (item 4 of argv)
    set copyCommand to "/usr/bin/ditto " & quoted form of sourcePath & " " & quoted form of backupPath
    set copyCommand to copyCommand & " && /usr/sbin/chown -R " & quoted form of ownerID & " " & quoted form of backupPath
    do shell script copyCommand with administrator privileges
end run
APPLESCRIPT
else
  ditto "$TARGET" "$BACKUP/vRemote.app"
fi
codesign --verify --deep --strict "$BACKUP/vRemote.app"
cmp "$TARGET/Contents/MacOS/vRemote" "$BACKUP/vRemote.app/Contents/MacOS/vRemote"
PREFS="$HOME/Library/Preferences/local.simaqingfeng.vRemote.plist"
[[ ! -f "$PREFS" ]] || cp -p "$PREFS" "$BACKUP/Preferences-before.plist"
STAGE="/Applications/.vRemote-9451-stage-${BACKUP:t}.app"
[[ ! -e "$STAGE" ]] || { print -u2 'Staging path already exists'; exit 1; }
# /Applications can be writable while a root-owned installed bundle still
# rejects rename. Authorize the complete staged swap through macOS, not sudo
# on a noninteractive terminal. Every elevated path is confined to these Apps.
/usr/bin/osascript - "$SOURCE" "$STAGE" "$TARGET" "$BACKUP/Previous-installed.app" "$BACKUP/Failed-replacement.app" <<'APPLESCRIPT'
on run argv
    set sourcePath to quoted form of item 1 of argv
    set stagePath to quoted form of item 2 of argv
    set targetPath to quoted form of item 3 of argv
    set previousPath to quoted form of item 4 of argv
    set failedPath to quoted form of item 5 of argv
    set swapCommand to "set -e; /usr/bin/ditto " & sourcePath & " " & stagePath
    set swapCommand to swapCommand & "; /usr/bin/codesign --verify --deep --strict " & stagePath
    set swapCommand to swapCommand & "; /bin/mv " & targetPath & " " & previousPath
    set swapCommand to swapCommand & "; if /bin/mv " & stagePath & " " & targetPath & "; then "
    set swapCommand to swapCommand & "if /usr/bin/codesign --verify --deep --strict " & targetPath & "; then :; else "
    set swapCommand to swapCommand & "/bin/mv " & targetPath & " " & failedPath & "; /bin/mv " & previousPath & " " & targetPath & "; exit 1; fi; "
    set swapCommand to swapCommand & "else /bin/mv " & previousPath & " " & targetPath & "; exit 1; fi"
    do shell script swapCommand with administrator privileges
end run
APPLESCRIPT
codesign --verify --deep --strict "$TARGET"
print -r -- "$SOURCE" > "$BACKUP/Installed-source.txt"
print "Installed App only. Backup: $BACKUP"
print "Rollback after approval: scripts/swap-reviewed-app.sh --approved '$BACKUP/vRemote.app'"
print 'Driver, preferences, application data, Bluetooth and privacy settings were not replaced.'
