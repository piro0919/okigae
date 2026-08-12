# Drawing the faces

Notes on generating the bundled artwork with ChatGPT's image generation, written after
making eight of them and checking every one at its real size in the menu bar.

## The prompt

Swap the last two lines — hair and expression — and leave the rest alone. Japanese is
fine as-is: terms like `SD`, `ツインテール` and `前髪ぱっつん` have no settled English
equivalent, and translating them makes the style drift.

```text
正方形・透過背景のアプリアイコン用イラストを1枚。
被写体は少女の頭部のみ、正面向き、画布の中央に配置し、上下左右に均等な余白。
画風はデフォルメされたSD、頭身は2頭身相当。
輪郭線は太く均一で、色は髪色よりはっきり暗い色（黒は使わない）。
塗りは面で塗り、影は2階調まで。強いグラデーションと光沢は入れない。
装飾品・小物・文字は入れない。
顎から下は髪と透過のみにする。首・肩・服は描かない。
髪の毛先は顎の高さより下に伸ばさない。
20ピクセルに縮小しても形が判別できることを最優先にする。

髪: ピンクのツインテール、前髪ぱっつん
表情: にっこり笑って目を閉じている
```

## What we learned

**Leave the framing instruction alone.** Changing it to "the face should fill about 60%
of the canvas" and "hair may run off the edges" did enlarge the face — and also thinned
the outline toward black and pulled the whole thing from sticker art to ordinary anime
illustration. At 20 pixels the eyes collapse into a dark smudge. Touch the composition
and the style moves with it.

**Control hair length through the hairstyle, not the framing.** With the framing fixed,
longer hair stretches the bounding box downward and the face shrinks to compensate. So
the tips stop at the chin. Long hair and high ponytails do give silhouettes something to
differ by, but not when they cost the face.

**Negative instructions are weak.** "Do not draw below the neck" alone still produced a
visible neck. Adding the positive form — "below the chin, only hair and transparency" —
made it hold.

**Outline value decides everything at small sizes.** Too little contrast against the hair
and the face reads as a blob. Silver failed this way: a pale grey outline sinks into a
dark menu bar and washes out against a bright wallpaper.

**Draw the eyes large.** The larger the eyes relative to the face, the more of the
expression survives the trip down to 20 pixels.

## The eight

Hue and silhouette both vary, because at 20 pixels there are moments when colour is all
you have to go on.

| Hair | Style | Expression |
| --- | --- | --- |
| Pink | Twintails, blunt bangs | Smiling with eyes closed |
| Blue | Bob, curled under | Wide-eyed and puzzled |
| Red | Semi-long, curled under | Laughing with an open mouth |
| Green | Two buns | Winking |
| Purple | Short braids on both sides | Sleepy, eyes half closed |
| Orange | Short, flicked ends | Smug little grin |
| Black | High twintails | Startled, mouth open |
| Silver | Long waves | Composed, mouth closed |

Silver's outline is too weak; it is the one worth redrawing.

## Installing

Generated PNGs carry transparent margins, so square them first.

```bash
swift Tools/square.swift <generated.png> ~/Library/Application\ Support/Okigae/Faces/<name>.png
```

`Tools/square.swift` finds the bounding box of the opaque pixels and centres it on a
square canvas. Whatever you name the file in `Faces` becomes the choice in the menu and
the value in `assignments.json`.
