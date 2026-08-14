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
- **The bar's height is measured, not assumed.** Ice and friends draw a rounded bar that sits
  a few points inside the real one, so a panel covering the item's full rect cuts a notch out
  of it. `BarShape` reads one column between two items and counts the rows that differ from
  the middle. Nothing overlaid means no difference means zero.
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

- The silver character's outline is too pale to read at menu bar size; worth redrawing.
- Bundled characters are named after their colour. They could have real names.
- Items that only ever report `Item-0` cannot be identified, so they are left out.
- An item's width becomes the character's size, so narrow items get small faces.
