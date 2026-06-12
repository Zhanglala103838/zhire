#!/bin/bash
# 构建知热.app：swift release 构建 → 组装 bundle → Developer ID 签名
# 用法：
#   ./scripts/build-app.sh             仅构建+签名（日常自用）
#   ./scripts/build-app.sh --notarize  构建+签名+DMG+公证+装订（对外发布）
#
# 凭据：放 scripts/signing.env（已 gitignore，不入库），或预先 export 环境变量：
#   APPLE_SIGNING_IDENTITY  Developer ID Application: YOUR NAME (TEAMID)
#   APPLE_API_KEY           App Store Connect API Key ID（仅 --notarize 需要）
#   APPLE_API_ISSUER        Issuer UUID（仅 --notarize 需要）
#   APPLE_API_KEY_PATH      AuthKey_XXXX.p8 路径（仅 --notarize 需要）
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f scripts/signing.env ]] && source scripts/signing.env

SIGN_IDENTITY="${APPLE_SIGNING_IDENTITY:?需要 APPLE_SIGNING_IDENTITY（见脚本头部注释）}"
APP="build/知热.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG="build/Zhire-${VERSION}.dmg"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Zhire "$APP/Contents/MacOS/Zhire"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 稳定签名身份（不走 ad-hoc，避免 cdhash 漂移导致 TCC/自启授权丢失）
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"

echo "✅ Built & signed: $APP"
echo "   安装：cp -R \"$APP\" /Applications/"

# ── 发布链路：DMG + 公证 + 装订 ──
if [[ "${1:-}" == "--notarize" ]]; then
  : "${APPLE_API_KEY:?需要 APPLE_API_KEY（App Store Connect API Key ID）}"
  : "${APPLE_API_ISSUER:?需要 APPLE_API_ISSUER（Issuer UUID）}"
  : "${APPLE_API_KEY_PATH:?需要 APPLE_API_KEY_PATH（AuthKey .p8 路径）}"
  [[ -f "$APPLE_API_KEY_PATH" ]] || { echo "❌ API Key .p8 不在: $APPLE_API_KEY_PATH"; exit 1; }

  STAGE="build/dmg-stage"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "知热" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
  rm -rf "$STAGE"

  # DMG 本身也要签名（只公证不签名会被 spctl 以 no usable signature 拒绝）
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

  echo "⏳ 提交公证（DMG 整体提交，ticket 覆盖内嵌 .app）…"
  xcrun notarytool submit "$DMG" \
    --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY" --issuer "$APPLE_API_ISSUER" \
    --wait

  # DMG 和本地 .app 都装订 ticket（同一 cdhash，离线 Gatekeeper 也放行）
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APP"

  echo "── Gatekeeper 验证 ──"
  spctl -a -t open --context context:primary-signature -v "$DMG"
  spctl -a -t exec -v "$APP"
  echo "✅ 公证+装订完成: $DMG"
fi
