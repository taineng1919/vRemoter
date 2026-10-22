#!/bin/zsh
# App-only local release. Does not install anything or package a HAL driver.
set -euo pipefail
cd "${0:A:h}/.."
VREMOTER_CONFIGURATION=release ./scripts/build-development-app.sh
APP="$PWD/dist/release/vRemote9451.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
PATCH=$(/usr/libexec/PlistBuddy -c 'Print :VRPatchRevision' "$APP/Contents/Info.plist")
FINAL="$PWD/dist/vRemoter-$VERSION-$PATCH.dmg"
STAGING=$(mktemp -d "$PWD/dist/.local-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/vRemote.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/安装说明.txt" <<'TXT'
vRemoter 9451 语音适配版（仅 App）

请先正常退出 vRemoter，并备份 /Applications/vRemote.app，再替换 App。
此镜像不含驱动、安装脚本或配对配置。保留现有驱动和应用配置。
需要回退时，正常退出新 App，将备份的旧 App 放回原位置再启动。

修复虚拟音频的闲置输入占用，保留 9451 短按切换、长按松开结束。
官方更新按钮仅查看说明，升级前须先在定制分支合并和测试。
本版本没有增加 9451 普通 HID 按键映射，也不提供鼠标指针控制。
TXT
codesign --verify --deep --strict "$STAGING/vRemote.app"
hdiutil create -volname "vRemoter $VERSION 9451" -srcfolder "$STAGING" \
  -ov -format UDZO "$FINAL"
hdiutil verify "$FINAL"
python3 - "$APP" "$FINAL" <<'PY'
import hashlib,json,pathlib,plistlib,sys
app,dmg=map(pathlib.Path,sys.argv[1:])
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
manifest={k:info[k] for k in ['CFBundleShortVersionString','CFBundleIdentifier','VRPatchRevision','VRSourceCommit']}
manifest['dmgSHA256']=hashlib.sha256(dmg.read_bytes()).hexdigest()
manifest['executableSHA256']=hashlib.sha256((app/'Contents/MacOS/vRemote').read_bytes()).hexdigest()
dmg.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
print "Built local App-only installer: $FINAL"
