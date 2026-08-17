#!/bin/bash
# 生成した絵を1体ぶん取り込む。
#
#   ./Tools/add-character.sh <生成した.png> <ローマ字の名前> <かなの読み>
#   ./Tools/add-character.sh ~/Downloads/image.png nagisa なぎさ
#
# やること:
#   1. 透明な余白を落として正方形にし、Resources/Characters/<名前>.png に置く
#   2. Sources/Assignments.swift の読みの表に一行足す
#   3. lp/public/ へ複製し、lp のキャラクター一覧と文言に足す
#   4. メニューバーの実寸に縮めた見本を docs/preview-<名前>.png に出す
#
# 名前はファイル名そのものが識別子になる。assignments.json に書かれる値でもあるので、
# 一度配ったら変えられない。変えるときは Assignments.renamed に対応を足すこと。
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -lt 3 ]; then
  echo "使い方: ./Tools/add-character.sh <生成した.png> <ローマ字の名前> <かなの読み>" >&2
  exit 1
fi

SOURCE="$1"
NAME="$2"
READING="$3"

if [ ! -f "$SOURCE" ]; then
  echo "見つかりません: $SOURCE" >&2
  exit 1
fi

if ! printf '%s' "$NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "名前は英小文字で: $NAME" >&2
  exit 1
fi

DESTINATION="Resources/Characters/${NAME}.png"
if [ -e "$DESTINATION" ]; then
  echo "既にあります: $DESTINATION" >&2
  exit 1
fi

# 1. 正方形にして置く
swift Tools/square.swift "$SOURCE" "$DESTINATION"

# 2. 読みの表に足す。最後の行の後ろに差し込む
python3 - "$NAME" "$READING" <<'PY'
import pathlib, re, sys

name, reading = sys.argv[1], sys.argv[2]
path = pathlib.Path("Sources/Assignments.swift")
text = path.read_text()

marker = re.search(r'(private static let readings: \[String: String\] = \[)(.*?)(\n    \])', text, re.S)
if marker is None:
    sys.exit("readings の表が見つかりません")
if f'"{name}"' in marker.group(2):
    sys.exit(f"読みの表に既にあります: {name}")

updated = marker.group(2).rstrip()
if not updated.endswith(","):
    updated += ","
updated += f'\n        "{name}": "{reading}",'
path.write_text(text[:marker.start(2)] + updated + text[marker.end(2):])
print(f"読みを足しました: {name} = {reading}")
PY

# 3. LP に足す
if [ -d lp/public ]; then
  cp "$DESTINATION" "lp/public/${NAME}.png"
  python3 - "$NAME" "$READING" <<'PY'
import collections, json, pathlib, re, sys

name, reading = sys.argv[1], sys.argv[2]

page = pathlib.Path("lp/src/app/[locale]/page.tsx")
text = page.read_text()
block = re.search(r'(const CHARACTERS = \[)(.*?)(\n\] as const;)', text, re.S)
if block is None:
    sys.exit("CHARACTERS の並びが見つかりません")
if f'"{name}"' not in block.group(2):
    body = block.group(2).rstrip()
    if not body.endswith(","):
        body += ","
    body += f'\n  "{name}",'
    page.write_text(text[:block.start(2)] + body + text[block.end(2):])
    print(f"LP の一覧に足しました: {name}")

for locale in ("ja", "en"):
    path = pathlib.Path(f"lp/messages/{locale}.json")
    data = json.loads(path.read_text(), object_pairs_hook=collections.OrderedDict)
    label = reading if locale == "ja" else name.capitalize()
    data["characters"][name] = label
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"{locale} の文言に足しました: {label}")
PY
fi

# 4. メニューバーの実寸で見る
mkdir -p build docs
swiftc -O -target arm64-apple-macos14.0 -framework AppKit \
  -o build/shrink Tools/shrink/main.swift
./build/shrink "$DESTINATION" "docs/preview-${NAME}.png"

echo
echo "取り込みました: ${NAME}（${READING}）"
echo "  絵      $DESTINATION"
echo "  見本    docs/preview-${NAME}.png"
echo "次は ./build.sh で建て直すと、設定画面に出ます。"
