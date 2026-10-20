#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BUILD_ROOT="$PWD/.build-development"
CONFIGURATION="${VREMOTER_CONFIGURATION:-debug}"
[[ "$CONFIGURATION" == debug || "$CONFIGURATION" == release ]] || { print -u2 'Use debug or release'; exit 1; }
APP="$PWD/dist/$CONFIGURATION/vRemote9451.app"
SDK_ARGS=()
if [[ -n "${VREMOTER_SDK:-}" ]]; then
  SDK_ARGS=(--sdk "$VREMOTER_SDK")
fi
swift build --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache" \
  --config-path "$BUILD_ROOT/config" --security-path "$BUILD_ROOT/security" \
  --build-system native "${SDK_ARGS[@]}" -c "$CONFIGURATION"
BIN_DIR=$(swift build --scratch-path "$BUILD_ROOT" --build-system native \
  "${SDK_ARGS[@]}" -c "$CONFIGURATION" --show-bin-path)
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/vRemote" "$APP/Contents/MacOS/vRemote"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
for resource_bundle in "$BIN_DIR/"*.bundle(N); do
  ditto "$resource_bundle" "$APP/Contents/Resources/${resource_bundle:t}"
done
for localization in Packaging/*.lproj(N); do
  ditto "$localization" "$APP/Contents/Resources/${localization:t}"
done
for resource in PermissionGuides Commerce RemoteImages; do
  [[ ! -d "Resources/$resource" ]] || ditto "Resources/$resource" "$APP/Contents/Resources/$resource"
done
[[ ! -d Resources/buymeacoffee ]] || ditto Resources/buymeacoffee "$APP/Contents/Resources/BuyMeACoffee"
cp Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png "$APP/Contents/Resources/vRemoterLogo.png"
ICONSET="$PWD/dist/$CONFIGURATION/vRemoter.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$APP/Contents/Resources/vRemoterLogo.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$APP/Contents/Resources/vRemoterLogo.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/vRemoter.icns"
python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib,sys
p=sys.argv[1]
with open(p,'rb') as f: info=plistlib.load(f)
info.update(CFBundleDisplayName='vRemoter 9451 Development',
            CFBundleShortVersionString='1.1.1-9451-dev',
            VRTelemetryDeckAppID='',VRCommerceConfigURL='')
with open(p,'wb') as f: plistlib.dump(info,f)
PY
chmod -R u+w "$APP"
xattr -cr "$APP"
codesign --force --deep --sign - --timestamp=none \
  --requirements '=designated => identifier "local.simaqingfeng.vRemote"' "$APP"
codesign --verify --deep --strict "$APP"
print "Built complete $CONFIGURATION App: $APP"
