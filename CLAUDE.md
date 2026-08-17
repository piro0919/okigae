# Okigae

Replaces the icons in the macOS menu bar with characters of your choosing. Nothing is
actually replaced — a panel is laid over each item, and the real item stays alive
underneath, so clicking still opens its own menu.

macOS 14+. No Xcode: `./build.sh` compiles with the Swift from the Command Line Tools.

## Shape of the thing

| file | what it does |
|---|---|
| `Sources/StatusItems.swift` | Finds menu bar items and works out a stable key for each |
| `Sources/Backdrop.swift` | Captures what sits behind an item |
| `Sources/BarShape.swift` | Measures how tall the bar actually is, for apps that reshape it |
| `Sources/OverlayPanel.swift` | One panel per item: backdrop underneath, character on top |
| `Sources/Assignments.swift` | `assignments.json`, the bundled characters, first-run copy |
| `Sources/SettingsWindow.swift` | Grid of items, grid of characters, click one then the other |
| `Sources/Updater.swift` | Sparkle. Checks once at launch, speaks only when there's an update |
| `lp/` | The landing page. Next.js, English and Japanese, `pnpm lp:dev` and `pnpm lp:build` |
| `Tools/add-character.sh` | Takes one generated PNG all the way in: squared, named, on the page |

## Key decisions

- **Overlay, not replacement.** `NSStatusItem` belongs to the process that made it and there
  is no public API to reach into another app's. Everything else follows from that.
- **The backdrop is captured from below the item.** On a transparent menu bar that yields the
  wallpaper; with **Reduce transparency** on it yields the flat colour. Capturing the real
  thing means no branch for either. Capturing *below our own panel* instead pulls the item
  itself into the backdrop — that mistake cost an hour, twice.
- **`CGWindowListCreateImage` is reached through `dlsym`.** It no longer compiles on macOS 15
  and ScreenCaptureKit has no equivalent for this. Ice worked around it with a protocol whose
  initialiser matched; current Swift rejects that. The symbol is still there.
- **Screen recording permission is not optional.** Not for the backdrop — for identification.
  Without it window titles come back empty and nothing can be told apart.
- **Keys are `title#ordinal`.** Window IDs change on every restart. A bundle identifier alone
  cannot separate several items owned by one app — Doll shows one per app it watches. The
  ordinal follows window ID order, which is the order the app created its items in; verified
  by restarting Doll and watching Discord/Slack/Linear keep their positions.
- **A display's own title wins.** Titles differ per display: a position carrying a bundle
  identifier on one screen may be `Item-0` on another. Borrowing across displays by
  right-edge order breaks as soon as the two lists differ in length, and quietly hands an
  item somebody else's name. Borrow only when the item's own title is empty or generic.
- **Deduplicate by position, keeping the better title.** Some apps keep two windows per item
  and swap which one is on screen every few seconds. Keying panels by window ID made them
  rebuild on every swap, which is what the flicker was. Keeping the front-most window lost
  names, because the front one is sometimes the untitled twin.
- **The bar's height is measured, not assumed, and measured per display.** Ice and friends
  draw a rounded bar that sits a few points inside the real one, so a panel covering the
  item's full rect cuts a notch out of it. `BarShape` reads a column at each item's left
  edge — the padding before the icon starts — counts the rows that differ from the middle,
  and takes the median so a column landing on artwork cannot decide the answer. Nothing
  overlaid means no difference means zero.
  Reading a column *between* two items does not work: Ice packs them so the rects touch, no
  gap of two points ever exists, and the measurement silently returned zero for everything.
  The inset differs per display — 4 points on the built-in screen against 1 on an external
  one — so a single global value notches one screen while fitting the other.
- **The same item carries a different key on each display, so keys have aliases.** One
  screen calls Doll's items `com.xiaogd.Doll#0`, the other `Doll_com.hnc.Discord#0`, and
  which screen gets the richer name flips between launches. Rather than canonicalise — that
  would strand assignments already written to disk — each item carries the keys its twins
  use elsewhere. Lookups try them in turn; assigning writes the same value to all of them.
  Pairing is by position from the right edge, because the clock and the battery are pinned
  there and new items pile up on the left. Widths are the evidence that the pairing is real:
  pair only while the widths agree, counting from the right, and stop at the first
  disagreement. Requiring the *whole* sequence to match looks safer and is useless — Okigae's
  own item shows on one display and not the other often enough that every alias silently
  vanishes, which reads as "some faces don't appear on the other screen".
- **A character's file name is its identity.** It is the value in `assignments.json`, and
  it is what the settings window shows — for artwork the user dropped in as much as for the
  bundled eight. So naming a character means renaming a file, which reaches into folders
  already out in the world. `Assignments` renames the artwork and repairs `assignments.json`
  on load, and the rename must run before the bundled copies are installed; the other order
  leaves both names in the grid. The kana readings are a display layer over the file names,
  and only the bundled eight have one.
- **Names avoid colours.** They were `pink` and `blue` once. Two characters will eventually
  share a colour, and a recoloured variant of an existing character has nowhere to go.
- **Development builds are signed with a self-signed certificate.** Ad-hoc signing changes on
  every build, so macOS treats each build as a new app and drops the screen recording grant.
  `./Tools/make-cert.sh` once, and the grant survives. Releases go out ad-hoc signed like the
  other apps here, which is what `release.sh` does.

## Things that bit

- Replacing a string in a file that no longer contains it fails silently. Two fixes were
  written, neither applied, and the symptoms were blamed on macOS both times. Check the
  file after patching it.
- `NSPanel` hides itself when the app deactivates. A menu bar app never activates, so the
  overlays never appeared until `hidesOnDeactivate = false`.
- An `.accessory` app cannot bring a window forward. Switch to `.regular` while the settings
  window is open, switch back when it closes, and activate on the next runloop pass.
- A window opened by a menu bar app lands in whatever Space it was created in.
  `.moveToActiveSpace` brings it to the one the user is looking at.
- Sparkle ships Japanese but shows English unless `CFBundleDevelopmentRegion` and
  `CFBundleLocalizations` are declared.
- **Sparkle overwrites the build you are testing.** `build.sh` stamps `0.0.0` unless
  `OKIGAE_VERSION` says otherwise, so the check at launch finds the released version, and
  minutes later `Okigae.app` is the ad-hoc signed release again — screen recording grant
  gone, no overlays, and the certificate you just signed with nowhere in sight. It looks
  exactly like a bug in the code you were editing. Build with `OKIGAE_VERSION=99.0.0
  ./build.sh` while working, and check `codesign -dv` before believing what you see.

## Gather what you can before asking

Every request costs the other person a turn. If two requests have not resolved something, find
a way to read it directly before asking a third time.

- `Tools/probe/` samples the resolved status items 20 times and prints every distinct reading,
  which is how to tell a wrong key from an unstable one. It is not wired into `build.sh`;
  compile it against the sources:

  ```bash
  swiftc -target arm64-apple-macos14.0 -framework AppKit \
    Sources/StatusItems.swift Tools/probe/main.swift -o /tmp/okigae-probe && /tmp/okigae-probe
  ```

- `screencapture -x -R<x,y,w,h> /tmp/bar.png` reads the menu bar back without asking anyone to
  describe it. Overlay alignment is a pixel question and should be settled from a picture.

The sources emit no log lines at all, so there is nothing to read with `log show`. Add a
`Logger` before reaching for one.

## Where things live

- Settings and characters: `~/Library/Application Support/Okigae/`
- Sparkle's private key: login keychain, shared with the other apps here. One key covers
  any number of apps; losing it means never updating what is already out there.

## Open

- Items that only ever report `Item-0` cannot be identified, so they are left out.
- An item's width becomes the character's size, so narrow items get small faces.
