# 0.19 canvasa — picks 9, 17, 18

## 9 Double-tap on empty board = new sticky note
- Before: Mac double-click on empty board already made a sticky note (typed at once). iPhone and iPad: two presses showed the whole board (`Finger.twoPressesFit`, true on iOS).
- Now: `Finger.twoPressesFit = false` (FingerSizes.swift) so iPhone, iPad and Mac all make a sticky note (middle at the press, typing starts at once). The code is the existing `session.add(.note, at:)`, which already refuses read-only boards and boards that place themselves (timeline, Who does what). Taps, holds, drags, the Pencil: untouched.
- Cost: the iPhone/iPad "two presses = show whole board" is gone (still: Show the whole board button / ⌘1 on the Mac). The empty-board hint "or double-click anywhere for a sticky note" stays Mac-only (not changed; Guide not touched). DECISION for lead: accept losing the iPhone/iPad fit gesture? One switch brings it back (but then pick 9 is Mac-only).
- Texts to fix later: SPEC line 456, 1109, 1183 and the Guide lines saying iPhone/iPad two presses show the whole board; TouchUITests test `testTwoPressesOnEmptyBoardShowTheWholeBoard` was changed to expect "1 note" in `board.count` (not run).

## 17 Read mode
- One press freezes the board: dragging a thing now pans the board, no typing, no adding, no undo/tool pill/handles (it simply counts as read-only: `BoardSession.readOnly` is now also true while `readMode`). Scrolling and zoom work. Choosing a thing still works.
- Top pill: symbol "book" + "Read mode" + full-colour "Done" button (ids `readmode.pill`, `readmode.done`). It replaces the chosen-bar row at the top while on.
- Button: board More menu "Read mode" / "Leave Read mode" (`more.readMode`, with book symbol); Mac View menu "Read Mode" / "Leave Read Mode", key ⌥⌘R (was free; checked all keyboardShortcut("r")). Not offered on boards that cannot be changed (newer-version boards) or starter drafts.
- Kept per board on this device: UserDefaults key `readMode.<board id UUID string>` (true or absent). Not in the board file.
- Entering read mode ends typing and an arrow in progress. The "made by a newer Seedboard" banner now tests `!board.canBeChanged` (was `readOnly`).
- Not seen: nothing run on screen.

## 18 Board background colours
- Before: More > Background (Plain / Dots / Squares) only. Now unchanged, plus one new line right under it: "Background colour…" (`more.paper`; pale on read-only / timeline etc.) which opens a small page "Background colour" with 4 round swatches with words: Plain, Paper, Warm grey, Night blue (`paper.swatch.plain|paper|warmGrey|nightBlue`), a line "It goes with the dots or squares of Background.", and a full-colour Done (`paper.done`; Return = Done, Escape closes). A swatch applies at once as one undo step (`setPaper`, refused on read-only/Read mode/timeline). Chosen swatch has a 3-pt ring in the Boards colour. Swatches show the real colour for the current day/night look.
- Colours in ONE enum `PaperColour` (Core/Sources/SeedboardCore/Paper19.swift): Paper day FBF7EE night 1F1C17; Warm grey F0EEEA / 252321; Night blue EDF1F7 / 151C2C. Plain = as before (F6F7F9 / 17181B). Stored in `Board.paper`.
- Drawing: `Paint` got an optional `paper` and `Paint.canvas` returns the paper colour, so the board fill, the safe-area background, arrow-word patches, tick-box rings and the Focus dimming all match. Dots/squares draw on top as before. Text, notes and lines use adaptive colours, and all three papers are light by day and dark by night, so they stay readable (not checked by eye).
- Picture/share export (BoardPicture.swift): before white; now white if no paper, else the paper's DAY colour behind the picture.
- Not covered: timeline and "Who does what" boards (not offered there); board thumbnails in the list and the Kept page still draw the plain colour.
- Symbols: Marks19Canvas.readMode = "book" (App/Sources/Canvas19.swift).

Signs: "book" symbol + "Read mode" pill = the board is frozen for reading (Boards colour). Paper colour swatches = background colour of this board only.

Tests: Core/Tests/SeedboardCoreTests/Canvas19Tests.swift (2), UITests/Canvas19UITests.swift (compiles only, not run). Files: Canvas19.swift (new), Paper19.swift (new), BoardSession, BoardView, CanvasView, CanvasDraw, BoardPicture, FingerSizes, MarksViews, Menus, TouchUITests.
