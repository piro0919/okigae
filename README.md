# Okigae

A macOS menu bar app that replaces the icons up there with artwork of your choosing.

Nothing is actually replaced. macOS gives no way to do that — a menu bar item is an
`NSStatusItem` owned by the process that created it, and there is no public API for
reaching into another app's. So Okigae lays a panel over each item instead. The real
item is still alive underneath: click it and its own menu opens, exactly as before.
Only the apps you assign artwork to change; everything else stays as it was.

Requires macOS 14 or later. Xcode is not needed — the Swift that ships with the
Command Line Tools is enough.

## Install

Grab the DMG from [Releases](https://github.com/piro0919/okigae/releases) and drag Okigae
into Applications. The app is signed ad-hoc rather than notarised, so the first launch needs
a right-click and **Open**. Updates after that arrive through Sparkle — Okigae looks once at
launch and only says something when there is an update.

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
`Characters/<name>.png` beside it. The menu bar item writes the same file when you pick from it.

The key is the item's window title plus an ordinal.

```json
{
  "io.kkweb.konechi#0": "momoka",
  "Doll_com.hnc.Discord#0": "hinata",
  "Battery#0": "ruri"
}
```

Window IDs change on every restart, so they cannot be the key. A bundle identifier
alone cannot separate several items owned by one app — Doll, for instance, shows one
per app it watches. Hence the ordinal, assigned in window ID order, which is the order
the app created its items in.

Displays disagree about titles. A position that carries a bundle identifier on one
screen may be empty, a bare `Item-0`, or a different name entirely on another — and which
screen carries which name changes between launches. Item order and widths from the right
edge do match, so the lists are lined up that way: the more specific title wins, and each
item also remembers the keys its twins use on the other screens. Assign a face on one
display and it appears on all of them.

## Build

```bash
./Tools/make-cert.sh   # once — creates a self-signed certificate for development
./build.sh
./Okigae.app/Contents/MacOS/Okigae --selftest   # assignment lookup, no windows opened
```

Ad-hoc signing changes the signature on every build, which makes macOS treat each build
as a different app and drops the screen recording grant every time. A stable certificate
keeps it.

## Characters

Ten come with the app: momoka, ruri, konoha, hinata, akane, sumire, kuroha, yuki, himari
and mio.
The file name is the name — it is what the settings window shows and what
`assignments.json` stores — so anything you drop into the folder is named by whatever you
call the file. The bundled ones also carry a kana reading for the settings window;
`Sources/Assignments.swift` holds both tables.

They used to be named after their hair colour. Anything still assigned to `pink` and the
rest is renamed on the next launch, artwork and `assignments.json` together.

How they are generated, and what the first eight attempts taught us, is in
[docs/characters.md](docs/characters.md).

To take one in, prompt to artwork in one step:

```bash
./Tools/add-character.sh ~/Downloads/generated.png himari ひまり
```

It squares the artwork, files it under `Resources/Characters/`, adds the reading, adds it
to the landing page in both languages, and writes `docs/preview-<name>.png` — the face at
its real menu bar size over a dark bar and a light wallpaper, which is where a pale
outline gives itself away.

## Releasing

```bash
./release.sh 0.1.0
```

Builds the app ad-hoc signed, packs a DMG and an update zip, signs the appcast with the key
in the login keychain, and pushes all three to GitHub Releases. Losing that private key means
losing the ability to update copies already out there.

## Known limits

- `CGWindowListCreateImage` no longer compiles on macOS 15 and is reached through
  `dlsym`. The symbol is still there, but Apple may remove it.
- An item that answers `Item-0` on every display cannot be identified. Every status item
  window belongs to Control Center, so there is nothing behind the title to fall back on.
  Such items appear in the settings window dimmed, and cannot be assigned.
- An item's width caps the artwork, since item rects tile the bar with nothing between them.
  Raising the size setting grows the artwork sideways over its neighbours, up to the height
  of the bar.

## License

MIT
