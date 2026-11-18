# AMS Seedboard — specification, version 0.1

Written from the code as it stands for 0.1 (build 1), as of 2026-11-18. Where the code does something other than the owner's feature list, this document says what the code does and marks it **Note**.

## 1. What the app is

AMS Seedboard is a thinking tool for iPhone, iPad and Mac (one target, iOS 17 and macOS 14 and later, bundle id `com.schabbauer.AMSSeedboard`, team `D24ENP83QQ`, URL scheme `seedboard`, App Store category Productivity). Its purpose: start a thought on an endless board (mind map, flow with shapes and arrows, sticky notes), grow it, and hand it to PARAGON (the owner's notes app) as a note, a project or Inbox tasks.

Layout of the repository:

- `Core/` — Swift package `SeedboardCore`: every rule, no screen. Files: `Board.swift` (data), `BoardEdit.swift` (add, link, move, copy, remove, hit-testing), `MindMap.swift` (tree rules, sides and layout), `Room.swift` (a growing map pushes things aside), `Shapes.swift` (a shape's size from its words, changing its kind), `Viewport.swift` (where the board stands on screen), `Typing.swift` (the line-break rule for ideas), `Outline.swift` (lists in and out), `Route.swift` (arrow routing), `Starters.swift` (the five starts), `Paragon.swift` (the hand-over text). Tests in `Core/Tests/SeedboardCoreTests`.
- `App/Sources/` — the screens: `SeedboardApp`, `RootView`, `BoardView`, `CanvasView`, `CanvasDraw`, `BoardSession`, `AppModel`, `BoardStore`, `ParagonGate`, `SendSheet`, `SettingsView`, `Guide`, `Sample`, `BoardPicture`, `Theme`.
- `UITests/SeedboardUITests.swift` — screen tests (find controls by identifier).
- `project.yml` — XcodeGen spec. Version lives only there (`MARKETING_VERSION` 0.1, `CURRENT_PROJECT_VERSION` 1). Icons come from the AMS-Icons package, pinned to one revision.
- Apple facts: bundle id `com.schabbauer.AMSSeedboard`; App Store Connect app id `6836228189`; iCloud containers `iCloud.com.schabbauer.AMSSeedboard` (the boards) and `iCloud.com.schabbauer.AMSPara` (PARAGON's notes, add-only); PARAGON's shared waiting list is the app group `group.com.schabbauer.amspara` (iPhone and iPad) and `D24ENP83QQ.group.com.schabbauer.amspara` (Mac; own file `App/Config/AMSSeedboard-macOS.entitlements`, hardened runtime on).
- Build: `xcodegen generate`, then open `AMSSeedboard.xcodeproj`. Rules tests: `swift test --package-path Core`. Release: `Tools/release.sh <build> both` (or `ios` / `mac`).

## 2. Screens and controls

All identifiers below are accessibility identifiers.

### 2.1 Window

- One window, no New Window command. Mac default size 1100 x 760, minimum 640 x 480. Split view: boards list on the left (width min 200, ideal 226, max 320), open board on the right. On iPhone (compact width) the list comes first and a board opens over it; opening or closing a board switches the column.
- Nothing open: `board.none` with a seed-sprout mark, "Start a thought" (no boards at all) or "Choose a board", the line "Every idea starts on a board." and the button `empty.newBoard` ("New board", blank).
- Settings: on the Mac its own window (520 x 460), opened from the app menu (Settings…), ⌘, or the `boards.settings` link at the bottom of the list (a `SettingsLink`); with `-settings` it is opened by a message to the app. On iPhone and iPad it is a page (sheet) with Done.
- Opening `seedboard://board/<UUID>` opens that board; for an unknown board the flash line "That board is not on this device yet." shows.

### 2.2 Boards list (`boards.list`)

- Top: `boards.new` (full-colour green button "New board") opens "Start with" with five rows (on regular width a small popover under the button, 300 wide; on compact width, the iPhone, a sheet coming up from the bottom, because a popover there comes out empty): `starter.blank`, `starter.mindMap`, `starter.flow`, `starter.prosCons`, `starter.steps` (name, one-line hint, a small mark). Choosing one makes the board, saves it and opens it.
- Groups, shown only when not empty, in this order: Pinned (`pinned == true`), Recent (not pinned, `sent == nil`), Sent to PARAGON (not pinned, `sent != nil`). A pinned board that was sent stays in Pinned. The list is sorted by `changed`, newest first, when loaded, when iCloud brings news, and at every kept change (so the open board moves to the top as it is changed). A newly made or copied board goes to the top.
- Row `boards.row.<title>`: dot in the board's colour, title (one line), `countLine`. Chosen row: white text on green. A tiny dot (6 points, amber; white on the chosen row) at the row's end, `notInCloudDot` (spoken "Not in iCloud yet"), shows while the board's newest change is on this device but not in iCloud yet (6, rule 11); it is never shown when iCloud is off or with `-sampleData`. Context menu (right-click, or press and hold): Rename… (alert "Name of the board", Cancel, Save), Pin to the top / Unpin, Make a copy, Colour (Green, Pink, Orange, Blue, Teal, Purple), Open in PARAGON (only when `sent != nil`), Remove… (confirmation "Remove “<title>”?", button "Remove the board", message "It is kept for 30 days in the Removed folder.").
- Empty list text: "No boards yet. Press New board."
- Bottom: `boards.settings` (Settings) and `boards.version` ("0.1 (1)").
- `countLine`: parts "N idea(s)", "N shape(s)", "N note(s)" joined with " · "; "Empty" when none. Shapes are box, round, diamond, oval. Text and frames are not counted.

Rules of the list (AppModel):

- New board: `Starter.board()`, colour = `Palette.boards[count % 6]`. The title is the starter's name; if a title (case-insensitive) is taken it becomes "<name> 2", "<name> 3"… A blank board ("New board") is not numbered.
- Make a copy: new id, title + " copy", then " copy 2", " copy 3"… while a title (case-insensitive) is taken, `created` and `changed` now, `pinned = false`, `sent = nil`, `sentTodos = []`; if the board is open, its live state is copied. It opens.
- Remove: the open session is dropped, the pending save cancelled, the board leaves the list, a removal mark is left and both copies move to Removed (see 6), flash "Board removed. It is kept for 30 days in the Removed folder."
- Rename: trimmed; empty is refused. A change to a board that is not open is written at once. A board from a newer format cannot be renamed, pinned or coloured (refused), and a copy of one is shown but never written (see 6).
- Saving: every change of the open board is shown in the list at once and written 0.5 s later (also when another board is opened, and on `saveNow`). Words are handed over as they are typed, not only when the typing ends. When the app is left (scene no longer active) or closed (Mac: will-terminate), `AppModel.leaving` finishes the typing (`commitEdit`), saves at once and waits until the DEVICE copy is written (`flush`, 2 s at most). iCloud's copy follows by itself: on iPhone and iPad the app asks iOS for background time (`beginBackgroundTask` "Seedboard saves", ended when iCloud's step is done or the time is up); on the Mac, when the app closes for good, it waits up to 2 s more for iCloud's copy.
- A board that another device removed leaves this list too; if it was open, its typing is finished first: when the board was changed after the removal it stays, is saved again and comes back on every device (6, rule 5); otherwise it closes. A board removed here is not put back by a late save.
- News that iCloud brings for the open board while the owner is typing or dragging in it is HELD (not shown, not thrown away, not marked as seen) and offered again the moment the typing ends: without a change of his own the other device's version is shown; with a change his is the newer one and stays, the other version goes to `SafetyCopies` at the save that follows, and a flash says "Another device changed this board while you were typing. Its version is kept as a safety copy." Opening another board also ends the typing and offers the held news.
- A link `seedboard://board/<id>` (5.3) that arrives before the boards are loaded (the app was started by it) is held and followed once loading has finished. A board that is not on the device: if it has a removal mark the flash says "This board was removed on <d MMM yyyy>." and `AppModel.removedLink` holds its id and day (the place for a later "Bring back" button; `AppModel.bringBack(id)` brings the newest copy in Removed back under the same identity, on every device, and opens it); otherwise "That board is not on this device yet. It opens when it arrives." and the board opens by itself if iCloud brings it before another board is opened.
- Colour name of a board is one of `Palette.boards`: green, pink, orange, blue, teal, purple.

### 2.3 Board screen

Top bar (`primaryAction`): `board.undo` ("Undo", disabled when no step) and `board.redo` ("Redo") on regular width only (on compact width, the iPhone, they are the `UndoCluster` at the bottom left above the tools, same identifiers, greyed when there is no step), `board.more` (menu "More"), `board.send` (full-colour green; "Send to PARAGON", "Send" on compact width). Title = board title (inline on iOS).

More menu: Rename… (alert, text field `rename.field`), Pin to the top / Unpin, Paste a list as a mind map (clipboard text; flash "Nothing to paste." if none), Copy the board as text (flash "The board's words are copied."), Share a picture… (share sheet, PNG named "<title>.png", the same picture as for PARAGON), Remove the board… (same confirmation as the list).

Canvas `board.canvas`: accessibility label "Board", value = `countLine`. Empty board shows `board.empty`: "An empty board" / "Press a tool below to start, or paste a list to get a mind map."

Banners above the tools: read-only banner (a board from a newer format, which is shown and can be looked at but not changed: "This board was made by a newer Seedboard. Update the app to change it."); arrow-tool banner ("Press the first shape, then the second." / "Now press the shape the arrow goes to.") with `board.linkCancel`; otherwise the selection bar `board.selectionBar`. A flash line `board.flash` (green capsule, 4 s) shows short messages.

Tool bar `board.tools` (its own accessibility element with the buttons inside; scrolls sideways when too narrow): seven tools, each 40 x 40:

| Identifier | Help text | Action |
| --- | --- | --- |
| `tool.mindmap` | Mind map (M) | add a mind-map centre |
| `tool.box` | Box (B) | add a box |
| `tool.diamond` | Diamond (D) | add a diamond |
| `tool.arrow` | Arrow between two shapes (A) | toggles the arrow tool; with one non-frame item chosen the arrow starts there |
| `tool.note` | Sticky note (N) | add a note |
| `tool.text` | Text (T) | add free text |
| `tool.frame` | Frame (F) | add a frame |

A new thing goes to the middle of the visible board, moved down-right by 34 points up to 14 times while its box (grown by 6) touches another non-frame, visible item (a frame is tested as 10 x 10). It is chosen and typing starts at once. Round box and oval have no tool; they are made by changing the kind of a chosen shape.

Zoom cluster (bottom right; on narrow widths a row above the tools, with the Undo cluster at its left on compact width): `zoom.out` ("Smaller", scale / 1.25), `zoom.value` (e.g. "100 %"), `zoom.in` ("Bigger", x 1.25), `zoom.fit` ("Show the whole board").

Selection bar (`board.selectionBar`, its own element with the buttons inside), shown while something is chosen and the board is not read-only. The chips are laid out by `WrapRow`: centred rows, and a second row when the width runs out (no scrolling). On iPhone and iPad every bar also has `sel.more` "Choose more" (before Remove; filled while on), which sets `choosingMore` so each press adds to or takes from the choice; Escape, pressing empty board or a new board clears it. On the Mac there is no such chip (Shift and the box do it).

- One idea: `sel.child` "Idea under"; `sel.sister` "Next idea" (not for a centre); `sel.fold` "Fold"/"Unfold" (only when it has ideas under it); `sel.sides` "Both sides"/"One side" (centre only) or `sel.colour` "Colour" (non-centre); `sel.todo` "To do"; `sel.copy` "Copy"; `sel.words` "Words"; `sel.remove` "Remove".
- One shape: four buttons `sel.shape.box`, `sel.shape.round`, `sel.shape.diamond`, `sel.shape.oval`; `sel.colour`; `sel.todo`; `sel.copy`; `sel.words`; `sel.remove`.
- One sticky note: `sel.colour`, `sel.todo`, `sel.copy`, `sel.words`, `sel.remove`.
- One text: `sel.todo`, `sel.copy`, `sel.words`, `sel.remove`.
- One frame: `sel.colour`, `sel.copy`, `sel.words`, `sel.remove` (no To do).
- One arrow: `sel.words`; `sel.style.elbow` "Right angles", `sel.style.straight` "Straight", `sel.style.curve` "Curved" (the current one is filled); `sel.turn` "Turn round"; `sel.colour`; `sel.remove`.
- Several things: text "N chosen", `sel.todo`, `sel.copy`, `sel.remove`.
- The colour row `board.colours` (its own element with the dots inside): dots `colour.<name>`; shapes and arrows also have `colour.none` first. Sticky notes offer `Palette.notes` (yellow, pink, blue, green, orange, purple), everything else `Palette.names` (pink, orange, teal, blue, purple, green, yellow, red, grey). The row closes when the choice changes.
- Setting a colour on a mind-map idea sets the colour of its main branch (nothing for a centre).

Typing field `board.field`: sits over the item (or over the label of an arrow). On iPhone and iPad a keyboard toolbar (`.keyboard` placement) holds a "Done" button `board.fieldDone` that keeps the words. Behaviour in 3.8. The count line is also a 1 x 1 clear element `board.count` (the screen tests wait for it).

### 2.4 Send page (`SendSheet`)

Title "Send to PARAGON". Rows `send.kind.note` ("As a note"), `send.kind.project` ("As a project"), `send.kind.todos` ("Only the to-do boxes") with explaining lines. Field `send.title` (name; note and project only; starts as `noteTitle(for: board.title)`). A line says how many to-do boxes become tasks. When the board was sent before: "Last sent <yyyy-MM-dd HH:mm> as a <kind>: “<title>”" and `send.openLast` ("Open in PARAGON"). Fixed line: "Seedboard only adds something new. It never changes a note you already have; sending again makes a second note." Errors in `send.problem` (red). Buttons `send.cancel` (Escape) and `send.send` (Return; label "Sending…" while busy; full-colour purple, paler when disabled).

Size: Mac 470 wide, as tall as its content. iPhone and iPad: the content (at most 560 wide) sits in a scroll view that only bounces when it does not fit; the only detent is large, so on the iPhone (and on an iPad in a narrow window) the page is full height and the title is never cut; on the iPad in a wide window the page is a card sized to its content (`presentationSizing(.form.fitted(horizontal: false, vertical: true))`, iOS 18 and later; on iOS 17 the system's own card size). When the page closes the board takes the keys back.

- If PARAGON is not found: `send.notReady` shows the line from Settings; Send is disabled.
- Send is enabled when PARAGON is found, not busy, and: for "Only the to-do boxes" at least one unsent to-do box with words AND an Inbox list reachable; for the others the board is not empty.
- On open the kind is "note", except when the board has no mind map, unsent to-do boxes exist and every item is a to-do box: then "to-do boxes".
- After success the page closes, the board is saved with `sent` and `sentTodos`, and a flash line says what happened.

### 2.5 Settings (`SettingsView`)

Sections: Help (`settings.howItWorks`, `settings.whatsNew`), PARAGON (`settings.paragonLine`, `settings.checkParagon` "Check again"), Your boards (`settings.safetyLine`; `settings.notInCloud`, only while boards wait for iCloud: "1 board is not in iCloud yet. It is safe on this device." / "N boards are not in iCloud yet. They are safe on this device."; `settings.saveWarning`, only when a write failed, in amber; Mac only `settings.showFolder` "Show the boards folder", which opens the device's `Boards` folder), About (`settings.version`). Done `settings.done` (Escape on the Mac). `GuidePage` (`guide.page`) shows `Guide.guide`, `WhatsNewPage` (`whatsNew.page`) shows `Guide.news` (newest first).

PARAGON line texts: "Looking for PARAGON…"; "Sample boards: nothing is sent anywhere." (with `-sampleData`); "PARAGON's notes are found. Boards can be sent as a note, a project, or tasks for the Inbox."; "PARAGON's notes are found. Notes and projects can be sent; the Inbox cannot be reached from this device."; "PARAGON's notes were not found on this device. Open PARAGON once with its own iCloud folder, then check again."

Save warning (also shown once as a flash when it appears): "“<Title>” could not be saved on this device. Keep Seedboard open: it tries again by itself." (several: "N boards could not…"), or, when only iCloud's copy failed, "“<Title>” could not be put into iCloud. Nothing is lost: the device has it, and Seedboard tries again by itself." The warning goes away when the write succeeds.

Safety line: "<N board(s)> · last safety copy today|yesterday|d MMM HH:mm", or "· no safety copy yet", or in sample mode "· example boards, nothing is saved". When iCloud is off (no account, or sample mode excluded) " · iCloud is off: the boards are on this device only" is added at the end.

### 2.6 Mac menus

Edit: Undo ⌘Z, Redo ⇧⌘Z (replace the standard ones; disabled with nothing to undo/redo). Board menu: "Copy the Chosen Things" ⌘D, "To Do" ⇧⌘T, "Paste a List as a Mind Map" ⇧⌘V (clipboard text; Mac and iPad keyboard), "Bigger" ⌘+, "Smaller" ⌘-, "Show the Whole Board" ⌘0. Paste (⌘V) on the canvas pastes a list (3.8) — on macOS only (`onPasteCommand`).

## 3. Rules (SeedboardCore and the canvas)

### 3.1 Data (Board.swift)

- `ItemKind`: idea, box, round, diamond, oval, note, text, frame. `isShape`: box, round, diamond, oval. Words: Idea, Box, Round box, Diamond, Oval, Sticky note, Text, Frame.
- Default sizes (w x h): idea 90 x 30, box 150 x 56, round 150 x 52, diamond 160 x 104, oval 150 x 72, note 150 x 110, text 120 x 28, frame 440 x 300. A new centre idea is made 150 x 46 (then fitted to its words).
- `Item`: id, kind, text, x, y, w, h (a rectangle, top-left origin, y down), colour (a name; "" = the kind's own), todo, parent (idea only; nil = a centre or not an idea), order (place among sisters), folded, bothSides (centre only). Not stored fields of their own: `unknownKind` (the kind word from the file when this version does not know it) and `extra` (the file's fields this version does not know).
- `Link` (arrow): id, from, to, text, colour, style (`elbow` "Right angles" default, `straight`, `curve`), head (always true; there is no control to remove it). Also `unknownStyle` and `extra`, as for an item.
- `SentInfo`: when, kind ("note" or "project"), title, path (e.g. "Projects/Summer cabin.md").
- `Board`: id, title, created, changed, format, pinned, colour (default "green"), items, links, sent, sentTodos (ids of to-do items already sent to the Inbox or inside a note/project). Also `extra` (the file's fields this version does not know).
- `Palette.names`: pink, orange, teal, blue, purple, green, yellow, red, grey. `Palette.branches` (order of main-branch colours): pink, orange, teal, blue, purple, green, red. `Palette.notes`: yellow, pink, blue, green, orange, purple. `Palette.boards`: green, pink, orange, blue, teal, purple. `branch(i)` wraps round after 7.
- Colours by day / night (hex), lines: pink C0399F / E58AD0, orange E07B1A / F2A45C, teal 1E9C8E / 5CCBBE, blue 3572D6 / 7FAEF5, purple 8E55D9 / B99AF0, green 2E8B57 / 5FBF8A, yellow C99A0A / F0C850, red D5485C / F08A98, grey 7B8794 / A9B4C4. Note paper: yellow FBE38A / 6B5A1E, pink F9C2D4 / 6B3048, blue BFD9FA / 2C4A73, green BFE8C8 / 2C5A3B, orange FBD0A0 / 6E4520, purple DCC9F7 / 49367A. An unknown colour name draws as grey (line) or yellow (note).
- Canvas: day F6F7F9, night 17181B. Chosen/outline green 2E8B57 / 5FBF8A.
- `touch()` stamps `changed` with `max(now, changed + 0.001 s)`: always later than the board's last stamp, even when this device's clock runs behind another's, so "the newer change wins" never throws away the change just made. `canBeChanged` = `format <= 1` AND no item or arrow of a kind this version does not know (`holdsUnknownKinds`).

### 3.2 File format

- `Board.currentFormat = 1`. Raise it when a new version writes something an older version would lose or could not use: a new stored field, a new kind of item or arrow. The test `StoredFieldsTests` holds the list of stored field names for each format number and fails when a field is added, renamed or dropped without a new number.
- Encoding: JSON, pretty-printed with sorted keys, dates as ISO 8601 written to the thousandth of a second (e.g. `2026-11-18T09:15:00.123Z`); reading accepts them with or without the fraction. Item keys: id, kind, text, x, y, w, h, colour, todo, parent, order, folded, bothSides. Link keys: id, from, to, text, colour, style, head. Board keys: id, title, created, changed, format, pinned, colour, items, links, sent, sentTodos.
- Tolerant reading: a missing field gets its plain default (kind "box", text "", x/y 0, w/h the kind's default size, colour "", todo/folded/bothSides false, parent nil, order 0; board title "Board", created 1970, changed = created, format 1, pinned false, colour "green", sentTodos []). A field this version does not know (on the board, on an item, on an arrow; any JSON value) is CARRIED: it is kept as it was read (`extra`) and written back untouched at every save, so an older app never drops what a newer one wrote. (Fields inside `sent` are not carried.) An unknown kind word draws as a box and an unknown style as right angles, but the word is kept and written back as it was, and such a board is read-only (`canBeChanged` false: the banner of 2.3, no tools, never written over, no copy) exactly like a board of a newer format. One broken item or arrow is skipped without losing the board (each element is read by itself). An arrow without `from` or `to` is skipped. A board without an `id` cannot be read. A damaged file in which an idea hangs under itself, or ideas hang in a ring, opens: such an idea becomes a centre (each ring member its own map) and `descendants` never goes round for ever.
- A file with `format` above 1, or one that holds a kind of item or arrow this version does not know, comes from a newer version: it is read as far as this version understands it and SHOWN, but `canBeChanged` is false (the board is read-only, 2.3) and it is never written over (see 6).

### 3.3 Starters (Starters.swift)

Titles are the start's name ("New board" for blank). All are centred round (0, 0).

- Blank board: nothing.
- Mind map: centre "Main idea" with four ideas "First thought" … "Fourth thought"; both sides on.
- Flow: round "Start", box "Step", diamond "Decision?", box "Do it" in a row 70 apart; box "Think again" 70 below the diamond. Arrows Start→Step, Step→Decision?, Decision?→Do it ("Yes"), Decision?→Think again ("No").
- Pros and cons: text "What are we deciding?" at (0, -250); two frames 360 x 420, "Pros" (green, centred x -200) and "Cons" (red, x 200), each with two notes "A good thing" (green paper) / "A bad thing" (pink paper).
- Plan in steps: five boxes "Step 1" … "Step 5", 70 apart, each with a note "What it needs" below it (centre 113 below the box centre), arrows between the boxes.

### 3.4 Mind maps (MindMap.swift)

- An idea with no parent is a centre; every other idea hangs under one parent. `children(of:)` are sorted by (`order`, id string). Depth 0 = centre, 1 = main branch.
- Layout constants: `gapAcross = 46` (sideways, between an idea and its children), `gapDown = 10` (between sisters). The centre stays where the owner put it. Every other idea is placed by `layoutMaps()` after every change: the height of a subtree is the larger of the idea's own height and the sum of its children's subtree heights plus gaps (a folded idea counts as its own height); children are stacked top to bottom in order and each is centred in its slot; a child's x is the parent's right edge + 46 (left side: parent's left edge − 46 − the child's width). With `bothSides`, every main branch is placed on the side it remembers (`side`, see Sides below); on each side the branches are stacked in their order. A main branch carries its side to everything below it. An idea whose parent is gone, or that hangs under itself, becomes a centre; ideas hanging in a ring each become a centre. Folded: children are not placed and count as hidden (also not hit, not drawn, not counted by `bounds`).
- Sides (`MindMap.sides(of:bothSides:)`, one rule for the layout, `side(of:)` and the drawing): without `bothSides` everything is right. With it, a main branch stays on the side it remembers. A branch that remembers none goes to the emptier side (right when even), in order. A map in which NO branch remembers a side (a file from 0.1, a pasted list, a starter, a one-sided map just switched to both sides) is split as in 0.1: the first `(n + 1) / 2` right, the rest left. `layoutMaps()` and `settleSides(of:)` write the sides down, so adding or removing a branch never makes another one jump across the middle. Switching to one side keeps the remembered sides for the way back.
- Adding: `addCentre` (150 x 46, both sides on); `addChild` appends after the last sister (`order` = last + 1), takes the next free colour of `Palette.branches` if it is a main branch (first not used by its sisters, else by count), unfolds the parent; a new main branch of a both-sides map goes to the emptier side (right when even). `addSister(above:)` puts the new idea right after (or before) this one and renumbers 1, 2, 3… (for a centre it makes a first branch); a new main branch made this way stays on the side of the idea it was made from when the two sides are even, else it goes to the emptier side.
- `reparent(id, under:)`: refused when the target is the idea itself or lies below it, or either is not an idea; the idea goes last under the target, the target is unfolded; under a centre an idea with no colour takes the next free branch colour and (unless it already was a main branch there) the emptier side; under a non-centre the colour and the side are cleared. The idea may be a centre: its whole map then hangs under the target, its `bothSides` goes off and every idea below it loses its own colour and side, so all of them follow the branch they are now in.
- `detach(id, at:)`: the idea becomes a centre at the point (colour and side cleared, both sides off). The ideas right under it are main branches now: each one without a colour takes the next free branch colour.
- `moveOut(id)` (Shift+Tab): the idea becomes the sister right after the idea it hung under (`reparent` under the grandparent, then renumbering). Refused for a centre and for a main branch. An idea that becomes a main branch this way takes a branch colour and stays on its old parent's side.
- `idea(at:notIn:)`: the topmost visible idea under a point (box grown by 5 across, 4 up/down), leaving a set of ideas out — used while a whole map is dragged over another.
- Making room (`makeRoom(since:)`, Room.swift), called by the app after every undoable change and every keystroke with the board as it was before: every map whose visible idea boxes changed while its centre did not move pushes away what it NEWLY covers — a note, shape or free text that was not moved by the change, overlaps an idea box now and overlapped none before, and likewise another map as a whole (centre not moved; all its ideas go together, hidden ones too). Each goes the shortest of the four ways (right, left, down, up; away from the centre first when two are equal) until it stands 8 points clear of every idea box of the map. A pushed note, shape or text takes along, the same way, any other note, shape or text it would then newly lie on (at most 60 such pushes). Frames and things the owner laid on a map on purpose stay. A dragged map (centre moved) pushes nothing. Undo, Redo, a live drag and a version from another device do not make room.
- `shiftIdea` exists in the rules (move one place up or down among sisters) but no control uses it in 0.1.
- Branch colour: a main branch's own colour (pink if empty); everything under it follows. Side: see Sides above.
- Walking (`idea(from:step:)`): up/down = the neighbouring sister on the same side (not past the ends); on a centre right/left = its first child on that side; on another idea the key pointing towards its children = its first child (none if folded), the other = its parent.
- Removing an idea removes everything under it.
- Text sizes: centre 17 bold, main branch 15 bold, deeper 15 regular. Fitting (`Lettering.fit`, after every change): the words are measured (wrap width centre/idea 240, free text 360); centre w = max(110, text + 32), h = max(44, text + 20); other idea w = max(36, text + 6), h = max(26, text + 8); free text w = max(40, text + 8), h = max(26, text + 6); shapes (`ShapeFit.size`): needed height = text + 22 for box and round (wrap width − 24), 2 x text + 20 for a diamond (wrap 0.56 of width), 1.4 x text + 16 for an oval (wrap 0.72 of width). Normally the width is the owner's and only the height grows: max(own, needed). While its words are typed, and right after its kind is changed, a shape whose words no longer fit its height first grows WIDER, round its middle, to the narrowest width at which they fit (found in 2-point steps), at most to `ShapeFit.widest` (box and round 300, oval 320, diamond 340), and only then taller. A shape the owner made wider than that is never narrowed. Note max(own, text + 22) (wrap width − 20); an empty idea is measured as "Idea". Shapes and notes never shrink.
- Branch drawing: a curve from the parent's side middle to the child's near side middle, 2.6 wide, in the branch colour.
- A folded idea shows a filled dot (grey for a centre, else the branch colour) with the number of its direct children, 14 points beside it.

### 3.5 Shapes, arrows and routing (BoardEdit.swift, Route.swift)

- `add(kind, centre:)`: a note with no colour becomes yellow; a frame is inserted at the bottom of the item list (so it is drawn under everything); everything else is appended (on top).
- `link(from:to:)`: refused for the same item, a missing item, or a frame at either end; the same (from, to) pair is never made twice (the old one is returned). Arrows may join shapes, notes, text and ideas.
- `addNext(from:direction:gap = 70)`: not for ideas or frames. A new item of the same kind, size and colour, `gap` away in the direction, joined by an arrow. While its box grown by 8 touches a visible non-frame item (up to 12 tries) it steps aside: down by its height + 24 for left/right steps, right by its width + 24 for up/down steps.
- Removing items removes the arrows that lose an end, and forgets their `sentTodos`.
- Routing (`Route.path`): "apart across" = the boxes do not overlap in x; "apart down" likewise in y. Sideways when apart across (and, if also apart down, when |dx| >= |dy| between centres), up/down when only apart down; when they overlap both ways, by |dx| >= |dy|. The line leaves the middle of the side facing the other item and arrives at the middle of the facing side of the other. `straight` and `curve`: two points (the curve is drawn as a bezier with control points at half way, along the leaving direction). `elbow`: one straight piece when the ends line up within 1 point, else four points with the bend half way. The label sits at half the length of the line. The head (two strokes, 9 long, 5.5 wide) points the way the line arrives. Arrow line 2.2 wide, grey (7B8794 / A9B4C4) or the arrow's colour; chosen: a soft 8-wide halo.
- Hit distance for an arrow: 9 screen points (8 board points in the rules' default).
- Words on an arrow: 13 pt medium on a plate of the canvas colour.
- Shapes: box = rounded rectangle radius 9; round = capsule; diamond = four tips; oval = ellipse. Uncoloured: white/plate fill with a 1.4 grey edge; coloured: soft tint fill and 1.8 coloured edge. Notes: paper colour, radius 4, soft shadow, left-aligned words, dark ink in day mode. Frame: radius 14, soft tint (0.45 day / 0.35 night) with a 1.6 line, name at top left in 13 bold, default colour teal, placeholder "Frame".
- Changing the kind of a shape (`Board.setKind(_:to:)`) keeps the middle, the words and the colour, and keeps the size when the owner (or the words) changed it; only a shape still exactly at its old kind's default size takes the new kind's default size. After the change the shape is fitted with widening (3.4, text sizes).
- Resizing (`resize`) never goes below 44 x 28 (frame 120 x 80).

### 3.6 Hit-testing and carrying

- `hit(point)`: items from the top: non-frames first (visible only). Diamond: |dx|/(w/2) + |dy|/(h/2) <= 1.02; oval: ellipse test with 1.03; idea and text: the box grown by 5 across and 4 up/down; others: the box. Frames after that, topmost first: caught only inside the top 30 points (name band), within 8 inside the edge, or up to 6 outside the edge.
- `hitLink(point, within:)`: the nearest arrow whose two ends are visible; the canvas uses 9 / scale.
- `items(in: rect)` (the choosing box): every visible item the box touches; a frame only when the box wholly contains it.
- `carried(by:)` (what moves with a drag): a centre idea with all its descendants; a frame with every item wholly inside it (centres with their descendants); other ideas are left out (the map places them); other kinds alone.
- `duplicate`: copies the items (an idea with all ideas under it) 28 down and 28 right, with the arrows between them. A copied idea whose parent was not copied keeps its parent and takes `order + 0.5` (the next sister) and is not moved. `todo` is kept.
- `bounds`: the union of all visible items (nil when empty).

### 3.7 The canvas: view, gestures, undo

- View: `Viewport` (Core): `offset`, `scale`, the room `size` and the mark `movedByOwner`. Every way of moving the view — two-finger scroll, a finger slide on empty board (`slide(from:by:)`), `reveal`, zoom by button, key, pinch or ⌘-scroll — goes through `pan` or `zoom`, which set the mark. While the mark is not set the board is fitted again whenever its room changes (a window settling, the keyboard, a page over it); once it is set the view stays where the owner left it. Zoom range 0.2 – 3 (20 % – 300 %); buttons and ⌘+ / ⌘- change it by 1.25; zoom keeps the point under the pointer (or the view's middle). Fit: room = view minus 80 across and 170 down; scale = min(1, fit) but never below 0.5 (on a small screen with a large board the middle shows and the view is moved by hand); centred on the bounds; an empty board is shown at 100 % with the origin in the middle. A board is fitted the first time its size is known. `reveal` moves the view only as far as needed to bring an item inside a safe rectangle (30 from the sides, 70 from the top, 120 from the bottom).
- Mac: scroll wheel / two fingers move the view (x8 for wheels without precise deltas); a magnify gesture zooms around the pointer; ⌘ + scroll zooms by 1 % per scroll unit. iPhone/iPad: pinch zooms around the fingers; there is no two-finger scroll handler.
- Press and drag (a press that moves more than 4 points becomes a drag): on an item → move it (with all chosen items if it is chosen; with `carried(by:)`); on a non-centre idea → drag-an-idea (a ghost at 70 % follows; a dashed green frame marks an idea under the finger that is not a descendant) — on iPhone and iPad only when the finger rested at least 0.25 s before it moved (a light tap of the haptic motor marks the lift); a quicker slide that starts on an idea pans the view instead; on a plus → pull a line; on the size knob → resize; on an arrow or empty board → a choosing box on the Mac (`ScrollCatcher`-less drag), pan on iPhone/iPad; in read-only mode a drag on an item pans. In arrow-tool mode a drag from an item to another joins them.
- Release of an idea drag: over a target idea → `reparent`; no target and moved more than 50 screen points → `detach` at the release point, and the notice `board.notice` "Made its own map" with the button `board.noticeUndo` "Undo" shows for 6 s (it goes at the next change, Undo or Redo); else it springs back.
- Dragging ONE map by its centre: the dashed green frame marks the idea of another map under the pointer; released there, the map goes back to where it was and `reparent`s under that idea (the two maps become one), with the notice "Joined to the other map" and Undo. Released anywhere else it is an ordinary move.
- Keys (focus): the canvas takes the keyboard focus when a board opens, when typing ends, on every press on it, after every button of the tool pill, the selection bar, the colour row, the zoom and undo buttons, each item of the More menu, the rename and remove dialogs, and when the Send page closes (`BoardSession.takeKeys`).
- Release of a plus pull: from an idea → a new child; from another item → over another non-frame item joins them, else a new item of the same kind and colour is made with its middle at the release point, joined, chosen and ready to type.
- Press without moving: on a plus → idea: new child; other: `addNext` in that direction. On an item: chooses it (Shift on the Mac adds/removes). Two presses within 0.42 s on the same item or arrow → type its words. On empty board: chooses nothing; two presses within 0.42 s → a sticky note with its middle at the press, only when nothing was chosen (no item, no arrow) before the FIRST press. In arrow-tool mode: the first non-frame item sets the start, the second joins; a press on a frame is passed over and the tool stays on (a drag from an item and let go on a frame makes no arrow and ends the tool); empty board ends the tool. With `choosingMore` (iPhone/iPad) a press on an item adds or removes it like Shift on the Mac.
- Handles of a single chosen item (not while typing, not read-only, not in arrow-tool mode): idea centre: one plus, on the right; other idea: one plus on its side; free text: plus right and down; frame: size knob only; every other kind: four plus signs and a size knob at the lower right corner. A plus is 18 points (screen) wide and stands 17 points from the item's edge; a press within 9 points counts. Handles keep that screen size when zoomed in and shrink with the zoom below 100 % (factor `min(1, max(scale, 0.55))`). The plus of a centre makes a child; it goes right in a one-sided map and to the emptier side in a both-sides map (3.4).
- Chosen items have a green outline (2 points, 5 / 4 outside the box).
- Undo: a stack of at most 120 earlier boards (the oldest falls away); a new change empties Redo. One drag, one typed item or one command is one step. Undo and Redo do nothing while typing. The stacks live only as long as the board stays open. When a newer version of the open board arrives from another device (`BoardSession.replace`), it takes the place of the open one and both stacks are emptied; while typing or dragging (`busy`) the open board is left alone and the next save settles it (newer wins, the other goes to the safety copies).
- `change` ignores a change that leaves the board equal; every kept change stamps `changed` and calls the save.
- Select all (⌘A): every visible item.
- Delete: removes the chosen items and arrow; if exactly one item was removed and it had a parent, the parent is chosen.
- To do: sets `todo` on every chosen item that is not a frame; if all chosen items already have it, clears it.
- Both sides: toggles `bothSides` on the centre of the chosen idea's map. Fold: toggles `folded` on the chosen idea.
- Turn round: swaps `from` and `to`. Words/typing on an arrow: draft in a field over the label, 170 wide.

### 3.8 Typing in place

- Press a tool, plus, chip or key that makes a thing → typing starts in it at once. Words go onto the board as typed (the board is re-fitted each keystroke). `commitEdit` trims the words. Every keystroke is also handed to the save (written 0.5 s later), so leaving the app mid-sentence loses nothing.
- Return: in an idea → ends and makes the next sister (`addSister`; for a centre, a first branch); in anything else → ends. Shift+Return or Option+Return → new line (hardware keyboard), in an idea too: the field makes the line where the cursor stands, and if it has not within 0.08 s the line is put at the end of the words. In an idea, exactly ONE new line break in the text without Shift (the screen keyboard's Return; `Typing.withoutNewBreak`) ends the idea and starts the next sister; if the idea is empty it just ends. Line breaks already in an idea stay, and several lines pasted in stay as lines. In lists and in PARAGON an idea with several lines is one line. Tab: in an idea → ends and makes a child; elsewhere → ends. Shift+Tab: in an idea → `moveOut` and the typing goes on; elsewhere nothing. Escape → cancels (`cancelEdit`): the words go back to what they were when the typing began, and a thing made for this typing (tool, plus, Tab, Return) goes away again, its making taken back out of Undo, and its parent is chosen. Return, Done and pressing elsewhere on the canvas keep the words. Opening another board ends it.
- A new idea (made by the tool, plus, Tab, Return or Next idea) that ends empty, has a parent and no ideas under it, is removed again and its parent is chosen. A new centre left empty stays (it shows the faint word "Idea").
- A board still titled "New board" takes the first line of the only item that has words, cut to 40 characters.
- One typed item is one Undo step (adding it is another; the UI test relies on that: two undos reach "Empty"). A cancelled new thing leaves no step.
- Not typing, a chosen single item + any single printable character (no ⌃ or ⌥, no ⌘) starts typing and puts the character after the existing words.

### 3.9 Keys (canvas, no typing in progress)

⌘A select all. Tab: child of the chosen idea. Shift+Tab: the chosen idea moves out one level (`moveOut`, 3.4). Return: next idea beside a chosen idea (centre: first branch); other chosen item: type; chosen arrow: type. Delete / Forward Delete: remove. Escape: clear the choice (and `choosingMore`) and leave the arrow tool. Arrow keys: walk a chosen idea, else move chosen things (carried) 10 points, with Shift 40. Space: type in the chosen item. With one item chosen a printable character types (see 3.8). With no item chosen and no arrow chosen: m idea, b or r box, u round, d diamond, o oval, n note, t text, f frame, a or l toggles the arrow tool (these add at the middle of the view and end the arrow tool). With several things chosen the letters also add things. Menu keys (`BoardCommands`, on the Mac's menu bar and, with a hardware keyboard, on the iPad and iPhone window too, where holding ⌘ lists them): ⌘Z, ⇧⌘Z, ⌘D, ⇧⌘T, ⇧⌘V (paste a list as a mind map), ⌘+, ⌘-, ⌘0; ⌘V (Mac only). While words are typed on the board, ⌘Z and ⇧⌘Z go to the text field (Mac: the `undo:` / `redo:` actions; iPhone/iPad: the undo manager of the view that has the keys).

### 3.10 Lists in and out (Outline.swift)

- `Outline.parse(text)`: one entry per line; blank lines ignored; text trimmed. Depth from leading spaces and tabs (a tab = 4 spaces; any consistent step; a smaller indent closes deeper levels). Markers stripped: one of `- * + • – ◦`, or a number with `.` or `)`, or a single letter with `)`, followed by a space; then a check box `[ ]`, `[x]`, `[X]`. A line that is only a marker is dropped. A Markdown heading (1–6 `#` then a space) has depth level − 1, and the following list lines nest under it (depth = heading depth + 1 + their indent steps; a new heading resets the indent steps). A line is pulled up so that it is at most one step deeper than the line before it.
- `Outline.isList` = at least two non-blank lines.
- `addMap(from:title:at:)`: one top node → it is the centre and its children are the main branches; several → the centre says the title or "Ideas" and the top nodes are the main branches. Rough sizes first (8.2 per character + 16, at most 260, at least 60; height 30; centre + 24 wide and 46 high), fitted by the app later. `bothSides` when there are more than 4 main branches. Branch colours follow 3.4.
- Paste (`BoardSession.paste`): ignored while typing, read-only or empty text. With exactly one idea chosen and a non-empty parse: the nodes hang under it (even one line). Else with `isList`: a new map with its middle at a free spot near the middle of the view (300 x 200 searched). Else (one line): a yellow sticky note with the text at a free spot. The new thing is chosen.
- `outlineText` (Copy the board as text): maps as `- ` bullets two spaces per level, separated by newlines; then "Flow:" with `A → B (words)` lines; "Notes:" with `- ` lines for notes and text; "Shapes:" with `- ` lines for shapes that no arrow touches. Sections are separated by a blank line. Line breaks inside words become a single space; empty words show as "(empty)".

## 4. Look

- Parts and colours (day / night): boards green 2E8B57 / 5FBF8A; mind map A8388F / E27FC8; shapes 2B67C9 / 7FAEF5; arrows 4A5565 / A9B4C4; notes B77A08 / F0BE50; frames 178378 / 5CCBBE; PARAGON 6B4EA8 / B59CEB; text = ink. A full-colour button always uses the day shade with white words; disabled = half opacity, not grey. Soft backgrounds are 6 % (day) or 12 % (night) of the colour over a pale base.
- Type: Apple text styles; on the Mac titles take a step up. Board text 17 / 15 / 13 as in 3.4 and 3.5.
- Marks: hand-drawn marks from the AMS-Icons package (app marks such as seedSprout, seedBox, seedMindMap, seedArrow, seedNote, seedText, seedFrame, seedFit, send, undo, redo, duplicate, bin, palette, zoomIn, zoomOut; control marks add, chevron, ticked, circle, edit, settings). The app icon: a white hand-drawn seed with three branches on a flat teal tile, no transparency.
- A to-do box shows a purple (PARAGON) ring 7.5 in radius with a white tick at its upper right corner (a branch idea: beside the idea).
- Settings headings: Help green, PARAGON purple, Your boards green, About teal.
- Day and night follow the system.

## 5. Send to PARAGON (Paragon.swift, ParagonGate.swift, SendSheet.swift)

Two rules protect the owner's notes: Seedboard only ever adds new files to PARAGON's folder (it never opens, changes or replaces an existing one; files are written without overwriting; the one file it may take away again is a picture it made itself a moment ago in the same hand-over, when the note for it could not be written), and Inbox lines are never written into `Inbox.md` but into the waiting list that PARAGON's own Share button uses.

### 5.1 Finding PARAGON

- PARAGON's notes folder: the `Documents` folder of the iCloud container `iCloud.com.schabbauer.AMSPara`. It counts as PARAGON's folder IN USE when it holds `Inbox.md` (or `.Inbox.md.icloud`) or PARAGON's own settings file `.ams-para/config.json` (or `.ams-para/.config.json.icloud`) — `ParagonExport.looksLikeParagonFolder`. A folder with only a `Projects` folder in it is not taken: that can be a folder PARAGON never used. (Seedboard cannot ask PARAGON which folder it uses when the owner pointed PARAGON at a folder of his own; only this container is looked at.)
- The Inbox waiting list: the file `capture-outbox.jsonl` in the app-group container `group.com.schabbauer.amspara` (macOS: `D24ENP83QQ.group.com.schabbauer.amspara`). If the group container cannot be reached, notes and projects can still be sent and the Inbox cannot.
- Without iCloud (no container) PARAGON is "not found". With `-sampleData` PARAGON is "not found" (unless `-paragonFolder`, below).
- Looking is slow the first time and runs off the main thread; it runs at launch, on Settings → Check again, and again at EVERY Send (the folder may have appeared, gone or changed since the app started); the PARAGON line in Settings follows what the last look found.
- Entitlements: sandbox, user-selected files read-write, iCloud documents with both containers (Seedboard's own first, PARAGON's second), and the app group above (iPhone/iPad: `project.yml`; Mac: `App/Config/AMSSeedboard-macOS.entitlements`). `LSApplicationQueriesSchemes`: `amspara`.

### 5.2 Names

- Note title (`noteTitle`): `/ \ : * ? " < > |`, line breaks, tabs and control characters become a space; spaces squeezed; dots and spaces trimmed at both ends; at most 100 characters (re-trimmed); `(conflict` becomes `(clash` (PARAGON reads "(conflict …)" as a conflict copy); an empty title becomes "Board"; the words "capture" and "timeblock" (any case) become "<word> (board)".
- Free title (`freeTitle`): compared with every `.md` file name in the PARAGON folder (all sub-folders, hidden folders skipped, `.icloud` placeholders counted), case-insensitive. If taken: "Title (board 2)", "(board 3)"… A name that would look like "Name 2" (a single digit 2–9 after a space) beside an existing "Name" is also treated as taken.
- Picture name: `Seedboard <safe title, at most 60 characters> <yyyy-MM-dd HHmm>.png` (letters, digits, space, `- _ . ,` kept; others become spaces); empty → "board". If it exists: " b2", " b3"… (up to 50 tries).

### 5.3 What is written where (all relative to PARAGON's folder)

- As a note: `Resources/<Title>.md`, and `Pictures/<picture>.png`.
- As a project: `Projects/<Title>.md`, and `Pictures/<picture>.png`.
- The picture is written first; if it fails nothing else is written and the page says "The picture could not be saved in PARAGON's folder. Nothing was changed." If the note then fails, the picture made a moment ago (only that new file) is taken away again and the page says "The note could not be saved in PARAGON's folder. Nothing was changed."; if the picture cannot be taken away either: "The note could not be saved in PARAGON's folder. Its picture “<name>” is left in PARAGON's Pictures folder; no note uses it."  The picture is made from the board in the day look on a white background (the plates behind words on arrows are white too), the bounds grown by 40, at 2x (1x when the larger side is over 3000 points). Nothing is picture-written for "Only the to-do boxes". An empty board has no picture (and the Send page does not allow it).
- Only the to-do boxes: no file in the folder; lines go to the waiting list.
- The waiting list is JSON Lines: one line per entry, appended in one step (`O_APPEND`), so PARAGON and Seedboard cannot write into each other. Each line: `id` (new UUID), `text`, `target` (inbox), `asTask` (true for a task, false for a note line), `createdAt` (ISO 8601; task lines are 1 s apart in board order). The lines are made in SeedboardCore (`ParagonExport.WaitingLine`, `taskLines`, `noteLine`, `waitingData`), and a test reads them back with a copy of PARAGON's own reader (`CaptureItem`, PARAGON build 339). All the lines of one send are written in ONE append: either every task is on its way, or none (a failed write says the Inbox cannot be reached). PARAGON files the lines itself the next time it opens.
- As a note: after the note is written, one line `[[<Title>]] — a board from Seedboard` with `asTask` false is added, only when the waiting list is reachable (a failure to write it is ignored). The result message: "“<Title>” is in PARAGON under Resources, with a line in the Inbox." or "… under Resources." or "… under Projects."
- Only the to-do boxes: one task per unsent to-do item that has words, in board order. So that the same tasks can never go twice, the "already sent" ticks are saved FIRST: the board with the ticks is written to the device (and waited for) before the lines are added to the waiting list; if adding them fails, the board is stored again without the ticks. A second Send while one is on its way is refused ("The board is on its way already."). Message: "1 task is on the way to the PARAGON Inbox. They show the next time PARAGON opens." (or "N tasks are…"). Errors: "No to-do boxes are waiting to be sent." / "This device cannot reach PARAGON's Inbox. Send the board as a note or a project instead."
- Afterwards (`markSent`): for a note or project the board's `sent` is set (when, kind, title, path "<Folder>/<Title>.md") and EVERY to-do item (also ones whose words are empty) is added to `sentTodos`; for to-do boxes only the sent ones are added. The board is saved at once. Taking the To do off a box (`toggleTodo`, all chosen ticked → cleared) removes it from `sentTodos`, so ticking it again sends it again. Copies of a board start with `sentTodos` empty.
- Open in PARAGON: opens `amspara://<title, percent-encoded>`.
- Board link: `seedboard://board/<board UUID>` (what happens when it arrives: 2.2). In PARAGON it opens from the reading view, and since PARAGON build 339 also while the note is edited (iPhone and iPad: a tap on its words; Mac: ⌘-click).

### 5.4 Text of a note (`Resources/`)

```
---
title: <Title>
type: resource
created: yyyy-MM-dd
---
# <Title>

![Picture](../Pictures/<picture, %-encoded>)

[Open the board in Seedboard](seedboard://board/<UUID>)

## Outline
- <centre>
  - <branch>
    - <idea>

## Flow
- <from> → <to> (<words on the arrow>)

## Notes
- <words of a sticky note or free text>

## Tasks
- [ ] <words of each item marked To do>
```

A value that starts with `[ { " '` in the front matter is quoted. A section with no lines is left out. The picture line is left out when there is no picture. Words of one item are made one line (line breaks become one space, runs of spaces one space); an empty label reads "(empty)". Outline: every mind map, each idea a bullet, two spaces per level. Flow: every arrow whose two ends exist, in arrow order. Notes: notes and free text with words, in item order. Tasks: every item marked To do that has words (any kind), in item order.

### 5.5 Text of a project (`Projects/`)

```
---
title: <Title>
type: project
status: active
created: yyyy-MM-dd
---
# <Title>

![Picture](../Pictures/…)

[Open the board in Seedboard](seedboard://board/<UUID>)

## Outcome

<words of the first map's centre that has words, else the title>

## Tasks

- [ ] <a main branch with no ideas under it>

### <main branch with ideas under it>
- [ ] <idea>
  - [ ] <deeper idea>

### Steps
- [ ] <each flow shape with words, in arrow order>

### To do
- [ ] <each note or free text marked To do>

## Notes

- <notes and free text>

## Log

- yyyy-MM-dd: Project created from a Seedboard board
```

All main branches of all maps are used. Every idea under a main branch becomes a task whether or not it is marked To do. Steps: every shape with words (marked or not): those no arrow points at first, each followed along its arrows, then any left over. To do: notes and free text marked To do (ideas and shapes are already in the lists above). Nothing goes to the Inbox for a project.

## 6. Storage and safety (BoardStore.swift; the decisions in SeedboardCore, Safety.swift)

- One file per board: `<UUID>.seedboard` (JSON, 3.2). Folders (device, inside the app's sandbox): Application Support/`Boards`, `Removed`, `SafetyCopies`. iCloud (container `iCloud.com.schabbauer.AMSSeedboard`, document scope public, name "Seedboard"): `Documents/Boards`, `Documents/Removed`. The cloud folder is asked for again every 30 s until found, so signing in later is noticed.
- Save: never makes the app wait, and the device never waits for iCloud. `BoardStore.save` hands the board to `BoardDisk.save`, which has two lines of work, each doing one thing at a time: `local` writes the device file at once (atomically), `cloud` does everything in iCloud's folder through file coordination. Several quick saves of one board become one iCloud write (the newest waiting version). `flush()` waits for the device line (2 s at most) when the app is left; iCloud's line gets background time (2.2). `cloudIsOn` is false without an iCloud account or in sample mode; the app then works from the device copy alone, and Settings says "iCloud is off" (2.5).
- What a board "grew from" (`Lineage`): for each board the store remembers the `changed` stamps of every version the app SHOWED (at loading, or news it took) and every version it saved, the newest 600. Two stamps less than 1.5 thousandths of a second apart are the same version (files keep thousandths).
- The rules:
  1. For the same board the newer `changed` wins; a losing version that differs is kept in `SafetyCopies` as `<UUID>-<yyyyMMdd-HHmmss>-<6 letters>.seedboard` (these single files are not removed by the 14-day rule; the same bytes are never kept twice). Before a save writes over a stored version (on the device or in iCloud) that is NOT one this board grew from — another device wrote it and this app never showed it — that version is kept in `SafetyCopies` first (`SafetyRules.write`: write / keep the stored one then write / the stored one is newer and stays, mine is kept / nothing / refuse).
  2. A version that iCloud parked because two devices wrote at once (`NSFileVersion`) is settled BY ITSELF and only when it was really read and its words are safe: the newer wins (its own bytes go into the board's file), the other is kept in `SafetyCopies`; one that cannot be read as a board is kept there as `….unreadable`. A parked version that has not arrived, or cannot be dealt with now, stays for the next look. iCloud's own copies `<UUID> 2.seedboard` (any number) are read too and joined by the same rule (the loser to `SafetyCopies`), then the stray file is cleared away — only once its words are in the board's own file or in `SafetyCopies`. A copy without its board becomes the board. A copy that has not arrived (`.….icloud`) is asked for and joined at a later look. (`BoardFileName` reads what a file is from its name.)
  3. A file from a newer format (`format` above 1), or one holding a kind this version does not know, is read and SHOWN (`canBeChanged` false, read-only) and never written over (device and iCloud writers refuse it). When two copies differ and only one is such a file, that one wins and the other goes to the safety copies.
  4. A cloud file that cannot be read, or has not arrived yet, is never written over. A DEVICE file that cannot be read no longer stops every save: its bytes are kept in `SafetyCopies` (`….unreadable`), then the new version is written.
  5. A removed board leaves a mark `<UUID>.gone` in the device `Boards` folder and the iCloud `Boards` folder, and both copies move (device and iCloud) to `Removed/<UUID>-<yyyyMMdd-HHmmss>.seedboard` (the next free second when that name is taken). It is not deleted at once. The mark carries WHEN the board was removed: `{"removed":"<ISO 8601 with thousandths>"}`, always later than the board's last change (`RemovalMark.time`); an old mark of 0.1 is empty and counts as "removed at the mark file's date". At each load and each look at iCloud (`SafetyRules.removal`): a version of the board changed AFTER the removal wins — the marks are cleared on the device and in iCloud and the board is back on every device; otherwise every device that finds a mark moves its own copy to its Removed folder too (`moveAway`), and the board is not shown. A save of a marked board is refused unless its change is later than the removal (then it clears the mark). While a mark or iCloud's copy of the board has not arrived yet, nothing is decided for that board. Files in either Removed folder are deleted for good when the day in their NAME is more than 30 days back (`removedDay`); a file whose day cannot be read is kept. The 30 days count from when that device moved its copy. Marks are kept a year (by creation date). `BoardStore.bringBack(id:)` puts the newest copy in Removed back as the board, stamped later than the removal, and clears the marks; there is no button for it yet (see 2.2).
  6. Once a day, before the first write or load of the day, all device boards are copied to `SafetyCopies/<yyyy-MM-dd>/`; the newest 14 day folders are kept. Nothing is made when there are no boards.
  7. Loading: the union of ids in both folders (a `.<name>.icloud` placeholder is asked for and counted), minus the removed ones (rule 5). Both copies equal → used; iCloud's newer → it is shown, the device's version goes to the safety copies and is replaced (unless the device has moved on meanwhile: then the next save settles it); the device's newer → it is shown and written to iCloud, and iCloud's version is kept in the safety copies unless it is one this board grew from (a newer-format copy beats an older-format one, rule 3); only the device copy → shown and sent to iCloud; only the cloud copy → shown and copied to the device; a side unreadable → the other is shown and the unreadable one is left alone. A board of a newer format is shown read-only (banner of 2.3).
  8. iCloud is watched (a query on `*.seedboard` and `*.gone`, and at every return to the app); a board that is newer than what the app SHOWS is news: it replaces the board in the list, and in the open board when it is not being typed in or dragged (then Undo's steps are cleared, 3.7). News for a board that is being typed in is held and offered again (2.2); only news the app shows counts as seen, anything else is offered again at the next look (`SafetyRules.news`: ignore / take / hold). Boards that gained a removal mark on another device leave the list (2.2).
  9. A removal reaches every device through the mark of rule 5: another device that still has its copy moves it to Removed at its next load or at the next look at iCloud — unless that copy was changed after the removal.
  10. Writes that fail are said, not swallowed. The store tells the app (`onState`) two things: `notInCloud` (rule 11) and `warning` (texts in 2.5) — a device write that failed, or an iCloud write that failed. While either is the case the store looks again every few seconds (3 s, then twice as long each time, 30 s at most): it tries the failed device write again, looks at iCloud again (which writes whatever is only on the device), and stops by itself when all is well.
  11. "Not in iCloud yet": a board is in this set from the moment it is saved until iCloud's folder holds that same version AND iCloud says the file is uploaded (`ubiquitousItemIsUploaded`); also boards found at loading that are only on the device or not uploaded. Without iCloud the set is empty (Settings says "iCloud is off" instead).
  12. Known weak spots (**Note**): a copy of a newer-format board is refused; Send on such a board writes the files in PARAGON but the sent mark is not kept. With clocks that disagree between devices the "newer" change is the one with the later stamp, not always the one made last; the loser is always in `SafetyCopies`.
- Mac: Settings → Show the boards folder opens the device `Boards` folder.

## 7. Launch arguments (pictures and tests)

| Argument | Effect |
| --- | --- |
| `-sampleData` | Made-up boards (Summer cabin pinned, App ideas pinned, Garage shelves, Trip to Spain, Packing flow, Training year, Workshop bench "sent"), nothing read or written, PARAGON "not found". Sample "Summer cabin": 12 ideas, 5 shapes, 2 notes, two to-do items. The UI tests expect "12 ideas · 5 shapes · 2 notes". |
| `-board <word>` | Opens the first board whose title contains the word (case-insensitive). |
| `-pick <word>` | In the opened board, chooses the first item whose words contain the word. |
| `-send` | Opens the Send page. |
| `-settings` | Opens Settings. |
| `-paragonFolder <path>` | Debug builds only. Treats that folder as PARAGON's notes (it must hold `Inbox.md` or `Projects/`) and uses `<path>/.seedboard-test-outbox/capture-outbox.jsonl` as the waiting list. Works together with `-sampleData`. |
| `-sendNow note\|project\|todos` | Debug builds only. Sends the opened board at once (with `-paragonFolder`) and prints the result. |
| `-ApplePersistenceIgnoreState YES` | Mac tests: no restored windows. |

`-sampleData` goes last in the UI tests' argument list. Screen tests find controls by the identifiers in section 2.

## 8. What 0.1 does not do

- No drawing with the Apple Pencil, no freehand drawing.
- No sequence diagrams, no tables, no other diagram kinds.
- No pictures, files or links on a board (the board's own picture is made only for PARAGON and sharing).
- No shared editing: boards are the owner's own across his devices; there are no other people, no comments.
- No search across boards, no folders or tags, no templates beyond the five starts.
- No button to bring back a removed board (the rule and the function are there, 6 rule 5), no list of the safety copies; no change of the order of sister ideas (rule exists, no control); no way to turn an arrow head off; no way to give a board's note a different folder.
- iPhone and iPad: no choosing box and no Shift (use Choose more in the bar); no ⌘V (use ⇧⌘V with a keyboard, or More → Paste a list as a mind map).
- Two-finger scrolling on iPad trackpads is not handled; pinch and dragging are.

## 9. Tests

- Rules (`swift test --package-path Core`): board data and tolerant reading, starters, editing and hit-testing, mind-map layout and walking, outlines, arrow routing, the PARAGON texts and names; the safety rules (`SafetyTests`: held news and what a board grew from, the dated removal mark and "a later change wins", the names of iCloud's copies, unknown kinds read-only and unknown fields carried, the Inbox line read by a copy of PARAGON's reader, the signs of PARAGON's folder, links that arrive early) and the stored-fields guard (`StoredFieldsTests`).
- Rules (`swift test --package-path Core`): board data and tolerant reading, starters, editing and hit-testing, mind-map layout and walking, outlines, arrow routing, the PARAGON texts and names; `PanelFixTests`: the view stays after a slide, sides of main branches (emptier side, nobody jumps, kept in the file, an older file opens), hanging a map under an idea of another and taking it off, moving out one level, the one-new-line-break rule, a shape's kind and size, wider first then taller, making room.
- Screens (`AMSSeedboardUITests`): the app opens with its boards; a new blank board is empty; the note tool adds a note; Return in a mind map makes the next idea and an empty one goes away; undo takes the last thing away; the Send page shows its three choices and Send is disabled without PARAGON; Settings shows Help and the version; choosing a shape shows its bar and Remove works; on the Mac Tab makes an idea under the chosen one.
