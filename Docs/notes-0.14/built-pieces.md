# Lane "pieces" — ideas 22 and 27 (built)

## 22 A brainstorm timer
Does: a small pill at the top of the board with a thin ring that fills and the time left. Nothing is saved; leaving the board (or opening another) stops it.
- Where: board More menu "Brainstorm timer" (ordinary boards only, not timeline / Who does what); Mac View menu "Brainstorm Timer".
- Words: before it starts "Brainstorm", "5 min", "10 min", "Cancel"; running "4:12 left" and "Stop"; at the end "Time!" for 4 seconds, then the pill goes. Choosing the menu line again while it runs offers the choices again (restart).
- End: one soft tap (`Feel.timeUp()`, respects Settings "Taps you feel") and one `TickSound.play()` (the soft pling, follows its own "Tick sound" switch: off on the Mac at first). Say if the sound should go.
- Ids: `more.brainstorm`, `timer.pill`, `timer.min.5`, `timer.min.10`, `timer.cancel`, `timer.left`, `timer.stop`, `timer.timeUp`.
- Rule in Core: `BrainstormTimer` (Pieces14.swift).
- Not: no pause, no custom length, no sound file, no background notification when the app is left.

## 27 Saved pieces
Does: with things chosen on an ordinary board, "Save as a piece…" asks for a name and keeps them (arrows between them; an idea's whole branch comes along). More ▸ "Add a piece…" opens the page "Pieces"; pressing a piece drops a copy (new ids) in a free spot near the middle of the screen, chosen, one undo step, and says "Added the piece “Name”.".
- Where: chosen-things bar (several chosen: button "Save as a piece…", moves behind "…" when narrow; one thing chosen: behind "…"), right-click / press-and-hold menu of a thing or of several ("Save as a piece…", after Copy/Cut/Duplicate); More menu "Add a piece…"; Mac Insert ▸ "Piece…". Mark on the bar button: the Starter mark (`seedStarter`) — please check that fits the sign rule.
- Save sheet: heading "Save as a piece", field "Name" (starts with the first chosen idea's words), line "5 ideas with the arrows between them. You can add the piece to any board later.", buttons Cancel / Save. After saving: "Saved as the piece “Name”.".
- Pieces page: heading "Pieces", count line under each name ("5 ideas", "3 things", "1 idea"), footer "Press a piece to add a copy of it to this board.", empty: "No pieces yet. Choose some things on a board, then press “Save as a piece…”.", buttons Close and Edit. Edit mode: names editable, "Remove" / "Keep" per piece, Cancel / Done, footer "Rename a piece or mark it to remove. Removed pieces are kept for 30 days."
- Stored like own starters: `Pieces/<id>.seedpiece` beside Starters, on the device (Application Support) and iCloud Documents; newer `changed` wins; removed ones keep their file 30 days. Simpler than starters: no working copy, no "SafetyCopies" set-aside of replaced versions; an iCloud file not yet arrived or unreadable is never written over; iCloud "<id> 2" copies are ignored.
- Ids: `more.addPiece`, `sel.savePiece` / `menu.savePiece`, `pieceName.sheet`, `pieceName.field`, `pieceName.cancel`, `pieceName.save`, `pieces.page`, `pieces.list`, `pieces.empty`, `pieces.row.<id>`, `pieces.edit`, `pieces.close`, `pieces.cancel`, `pieces.done`, `pieces.name.<id>`, `pieces.remove.<id>`.
- Rules in Core: `PieceShelf.cut`, `.drop`, `.save/.rename/.remove/.purge`, `PieceEntry.countLine/newer`, `PieceFileName`.
- Not: no pieces on timeline / Who does what boards; no reordering; no thumbnails; pieces with a picture keep the picture's file reference only (a picture dropped into another board whose picture store lacks it may not show — same as copy/paste today); no stored field added to boards (no format change).

## Tests
Core `Pieces14Tests` (3 tests). Screen test `UITests/Pieces14UITests` (built, not run).
## Shared files touched
Feel.swift (new moment `timeUp`), BoardView.swift (pill, More lines, host, stop on leaving), Menus.swift (View ▸ Brainstorm Timer, Insert ▸ Piece…), BarActions.swift (`savePiece`). New: PiecesPage.swift, PieceStore.swift.
## Could not see
Neither the pill nor the page was looked at on a screen; the bar button's room on the iPhone bar was not checked.
