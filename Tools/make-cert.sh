#!/bin/bash
# 開発用の自己署名証明書を作る。
#
# アドホック署名（codesign -s -）はビルドのたびに署名が変わるため、
# macOS からは毎回別のアプリに見え、画面収録の許可が外れる。
# 署名を固定すれば、ビルドし直しても許可は残る。
set -euo pipefail

NAME="Okigae Dev"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "すでにあります: $NAME"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cfg.conf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -days 3650 -nodes -config "$WORK/cfg.conf" >/dev/null 2>&1

# Security framework が読める形式にする。既定の形式は新しすぎて読めない
openssl pkcs12 -export -legacy -macalg sha1 \
  -out "$WORK/ident.p12" -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -passout pass:okigae >/dev/null 2>&1

security import "$WORK/ident.p12" -k ~/Library/Keychains/login.keychain-db \
  -P okigae -T /usr/bin/codesign -A

# 信頼設定を入れないと codesign から使える identity にならない
security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db "$WORK/cert.pem"

security find-identity -v -p codesigning | grep "$NAME"
