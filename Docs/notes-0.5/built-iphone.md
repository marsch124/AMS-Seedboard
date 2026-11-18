# Built in 0.5 — lane `iphone` (the rest of pick 31)

Branch `wt-iphone`. Source: `panel-apple-platform.md`, finding 10, bullets 2 to 4 and its traps.
Everything below is for iPhone and iPad; on the Mac nothing looks or works differently
(only the link `seedboard://new/…` is understood there too).

**Not one of the three parts was seen running.** This lane may not use the simulator, and none of the three
exists on the Mac. Both platforms build, the rules are proven by data tests, and the plate has a screen test
that compiles. What must be looked at on a device is listed at the end.

---

## 1. Press the app icon long

A long press on Seedboard's icon (Home Screen, App Library, search) shows up to five lines of its own, in this order:

| Line | Small grey line under it | Mark | What it does |
|---|---|---|---|
| **New board** | none | the plus (as on the New board button) | a blank board called "New board", opened |
| **New mind map** | none | the mind-map mark | a fresh board from the Mind map starter, opened |
| **New board from the clipboard** | none | the paste mark | a board from the words on the clipboard, opened |
| *name of the first pinned board* | its count line as in the list (e.g. "12 ideas · 4 shapes · 2 notes"; "Empty" for an empty board) | the board with the sprout | opens that board |
| *name of the second pinned board* | its count line | the board with the sprout | opens that board |

- "First two pinned boards" = the first two of the Pinned part of the list, i.e. the two pinned boards changed last.
  A name of several lines is shown on one line. Nothing pinned: only the three "New" lines.
- The lines are told to the device when the boards have been read after a start and every time the app is left,
  so they follow what is pinned now. Before 0.5 has been opened once, the icon shows none of them
  (all five are set by the app itself; nothing was added to `project.yml`).
- **New mind map** takes HIS version of the Mind map starter if he changed it. If he removed that starter from the
  shelf, a blank board opens and the line at the bottom says
  **"That starter is not here any more. This is a blank board."**
- **New board from the clipboard** follows the rule of the Shortcuts action "New board from text": a list
  (two lines or more) becomes a mind map, anything else ONE sticky note; the board is named after the middle idea
  or the first line (40 letters at most). Words only — a picture on the clipboard is not taken.
  Nothing on the clipboard (or only blanks): a blank board and the line
  **"There were no words to paste. This is a blank board."**
- With made-up boards (`-sampleData`) only the three "New" lines are set, never a made-up board.

### The new links
- `seedboard://new/<starter id>` — a fresh board from that starter, opened. The id is a built-in's stored name
  (`blank`, `mindMap`, `flow`, `prosCons`, `steps`, `timeline`, `sequence`) or the id of one of his own starters.
  Capitals do not matter. `seedboard://new` and `seedboard://new/` mean a blank board.
- `seedboard://new/clipboard` — the board from the clipboard, as above.
- They work from anywhere a link works (Safari, a note, a Shortcut "Open URL"), on iPhone, iPad and Mac.
  A link that starts the app waits until the boards are read; the starters are read again before the board is made.
- Each use makes a NEW board (two boards never share a name: "Mind map", "Mind map 2" …, as everywhere).

### Marks
Four small template pictures in the app's pictures (`App/Resources/Assets.xcassets`): `QuickAdd`, `QuickMindMap`,
`QuickPaste`, `QuickBoard` — each the icon library's own drawing (`control-add`, `app-seedMindMap`, `app-seedPaste`,
`app-seedBoard`), 30 points in a 35-point square, black on clear, at 2x and 3x. The icon's menu can only show a
picture that is part of the app, so these are copies: if one of the four drawings is ever redrawn in the library,
the copy must be made again. No system symbols are used.

---

## 2. The camera on the Picture tool

- A **press** on the Picture tile opens Photos, exactly as before.
- **Holding** the tile for 0.4 s (the same as the Box tile) opens a small plate. The tile now carries the small
  filled corner that says "there is more" (7 points, bottom right, in the pictures' colour) like the Box tile;
  on the iPad a press on that corner opens the plate too, on the iPhone the corner only shows (too small for a finger).
- The plate: heading **"Add a picture"** with the picture mark in the pictures' colour, **Cancel** at the right;
  under it three tiles in one row, each 54 points high, the mark (26 points) with its word under it:
  **Photos** · **Take a photo** · **Scan a page**.
  iPhone: a low sheet, 150 points high, with the grip. iPad: a pop-up 320 points wide above the tile.
- **Photos**: the photo picker as before (up to 12 pictures).
- **Take a photo**: the device's camera over the whole screen. "Use Photo" puts the photo on the board, chosen,
  at a free place near the middle of the view — the same way a picture from Photos lands (long side 2048 pixels
  at most, upright). Cancel: nothing happens.
- **Scan a page**: the device's page scanner over the whole screen (it finds the paper or whiteboard, straightens
  it; several pages can be scanned in one go). "Save" puts every page on the board as a picture of its own, all
  chosen. At most 12 pages land; with more, the line at the bottom says
  **"A scan puts 12 pages on a board at most. The first 12 of 15 are here."** (with the real number; 6 seconds).
  If the scanner reports a failure: **"The scan did not work. Nothing was put on the board."** (brick red).
- A device without a camera (the simulator): **"This device has no camera."** (brick red).
- The first use of the camera asks once for permission, with the words already in `project.yml`:
  "To put a photo straight onto a board."
- Not on a timeline or a "Who does what" board (they have no Picture tile), not on a board that is only read
  ("A picture cannot be put on this board.").
- The Mac has no plate and no corner mark (its pictures from the iPhone belong to the `mac` lane).

---

## 3. Three-finger undo and shake to undo

- With a board open and nothing being typed: **three fingers swiped left** undo one step, **three fingers swiped
  right** redo one step, **three fingers tapped** show the device's own small bar (undo, cut, copy, paste, redo —
  only its undo and redo do something on a board), and a **shake** offers the device's "Undo" question.
- ONE undo path. The board's own steps (up to 120) stay the truth. The window's `UndoManager` never holds a copy
  of them: after every change it is given exactly one "undo" (when the board has a step to take back) and one
  "redo" (when it has one to do again), and each only calls the board's own undo / redo. The Undo and Redo
  buttons, ⌘Z and ⇧⌘Z with a keyboard and the Edit menu go straight to the board as before and never through
  the manager. So one press or one swipe takes back exactly one step, never two.
- While words are typed the device's gestures undo the typing (the field's own undo), as before; the board's
  steps are not offered then. A board that is only read offers nothing. Back at the list nothing is offered.
- The touch layer: the device's three-finger gestures are let through beside the board's own press (until now
  they had to wait for the press to fail, which it never does, so they could not work on a board). While a third
  finger is down, and for 0.3 s after it lifted, the two-finger slide and zoom REST (the two fingers left over at
  the end of a swipe must not shove the board); then two fingers slide again, without a jump.
  One and two fingers behave exactly as before.
- The Mac is untouched: its Edit menu still says "Undo" / "Redo".

---

## Rules and tests

New Core files: `QuickStart.swift` (`NewLink`, `QuickActions`, `PictureWay`), `SystemUndo.swift` (`SystemUndo`,
`Fingers.isDevicesGesture`, `ThirdFinger`). Rule tests: `Core/Tests/SeedboardCoreTests/Iphone05Tests.swift`, **10 tests**:
a new link is read and written the same way · it opens a fresh board from that starter · it takes his own version
and his own starters · a starter that is gone gives a blank board and says so · the clipboard link follows "New
board from text" · the icon's menu is three "New" lines and the first two pinned boards · the Picture tile's three
ways and 12 pages at most · the device's undo takes back exactly one step through the board's own undo (on a real
`UndoManager`, including the end of an event) · in the middle of the device's undo nothing is touched · three
fingers belong to the device, and the board rests while a third finger is down and 0.3 s after.

Screen test (written, compiles, NOT run): `UITests/IphoneUITests.swift`, one test — the plate shows its three
ways in order and Cancel closes it (iPhone and iPad; skipped on the Mac).

## Launch words
- `-plate picture` (with `-board <word>`, iPhone and iPad): opens the plate "Add a picture" at once.

## New identifiers
`plate.picture` · `plate.picture.photos` · `plate.picture.camera` · `plate.picture.scan` · `tool.pictureWays`
(the corner on the Picture tile) · the plate's Cancel is the shared `plate.cancel`.

## Marks
No new `NewMark` case. Used: `.picture`, `.camera`, `.scan` on the plate — `.camera` and `.scan` are still the
groundwork's stand-ins (a picture, a document), so until the lead swaps them "Photos" and "Take a photo" show the
same mark. The four pictures for the icon's menu are described above.

## Stored fields
None. Nothing is written into a board; nothing new in `UserDefaults`. The icon's menu lines are kept by the device.

## New files
`App/Sources/QuickActions.swift`, `App/Sources/PictureWays.swift`, `App/Sources/SystemUndoHost.swift`,
`Core/Sources/SeedboardCore/QuickStart.swift`, `Core/Sources/SeedboardCore/SystemUndo.swift`,
`Core/Tests/SeedboardCoreTests/Iphone05Tests.swift`, `UITests/IphoneUITests.swift`,
four picture sets `App/Resources/Assets.xcassets/Quick*.imageset`.

## Hunks in existing files (where the join may clash)
- `App/Sources/SeedboardApp.swift`: 4 lines after `@Environment(\.scenePhase)` (the app delegate, iPhone and iPad
  only) and 2 lines after `.modifier(OutsideDoors(model: model))` (`SystemUndoHost`).
- `App/Sources/AppModel.swift`: 2 lines at the top of `open(url:)`.
- `App/Sources/PictureViews.swift`: 2 lines at the top of the Picture tile's action, 2 lines after its identifier.
- `App/Sources/TouchLayer.swift`: 2 lines after `private var lastMid` (a new property), 2 lines at the end of
  `verdict(for:)`, 2 lines in `shouldRecognizeSimultaneouslyWith`, one changed line in `shouldBeRequiredToFailBy`,
  5 lines at the top of `step()`. The `motion` lane works near the two-finger slide: its hunks and these must both stay.
- `project.yml`, `Info.plist`, `Guide.swift`, `SPEC.md`: not touched.
- If another lane also adds an app delegate for iPhone and iPad, the two must become ONE class
  (`SeedAppDelegate` in `QuickActions.swift` is the place).

## NOT built
- The Mac's Edit menu saying "Undo Move" instead of "Undo" (the finding's side remark): the board's steps have no
  names, and naming them means touching every change in the app. The lane's text asks only for the gestures.
- Three fingers pinched (the device's copy and paste gesture) is not let through on a board: not asked for.
- A picture on the clipboard for "New board from the clipboard" (words only).
- Lines of the icon's menu that are there before the app was ever opened (they would need `project.yml`).

## NOT seen running — to look at on an iPhone and an iPad
1. The icon's menu: that the lines and their marks show, in order; each line does its work both when the app is
   already running and when the line starts it.
   - iPhones show only a few lines of an app's own (four, on every iPhone I know of). With five lines the
     **second pinned board is then not shown**. To decide (see below).
   - "New board from the clipboard" reads the clipboard by itself, so iOS asks "Allow Paste?" each time unless
     Settings ▸ Seedboard ▸ Paste from Other Apps is set to Allow. Words copied inside Seedboard are not asked about.
   - A window the device kept from 0.4 was set up without this lane's window delegate. For that case the window's
     existing delegate is given the one missing method when the window becomes active (`SeedSceneDelegate.teach`,
     nothing is replaced). If a line pressed while the app is running ever does nothing, this is the place to look;
     swiping the app away once in the app switcher gives the window its new set-up for good.
2. The camera and the scanner: that both open over the whole screen, the photo and the pages land upright,
   and that the press which opens the plate does not also open Photos when the finger lifts.
3. The three-finger swipe, the three-finger tap and the shake on a board, on iPhone and iPad; that two-finger
   sliding and zooming feel as before; that a third finger put down by mistake while sliding only rests the board
   (it slides again 0.3 s after that finger is gone); that the board does not twitch at the end of a three-finger swipe.
   The device's three-finger recognisers are recognised by what they are (a pan, tap, swipe or long press that
   needs three fingers or more), not by a private name; if Apple builds them another way the swipe will not reach
   the board — `TouchSurface.isDevicesOwn` in `SystemUndoHost.swift` is the one place to change.

## To decide (lead / Martin)
- Five lines or four? As built the order is the brief's (three "New" lines, then two pinned boards), so on an
  iPhone the second pinned board is the one that falls off. Leaving out "New mind map" would show both pinned
  boards. One line to change: `QuickActions.list` in `QuickStart.swift` (and its test).

## Drive-by things seen and left
- `PictureHost.ask` and `BoardSession.lay` say "A picture cannot be put on this board." in the plain (green) tone;
  it is a problem line (the `feel` lane goes through every `say(`).
- `UIImagePickerController` is Apple's old camera page; it still works and needs nothing else. A camera page of
  the app's own look would be a piece of work of its own.
