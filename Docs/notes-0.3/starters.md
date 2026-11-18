# Starter boards (0.3) - what you can now do

## In plain words
- Save any board as your own starter. It then sits beside the seven built-in ones wherever starters are shown (home page, the New board choice, File > New Board).
- Rename, reorder, change and remove ALL starters, the seven built-in ones too.

## Save a board as a starter
- Where: the board's More menu ("Save as a starter…"), the Mac's File menu ("Save as a Starter…"), and the board list's right-click / press-and-hold menu ("Save as a starter…").
- A small page asks for the name (the board's title is filled in) with Cancel and Save. A name already taken becomes "Name 2".
- Afterwards the short message: Saved as the starter “Name”.
- Not offered for a board made by a newer Seedboard (read-only).
- A new board from your starter is a fresh copy: new identity, not pinned, not marked as sent to PARAGON, named like the starter. A timeline starter moves by whole days, so the plan sits as far from today as it did when you saved it.

## The Starters page
- Opened by the small "Edit" button beside the STARTERS heading on the home page, the "Edit" button in the New board choice, the Mac's File > "Starters…", and "Edit starters…" in a starter card's right-click / press-and-hold menu.
- Every starter in order, each row with its picture, name and grey line. Drag to reorder (iPhone and iPad show handles).
- Each row's "Edit" menu: Rename… (name and grey line, Cancel and Save), Change…, Remove… and, for a changed built-in, "Back to the original".
- Remove asks first: Remove the starter “Name”? The Blank board has no Remove (a new board must always be possible). A removed own starter is kept 30 days, then its file goes.
- At the bottom, only when a built-in is missing: "Bring back the built-in starters".
- Done closes the page (Escape on the Mac).
- A right-click / press-and-hold on any starter card offers Rename…, Change…, Remove… and "Edit starters…".

## Changing a starter
- Its board opens in the ordinary board screen as a working copy, with a bar at the top: Changing the starter “Name”, with Cancel and Save (Save in full colour).
- Nothing is stored until Save. Cancel after changes asks "Discard the changes?" (Discard / Keep changing).
- In this mode the toolbar has no Send to PARAGON, Pin, Remove or Save as a starter; Rename renames the starter.
- A built-in changed this way keeps its new board; "Back to the original" returns it.
- Going to another board while changing leaves the change unsaved (no question is asked).

## Where starters are kept
- One small file per starter that was ever changed or made: Starters/<id>.seedstarter, on the device and in iCloud Documents beside Boards. The newer copy wins. A removal keeps its file so it reaches every device.
- Read again when the app comes to the front and when the Starters page opens.
- Shortcuts / Siri still offer the seven built-in starters as they were.

# For the lead

## Files
- New: `Core/Sources/SeedboardCore/StarterShelf.swift`, `Core/Tests/SeedboardCoreTests/StarterShelfTests.swift` (15 tests), `App/Sources/StarterStore.swift`, `StarterModel.swift` (AppModel extension), `StartersPage.swift` (page, questions, banner, host, card menu), `UITests/StartersUITests.swift` (not run).
- Edited, small: `AppModel.swift` (5 stored properties + store, `present(draft:)`, `closeDraft()`, `open()` ends a change, `leaving()` flushes starters, loads starters at start), `BoardSession.swift` (`var starterDraft`), `BoardThumb.swift` (`init(starter: ShelfStarter)`), `BoardView.swift` (banner line, title, rename, More menu items, Send hidden in change mode), `HomeView.swift` (STARTERS heading + Edit, cards from the shelf, StarterCard/StarterPicker now take `ShelfStarter`), `RootView.swift` (picker calls, list context menu), `Menus.swift` (File lines, StarterSheet), `SeedboardApp.swift` (`.modifier(StarterHost())`).
- Not touched: Intents, Guide, SPEC, README, versions, Board.swift, Canvas*, Timeline*, Sequence*, PictureViews, tool row.

## Identifiers
home.startersEdit, home.starter.<id>, starter.<id> (picker), starters.edit (picker Edit), starters.page, starters.list, starters.done, starters.row.<id>, starters.more.<id>, starters.rename.<id>, starters.change.<id>, starters.original.<id>, starters.remove.<id>, starters.removeConfirm, starters.bringBack, starterName.sheet / .field / .hint / .cancel / .save, starter.change.banner / .cancel / .save / .discard. `<id>` is the raw value ("mindMap") or a UUID string; sample mode's two own starters are 00000000-0000-0000-0000-0000000000A1 (Weekly review) and ...A2 (Trip plan).

## Launch words (with -sampleData)
`-starters` (existing), `-starterPage`, `-starterChange <id or name>` (e.g. `-starterChange mindMap` or `-starterChange "Trip plan"`).

## Stand-in marks
Starters page header uses `.app(.seedStarter)`; "Bring back" uses `.new(.bringBack)`. The "Edit" buttons are text only (no mark fits). Menu lines are text only, as the existing menus are.

## Not proven
- No screens were run or looked at (no simulator, no app launch): layout of the page, the banner on iPhone, the Edit menu inside an editing List, drag reorder, and the dialogs are compiled, not seen. Day/night not checked.
- Real iCloud sync and conflict versions of starter files untested (sample mode and tests use memory only).
- Pictures laid on a board are referenced by file name; a starter made from a board with pictures shares those files.
- Leaving a change by opening another board discards it silently.
- Thumbnails of timeline own starters draw the plan at its saved days.
