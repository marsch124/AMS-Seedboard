# Notes for 0.2 — builder "mac" (picks 25 and 26)

## 1. What's new

**A fuller menu bar on the Mac (pick 25)** — the same lines work on an iPad with a keyboard and show there when ⌘ is held.
- Before: the app had 1 menu of its own, **Board**, with 9 lines (Copy the Chosen Things, To Do, Line Up, Even Gaps, Same Size, Paste a List as a Mind Map, Bigger, Smaller, Show the Whole Board). File, View and Edit held nothing of Seedboard's except Undo and Redo; Edit ▸ Delete and Select All did not reach the board (only the board's own ⌘A key did).
- Now there are 5 menus with Seedboard's lines:
  - **File** (6 lines): New Board ⌘N (opens the starter choice), New Blank Board ⇧⌘N, Rename…, Send to PARAGON… ⌘↩, Share a Picture…, Remove Board… (asks first, as before).
  - **Edit**: Undo and Redo as before; **Delete** and **Select All ⌘A** now act on the board while it has the keys; new **Duplicate ⌘D** (it was "Copy the Chosen Things" in the Board menu, same key).
  - **View** (4 lines): Zoom In ⌘+, Zoom Out ⌘−, Actual Size ⌘0, Show the Whole Board ⌘1.
  - **Insert** (new, 9 lines): the 7 tools with their letters — Mind map M, Box B, Diamond D, Arrow A, Sticky note N, Text T, Frame F — and below a line the 2 shapes that have a letter but no button: Round box U, Oval O.
  - **Board** (5 lines left): To Do ⇧⌘T, Line Up, Even Gaps, Same Size, Paste a List as a Mind Map ⇧⌘V.
- **One key changed:** ⌘0 was "Show the whole board". Now ⌘0 is Actual Size (100 %) and the whole board is ⌘1, as in other Mac apps.
- Lines that cannot act are grey: with no board open everything except New Board and New Blank Board; Delete and Duplicate with nothing chosen; To Do with nothing chosen; Share a Picture on an empty board; Rename and the Insert lines on a board made by a newer Seedboard.
- **Space and a drag slide the board (Mac).** Before: the board moved with two fingers on the trackpad only; a drag on empty board drew the choosing box. Now: hold Space — the pointer becomes an open hand — and drag anywhere, also on top of a shape; the board slides. A plain drag on empty board still draws the choosing box.
- Space pressed shortly (under half a second, no drag) with one thing chosen still starts typing in it. Before it started when the key went down, now when it is let go.
- Typing is untouched: while words are typed in a thing, letters, Space, ⌘A and ⌘Z belong to the words.

**Opens where you left (pick 26)**
- Before: Seedboard always started on the list with no board open, and every board opened shown whole.
- Now: the board that was open comes back, at the zoom and the place you left it. Every board remembers its own zoom and place, so going back to a board you worked on yesterday shows the same spot. This is per device and not synced: the Mac, the iPad and the iPhone each remember their own.
- A board you never moved or zoomed still opens shown whole. A board that is gone (removed here or on another device) falls back to the home page. If you left the app on the home page, it starts there.

**Reachable from outside (pick 26)**
- Before: the only way in from outside was a link `seedboard://board/…` (the one PARAGON's notes carry).
- Now 3 actions for the Shortcuts app, Siri, the Action button, Spotlight and Raycast:
  - **New board from text** — takes a title (optional) and text. A list becomes a mind map, anything else one sticky note. Opens Seedboard on the new board.
  - **New board** — with the starter you choose (Blank board, Mind map, Flow, Pros and cons, Plan in steps).
  - **Open board** — offers your boards by name.
- 7 phrases to say or type, each with the app's name: "New Seedboard board from text", "Start a thought in Seedboard", "New Seedboard board", "New board in Seedboard", "New Mind map in Seedboard" (any starter), "Open a Seedboard board", "Open Summer cabin in Seedboard" (any board).
- **Search on the device (Spotlight)** finds a board by its name and by the first words on it (up to 300 letters), and opens it. A removed board leaves the search.

## 2. How it works (guide text)

**The menu bar (Mac, and iPad with a keyboard).** Everything the buttons do is also in the menus. *File* makes boards (⌘N shows the starters, ⇧⌘N goes straight to a blank board), renames, sends to PARAGON (⌘↩), shares a picture and removes the open board. *Edit* has Undo, Redo, Delete, Select All (⌘A) and Duplicate (⌘D). *View* zooms: ⌘+ and ⌘− in steps, ⌘0 for the real size, ⌘1 for the whole board. *Insert* lists every tool with its letter. *Board* has To do, the three tidy commands and Paste a list as a mind map. A grey line cannot act right now — nothing is chosen, or no board is open. On an iPad with a keyboard, hold ⌘ to see the keys.

**The letter keys.** With nothing chosen, one letter makes a thing: M mind map, B box, D diamond, A arrow, N sticky note, T text, F frame, U round box, O oval. The Insert menu shows these letters when pressing one would make the thing — that is, when the board has the keys and nothing is chosen. With one thing chosen a letter starts typing in it instead, and the menu lines then show no letter (they still work with a click).

**Sliding the board with Space (Mac).** Hold Space: the pointer turns into an open hand. Drag, and the board slides with the hand; let go of Space and the pointer is an arrow again. It works wherever the drag starts, also on a shape. Two fingers on the trackpad slide the board as before. A short press of Space with one thing chosen starts typing in it.

**Where you left.** Seedboard opens on the board you had open last, at the same zoom and the same spot. Each board keeps its own zoom and spot on each device. "Show the whole board" (⌘1) is always one press away. Leave the app on the home page and it starts on the home page.

**From outside.** In the Shortcuts app, look for Seedboard: *New board from text*, *New board* and *Open board*. Put one on the Action button, in a shortcut, or say it to Siri ("New Seedboard board from text"). *New board from text* takes any text: a list (two lines or more, with or without bullets, indents for sub-points) becomes a mind map with the title in the middle; a single line or sentence becomes one sticky note. With no title, the board is named after the middle idea or the first line. Raycast runs these through its Shortcuts command. The search on your device (Spotlight) finds boards by name and by their first words; choosing one opens it.

## 3. Spec

**Menus (`App/Sources/Menus.swift`, `SeedMenus`; the Board menu and Undo/Redo stay in `BoardCommands`, BoardView.swift)**
- File (`CommandGroup(replacing: .newItem)`; no "New Window", one window as before): New Board ⌘N → `MenuDesk.choosingStarter` (the starter page, see below); New Blank Board ⇧⌘N → `AppModel.newBoard(.blank)`; Rename… → the board's own "Name of the board" question; Send to PARAGON… ⌘↩ → ends typing, opens the Send page; Share a Picture… → the board's PNG (the same picture as for PARAGON, written to the app's temporary folder as `<name>.png`) in the system's share choice (Mac: `NSSharingServicePicker` under the top bar; iPad: the share page); Remove Board… → the board's own "Remove …?" question.
- Edit: `CommandGroup(after: .pasteboard)` adds Duplicate ⌘D (`BoardSession.duplicateSelection`). On the Mac, Delete and Select All are the system's own lines; the drawing surface answers `delete:` and `selectAll:` (`BoardKeys`, `.onCommand`) while it has the keys — Delete only with something chosen on a board that can be changed, Select All only on a board that is not empty. The Delete KEY is still the board's own key handling (the menu line answers `delete:`, the key sends another command), so one press never removes twice. On iPad/iPhone a Select All ⌘A line is added: on the board it chooses everything, anywhere else it is passed to the text field that has the keys. The Cut, Copy and Paste lines are not touched.
- View: `CommandGroup(before: .toolbar)`: Zoom In ⌘+ (×1.25), Zoom Out ⌘− (÷1.25), Actual Size ⌘0 (zoom 1), Show the Whole Board ⌘1 (`fit`). The on-screen buttons keep their words (Smaller, Bigger, Show the whole board).
- Insert: lines from `MenuRules.tools` (7) and `MenuRules.moreShapes` (2) in SeedboardCore. A click adds the thing in the middle of the view, ready to type in (`BoardSession.add`); Arrow switches the arrow tool on or off, starting at the one chosen shape. Grey with no board or on a read-only board.
- The letter on an Insert line is a real key only when `MenuRules.lettersAreTools` says so: the drawing surface has the keys (`MenuDesk.keysBoard` is this board, the Mac window is the one typed in), no words are typed, nothing and no arrow is chosen, the board can be changed. In every other state the line has no key. Reason: a menu key must never be able to take a letter from words, whatever the system gives first — the menu or the text field.
- Board menu changes (BoardView.swift): "Copy the Chosen Things" and the three zoom lines moved out; To Do is grey with nothing chosen; Paste a List as a Mind Map is grey with no board, on a read-only board and while words are typed.
- Starter page for ⌘N (`StarterSheet`): the existing starter list (`StarterPicker`, now usable from other files) as a sheet with Cancel (Escape on the Mac). Identifiers: `starters.sheet`, `starters.cancel`; the rows keep `starter.<name>`.

**Space and a drag (Mac only, `SpaceHand` in Menus.swift)**
- Space is taken by the board only when the drawing surface has the keys, no words are typed, no text field is the first responder, and ⌘, ⌃, ⌥ are up. Otherwise the key goes where it went before.
- While Space is down: pointer = open hand; mouse down inside the board = closed hand; each drag step slides the view by the pointer's way (`BoardSession.pan`, so the board counts as moved by the owner). Mouse up: open hand; Space up: arrow. The press is never seen by the board's own drag handling, so nothing is chosen, moved or boxed.
- Space up without a drag, held under 0.5 s (`MenuRules.shortPress`), exactly one thing chosen (`MenuRules.spaceStartsTyping`): typing starts in it.
- The window or the app losing the keys while Space is down ends it.

**Opens where you left (`Core/Remember.swift`, `App/Sources/Remember.swift`)**
- Kept in the device's own settings (`UserDefaults`, key `seedboard.remembered`, JSON): `open` (id of the open board, absent on the home page) and `views` (board id → `scale`, `x`, `y`). `x`, `y` is the board point that stood in the MIDDLE of the room (rounded to 0.1), `scale` the zoom (rounded to 0.001) — the middle, so the same spot comes back in a window of another size. Never synced, never in a board file. No stored board field was added.
- Written: when another board is opened or the board is closed, 0.6 s after the view last moved, and when the app is left or quit. A view is only written once the owner has moved or zoomed the board; before that the board keeps opening shown whole. Views of boards that are no longer on the device are dropped at each write.
- At the start (`AppModel.load`): `Reopen.board` gives the board to open — the remembered one if it is on the device, else none (home page). A link, a Shortcuts action or a Spotlight result that started the app wins over it.
- Whenever a board is opened: `Reopen.view` gives its view; `Viewport.comeBack` sets the zoom (kept within 20 %–300 %) and holds the remembered spot in the middle while the room still settles (window finding its size, side bar), until the owner slides or zooms (`Viewport.pin`, `holdPin`).
- Launch words win: with any of `-sampleData`, `-board`, `-pick`, `-pickAll`, `-send`, `-sendNow`, `-settings`, `-starters` nothing is brought back (`Reopen.sceneWords`); with `-sampleData` nothing is written down either.

**Shortcuts actions (`App/Sources/Intents.swift`, App Intents, iOS 17 / macOS 14)**
- `NewBoardFromTextIntent` "New board from text": Title (optional), Text (several lines). Board made by `Outside.board(title:text:)` in SeedboardCore — the same rule as pasting: two or more non-empty lines and a readable outline → mind map (`addMap`; one top line = the middle idea, several = the title, or "Ideas", in the middle); else one sticky note; no text → empty board. Name: the title, else the middle idea, else the first line (40 letters at most). Gives the new board back, so a shortcut can go on with it.
- `NewBoardIntent` "New board": Start with = Blank board (default), Mind map, Flow, Pros and cons, Plan in steps.
- `OpenBoardIntent` "Open board": Board = one of the boards, offered newest first, found by name (`Outside.boards(named:)`: the exact name, then names that begin with the words, then names that hold them). Opens it the way a link is followed, so a board removed meanwhile is said so in the app.
- All three open the app and run inside it, through the app's one model (`AppModel.shared`; `AppModel.add` gives the colour, a name of its own "… 2", saves through the store and opens). There is no second writer. They wait until the boards are read, so they work when the app was not running.
- `SeedboardShortcuts` (`AppShortcutsProvider`): the 7 phrases above. The board names Siri offers are refreshed when the list of names changes.

**Search on the device (`App/Sources/Spotlight.swift`, Core Spotlight)**
- One entry per board: id = the board's id, name = the board's name, description = the first words (`Outside.searchWords`: every thing's words in the order made, one line each, joined by " · ", cut at a whole word at 300 letters, then "…"; an empty board shows its count line), never expiring.
- Told 2 s after the list of boards last changed (a board is saved 0.5 s after a change), only for boards whose time of last change differs from what was told before (`Outside.searchPlan`; kept in `UserDefaults`, key `seedboard.searchTold`), on a background task. Boards no longer in the list are taken out of the search. With `-sampleData` nothing is told.
- Choosing a result opens the board through the same path as a `seedboard://board/<id>` link (`onContinueUserActivity`).

**Data tests added (9, `swift test` now 140, all green):** `RememberTests` (6): what comes back at the start and that launch words win; storing and forgetting; a reopened view holds its spot while the room settles until the owner moves it; words from outside become a map or a note; the search's first words and what changed; finding a board by name. `MenuRulesTests` (3): the Insert lines and letters; when a letter is a tool; short press of Space.

## 4. For the lead

**Builds:** both compile (iOS Simulator and macOS, the two commands of BUILDERS-0.2). The Mac test bundle also compiles (`build-for-testing`); nothing was launched or run.

**Entitlements / Info.plist:** none needed, nothing changed in `project.yml` or `App/Config`. App Intents are found at build time by themselves — checked in the built Mac app: its `Metadata.appintents` lists the 3 actions, the Board entity, the starter list and the 7 phrases. Core Spotlight needs no entitlement.

**Screen test (written, not run):** `UITests/MenuUITests.swift` — `testTheStarterPageShowsItsChoicesAndCancel` (all devices, launch word `-starters`) and `testTheMacMenusListTheToolsAndTheZoom` (Mac only; opens Insert, View and File by their names).

**Launch word for pictures:** `-starters` (with `-sampleData`) shows the starter page of File ▸ New Board. The menus themselves need a click to be photographed.

**Shared files I touched (small hunks):**
- `SeedboardApp.swift`: the model is `AppModel.shared` (one model for the window and for actions that start the app); `SeedMenus(model:)` in front of `BoardCommands()` on both platforms; `.modifier(OutsideDoors(model:))` on the root.
- `AppModel.swift`: 2 lines in `load()` (bring the last board back); `newBoard(_:)` now calls the new `add(_ made: Board)` which holds its old body unchanged.
- `BoardSession.swift`: one new method `comeBack(to:)`.
- `BoardView.swift`: one `.modifier(MenuAsks(…))` line after `.focusedSceneObject`; in `BoardCommands` the first line (Copy the Chosen Things) and the last four (Divider + zoom) are gone, To Do and Paste each got a `.disabled` line. Other builders' new Board-menu lines go between them without a clash in meaning.
- `CanvasView.swift`: one `.modifier(BoardKeys(session:has:))` line after `.onKeyPress`. Nothing in the drag code or in `handleKey` was changed.
- `RootView.swift`: `StarterPicker` lost the word `private`.
- `Core/Viewport.swift`: one stored field `pin` and one line in `resized`.

**Watch when merging:**
- If the copy/paste builder REPLACES the Edit menu's pasteboard group, the Mac's own Delete and Select All lines disappear with it. They must then be put back as two buttons that send `delete:` and `selectAll:` (the board already answers both).
- If the home-page builder changed `StarterPicker`'s shape, `StarterSheet` in Menus.swift needs the same change (2 lines).
- `Guide.swift` and `SPEC.md` say ⌘0 shows the whole board: it is ⌘1 now, ⌘0 is Actual Size.

**SF Symbols:** the system's Shortcuts list REQUIRES a system symbol name for each phrase group (`text.badge.plus`, `plus.rectangle`, `rectangle.stack`). They show only in the Shortcuts app and Spotlight, never inside Seedboard. No `ICON-WANTED`.

**Left open / my choices:**
- The Insert letters show only while pressing them would make the thing (nothing chosen, board has the keys). I could not launch the app to see whether a plain-letter menu key is given to the menu before the text field; this way typing is safe either way. If a real run shows that typing always wins, `lettersAreTools` in Menus.swift can simply be `canChange`, and the letters show all the time.
- "Fold" is not in the Board menu (it was not there before; the brief says to keep what is there).
- No Share-sheet action ("Share" in the panel's line 26): the brief names three Shortcuts actions only. "New board from text" can be used from the Share sheet through a shortcut that takes the shared text.

**Only a real run can prove:**
1. Mac menus: Edit ▸ Delete and Select All turn black and act when the board has the keys, and stay with the words while typing; ⌘A, ⌘D, ⌘N, ⇧⌘N, ⌘↩, ⌘0, ⌘1 arrive; Share a Picture's choice appears under the top bar; Rename… and Remove Board… open their questions.
2. Space: the open hand shows and stays, the board slides, a short press still starts typing, Space still types a space in every text field and still presses a focused button.
3. iPad with a keyboard: the lines show when ⌘ is held; ⌘A in a name field chooses the words, not the board.
4. Reopening: the board, zoom and spot come back on Mac, iPad and iPhone after a real quit; on the iPhone the board (not the list) is in front.
5. Siri understands the phrases; the three actions show in Shortcuts and on the Action button; Raycast finds them through its Shortcuts command; an action run while the app is closed opens it on the right board.
6. Spotlight shows boards by name and first words on iPhone, iPad and Mac, opens the right board, and forgets a removed one.
