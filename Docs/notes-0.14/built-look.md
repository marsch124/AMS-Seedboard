# Built: lane "look" (ideas 15, 17, 19, 26)

Core: `Core/Sources/SeedboardCore/Look14.swift` (rules), `Viewport.fitChosen` in `Viewport.swift`; tests `Look14Tests.swift` (4 tests). App: `App/Sources/Look14.swift`; small marked blocks in BarActions, BoardSession (fit-to-chosen, today), CanvasDraw (`Lettering.style` for .text), CanvasView (LineField inserts at the cursor), MapOrder (keyboard bar), Menus.
No new stored field (uses `Item.textSize`, groundwork). No screen test (no new screen).

## 15 Copy the look
- What it does: with ONE thing chosen, "Copy look" keeps its colour, shape kind (flowchart shape) and text size (free text) on this device only (not in the board, not in iCloud). With one or several things chosen and a look kept, "Paste look" puts it on all chosen things in ONE undo step, only what fits each kind: a note stays a note (colour only, from the note colours); a shape takes colour and shape kind from a shape; a mind-map branch idea takes the branch colour (the main idea takes nothing); a frame and a sketch take the colour; a free text takes only the text size from a free text; pictures, doors, timeline rows take nothing. Colour is never given to something whose palette lacks it (e.g. "grey" is not a note colour, so a note skips it).
- Words: bar button "Copy look" (when one thing with a look is chosen); "Paste look" (only shown when a look is kept and at least one chosen thing can take part of it). Message after copying: "Look copied" (2 s).
- Where: bar (behind "…" when narrow, drop 7), right-click / press-and-hold menu (same lines, before Remove), Mac Edit menu "Copy Look" ⌥⌘C and "Paste Look" ⌃⌥⌘V.
- KEY CHANGE FROM BRIEF: ⌥⌘V is already "Vote Dot" (Edit menu), so Paste Look is ⌃⌥⌘V (Control added). Tell the texts helper.
- Marks: Copy look uses the existing Copy mark, Paste look the existing Paste mark (word beside each, except on a narrow iPhone where the bar shows the mark only; the words are in the "…" list).
- Identifiers: `sel.copylook`, `sel.pastelook`, `menu.copylook`, `menu.pastelook`.
- Core rule: `Board.lookToCopy`, `Board.canTakeLook`, `Board.pasteLook` (Look14.swift); test `testPasteLookGivesEachKindOnlyWhatFits`, `testTextSizeOnlyFromFreeTextToFreeText`.
- Does NOT: copy text, size, position or lines; not offered on timelines / "Who does what"; no "paste look" for one thing on itself after copy only matters if it can take it (same colour still counts as fits); not kept after the app closes.

## 17 Big and small words on free text
- `Item.textSize`: "title" = 28 pt semibold, nil = 17 normal, "small" = 13. Measuring, drawing and typing in place all use it (`Lettering.style`). Same for everyone who opens the board. The text sent to PARAGON is unchanged.
- Words: bar button "Size" (shown when a free text is chosen; list: "Title", "Normal", "Small", the one in use switched on). In the menu: "Size" with the same list (shown in "More"-style position after the arrow line, inside the right-click menu).
- Identifiers: `sel.size`, `sel.size.title`, `sel.size.normal`, `sel.size.small` (menu: `menu.size…`).
- Does NOT: change ideas, notes or shapes; no other sizes; one chosen free text only in the bar (a menu with several chosen has no Size line).

## 19 Zoom to the chosen things
- The board glides (0.30 s, same as "Show the whole board") so the chosen things fill the screen with a margin (60 pt sides, 110 pt top/bottom); zooms in up to twice life size, out down to 20 %.
- Words: bar "Zoom to these" (behind "…" first when narrow, drop 8); menu line "Zoom to these"; Mac View menu "Zoom to Chosen" ⌘3.
- Identifiers: `sel.zoomchosen`, `menu.zoomchosen`.
- Core rule `Viewport.fitChosen` (test `testFitChosenFillsTheRoomWithAMargin`).
- Does NOT: work on timelines or "Who does what" (they place themselves); not for a chosen arrow alone.

## 26 Today's date while typing
- Puts "19 Nov 2026" (day, month in three letters, year; English, same on every device) where the cursor stands (replaces a chosen piece of words); the cursor goes after it. On systems older than iOS 18 / macOS 15 (no cursor known) it goes at the end of the words.
- Words: keyboard bar button "Today" (iPhone/iPad, left of "Done"; VoiceOver: "Insert today's date"); Mac Edit menu "Insert Today's Date" ⇧⌘D (only while typing).
- Identifier: `board.key.today`.
- Core: `DateWords.short`, `Typing.insert` (test `testTodayInWordsAndInsertAtTheCursor`).
- Does NOT: offer other date forms ("Thu 19 Nov"); the word "Today" has no mark beside it.

## Launch words for pictures
None added.

## Could not see
Nothing run (no simulator, no app). Not seen: how the bar looks with the new buttons on a narrow iPhone; the glide on a real board; the keyboard bar "Today" on iPad.
