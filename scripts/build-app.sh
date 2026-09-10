#!/bin/zsh
# 재현 가능한 로컬 빌드: swift build → .app 번들 생성 → 서명.
# 사용: scripts/build-app.sh [debug|release]
# 서명 ID는 SIGN_IDENTITY 환경변수로 지정. 없으면 키체인의 첫 "Apple Development" ID, 그것도 없으면 ad-hoc(-).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
NAME="MissionControlLabels"
BUNDLE_ID="com.markhan.MissionControlLabels"
VERSION="0.1.0"
OUT="build/${NAME}.app"

swift build -c "$CONFIG" 2>&1 | tail -3
BIN="$(swift build -c "$CONFIG" --show-bin-path)/${NAME}"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/${NAME}"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>Mission Control Labels</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Minung Han. MIT License.</string>
</dict></plist>
PLIST
echo -n "APPL????" > "$OUT/Contents/PkgInfo"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" --options runtime "$OUT" 2>&1 || \
  codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$OUT"
codesign -dv "$OUT" 2>&1 | grep -E 'Identifier|Authority|Signature' | head -3
echo "built: $PWD/$OUT (signed with: $SIGN_IDENTITY)"
