#!/bin/bash
# Okigae をビルドして Okigae.app を作る。Xcode 本体は不要（Command Line Tools のみで動く）。
set -euo pipefail

cd "$(dirname "$0")"

APP="Okigae.app"
TARGET="arm64-apple-macos14.0"
VERSION="${MENUKO_VERSION:-0.0.0}"

rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS"

swiftc \
  -parse-as-library \
  -target "$TARGET" \
  -O \
  -framework AppKit \
  -o "$APP/Contents/MacOS/Okigae" \
  Sources/StatusItems.swift Sources/Backdrop.swift Sources/OverlayPanel.swift \
  Sources/Assignments.swift Sources/main.swift

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Okigae</string>
  <key>CFBundleDisplayName</key><string>Okigae</string>
  <key>CFBundleExecutable</key><string>Okigae</string>
  <key>CFBundleIdentifier</key><string>io.kkweb.okigae</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <!-- Dock とアプリ切替に出さず、メニューバーだけに常駐させる -->
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 開発用の自己署名証明書があればそれで署名する。
# アドホック署名だとビルドのたびに署名が変わり、画面収録の許可が外れてしまう。
# 証明書は Tools/make-cert.sh で作る。
if security find-identity -v -p codesigning | grep -q "Okigae Dev"; then
  codesign --force --sign "Okigae Dev" "$APP"
else
  echo "警告: Okigae Dev の証明書が見つかりません。アドホック署名にします。"
  echo "      ビルドのたびに画面収録の許可が外れます。Tools/make-cert.sh を実行してください。"
  codesign --force --sign - "$APP"
fi

echo "できました: $(pwd)/$APP"
