#!/bin/bash
# Okigae をビルドして Okigae.app を作る。Xcode 本体は不要（Command Line Tools のみで動く）。
set -euo pipefail

cd "$(dirname "$0")"

APP="Okigae.app"
TARGET="arm64-apple-macos14.0"
VERSION="${OKIGAE_VERSION:-0.0.0}"
SPARKLE_VERSION="2.9.5"

# 自動更新に Sparkle を使う。framework は大きいのでリポジトリに置かず、
# 無ければ取ってくる（Vendor/ は git の管理外）
if [ ! -d "Vendor/Sparkle.framework" ]; then
  echo "Sparkle $SPARKLE_VERSION を取得します…"
  mkdir -p Vendor
  TMP="$(mktemp -d)"
  curl -sL -o "$TMP/sparkle.tar.xz" \
    "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
  tar xf "$TMP/sparkle.tar.xz" -C "$TMP"
  cp -R "$TMP/Sparkle.framework" Vendor/
  cp -R "$TMP/bin" Vendor/
  rm -rf "$TMP"
fi

rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"

cp -R Vendor/Sparkle.framework "$APP/Contents/Frameworks/"

swiftc \
  -parse-as-library \
  -target "$TARGET" \
  -O \
  -F Vendor \
  -framework AppKit \
  -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$APP/Contents/MacOS/Okigae" \
  Sources/StatusItems.swift Sources/Backdrop.swift Sources/OverlayPanel.swift \
  Sources/Assignments.swift Sources/SettingsWindow.swift Sources/Updater.swift Sources/main.swift

# アプリ本体のアイコン。元絵があれば .icns を組み立てる
if [ -f Resources/app-icon.png ]; then
  ICONSET="build/Okigae.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size Resources/app-icon.png \
      --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/app-icon.png \
      --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$APP/Contents/Resources"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Okigae.icns"
fi

# メニューバーに出す絵
if [ -f Resources/menu-icon.png ]; then
  mkdir -p "$APP/Contents/Resources"
  cp Resources/menu-icon.png "$APP/Contents/Resources/"
fi

# 同梱するキャラの絵。初回起動で Application Support へ書き出される
if [ -d Resources/Faces ]; then
  mkdir -p "$APP/Contents/Resources/Faces"
  cp Resources/Faces/*.png "$APP/Contents/Resources/Faces/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Okigae</string>
  <key>CFBundleDisplayName</key><string>Okigae</string>
  <key>CFBundleExecutable</key><string>Okigae</string>
  <key>CFBundleIconFile</key><string>Okigae</string>
  <key>CFBundleIdentifier</key><string>io.kkweb.okigae</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <!-- Dock とアプリ切替に出さず、メニューバーだけに常駐させる -->
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>

  <!-- 自動更新（Sparkle）。確認は起動時に1回だけ行い、見つかったときだけ画面を出す。
       この2つを false にしておかないと、初回起動で「自動で確認していいか」を尋ねる画面が出る -->
  <key>SUFeedURL</key><string>https://github.com/piro0919/okigae/releases/latest/download/appcast.xml</string>
  <!-- 更新の署名を確かめる公開鍵。対になる秘密鍵はログインキーチェーンにある。
       Sparkle の鍵はアプリの数によらず一つでよく、Konechi と同じものを使っている -->
  <key>SUPublicEDKey</key><string>qYQq1iewXYNDhhkJJak1nXUXmFkZ0jAF6Gr+pjB4Bxo=</string>
  <key>SUEnableAutomaticChecks</key><false/>
  <key>SUAutomaticallyUpdate</key><false/>
</dict>
</plist>
PLIST

# 開発用の自己署名証明書があればそれで署名する。
# アドホック署名だとビルドのたびに署名が変わり、画面収録の許可が外れてしまう。
# 証明書は Tools/make-cert.sh で作る。
# framework は中から署名する。先にアプリを署名すると、後から中身が変わって壊れる
sign() {
  codesign --force --sign "$1" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" 2>/dev/null || true
  codesign --force --sign "$1" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" 2>/dev/null || true
  codesign --force --sign "$1" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>/dev/null || true
  codesign --force --sign "$1" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" 2>/dev/null || true
  codesign --force --sign "$1" "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign "$1" "$APP"
}

# 配布用はアドホック署名にする。開発用の証明書は受け取った人の Mac には無く、
# 検証に失敗する側へ倒れる。Konechi や chappie も配布物はアドホック署名。
if [ "${OKIGAE_ADHOC:-0}" = "1" ]; then
  sign -
elif security find-identity -v -p codesigning | grep -q "Okigae Dev"; then
  sign "Okigae Dev"
else
  echo "警告: Okigae Dev の証明書が見つかりません。アドホック署名にします。"
  echo "      ビルドのたびに画面収録の許可が外れます。Tools/make-cert.sh を実行してください。"
  sign -
fi

echo "できました: $(pwd)/$APP"
