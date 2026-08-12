# Okigae

A macOS menu bar app that replaces the icons up there with artwork of your choosing.

Nothing is actually replaced. macOS gives no way to do that — a menu bar item is an
`NSStatusItem` owned by the process that created it, and there is no public API for
reaching into another app's. So Okigae lays a panel over each item instead. The real
item is still alive underneath: click it and its own menu opens, exactly as before.
Only the apps you assign artwork to change; everything else stays as it was.

Requires macOS 14 or later. Xcode is not needed — the Swift that ships with the
Command Line Tools is enough.

## How it works

- The overlay is a transparent panel at `.statusBar` level that ignores mouse events,
  so clicks pass through to the real item below.
- Its background is a capture of whatever is actually drawn behind that item. On a
  transparent menu bar that is the wallpaper; with **Reduce transparency** on it is a
  flat colour. Because the capture is of the real thing, no branch is needed for either.
- Item positions come from the window list. Each display gets its own panels, and they
  follow as items move, appear, or vanish.

## Permission

**Screen recording access is required.** Not only to capture the backdrop, but to
identify the items at all: without it, window titles come back empty and there is no
way to tell which item belongs to which app.

## Assignments

Settings live in `~/Library/Application Support/Okigae/assignments.json`, artwork in
`Faces/<name>.png` beside it. The menu bar item writes the same file when you pick from it.

The key is the item's window title plus an ordinal.

```json
{
  "io.kkweb.konechi#0": "pink",
  "Doll_com.hnc.Discord#0": "orange",
  "Battery#0": "blue"
}
```

Window IDs change on every restart, so they cannot be the key. A bundle identifier
alone cannot separate several items owned by one app — Doll, for instance, shows one
per app it watches. Hence the ordinal, assigned in window ID order, which is the order
the app created its items in.

Displays disagree about titles. A position that carries a bundle identifier on one
screen may be empty or a bare `Item-0` on another. Order from the right edge and item
widths do match across displays, so the lists are lined up and the more specific title wins.

## Build

```bash
./Tools/make-cert.sh   # once — creates a self-signed certificate for development
./build.sh
```

Ad-hoc signing changes the signature on every build, which makes macOS treat each build
as a different app and drops the screen recording grant every time. A stable certificate
keeps it.

## Artwork

How it is generated, and what eight attempts taught us, is in [docs/faces.md](docs/faces.md).

Generated PNGs carry transparent margins, so square them before dropping them in:

```bash
swift Tools/square.swift <generated.png> ~/Library/Application\ Support/Okigae/Faces/<name>.png
```

## Known limits

- `CGWindowListCreateImage` no longer compiles on macOS 15 and is reached through
  `dlsym`. The symbol is still there, but Apple may remove it.
- On a display that only ever reports `Item-0`, used on its own, items cannot be identified.
- An item's width becomes the artwork's size, so narrow items get small faces.
