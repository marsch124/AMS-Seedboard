# 0.11 lane "safety" — items 1, 2, 4, 10, 11, 17

## 1. What's new
- 1: Before, a thing or arrow that could not be read was left out and the next save wrote the board without it, silently. Now the file as it was is kept once under Earlier versions before anything is saved over it, and a line says so: "1 thing on “Plan” could not be read. The whole board as it was is kept under Earlier versions." (plural: "3 things on …").
- 2: Before, an unreadable "created" time counted as 1970. Now it takes the file's own date, so "newer wins" stays right.
- 4: Before, a thing placed absurdly far away (e.g. 1e308) could stop the dot grid and the timeline. Now positions are held to within 100,000 points of the middle, sizes to 0–20,000, and the grid and timeline never turn a giant number into a whole number.
- 10: Before, importing a board from a newer Seedboard said "was not a board". Now: "1 board was made by a newer Seedboard — update Seedboard first."
- 11: Before, a damaged seedboard:// link did nothing. Now a red flash says "That board link is not complete."
- 17: one test of about ten damaged files (cut off, wrong types, huge numbers, nulls, broken arrows).

## 2. How it works
If something in a board file cannot be read, Seedboard keeps the whole file as it was under Earlier versions (once), shows a line in Settings (the save warning) and in the flash at start, and carries on with everything that could be read. Boards from a newer Seedboard are told apart from files that are no board at all.

## 3. Spec
- Core `Safe11.swift`: `SafeNumber` (`farthest` 100000, `biggest` 20000, `int`, `position`, `size`), `Board.unreadableCount(in:)`, `Board.fileDateKey` (decoder.userInfo), `SafetyWords` (`damaged`, `importSkipped`, `incompleteLink`).
- `Item.init(from:)` cleans x, y, w, h. `DotGrid.dots` returns [] for a non-finite rect or more than 400,000 dots. `TimelineGeometry.day(atX:)`, `row(atY:)`, `days(forDrag:)` use `SafeNumber.int`.
- BoardStore: `interpret(_:fileDate:)` keeps the original bytes with `setAside(..., "seedboard")` and reports `.damaged`; `warning` shows it (after write problems). Dates: file's modification date given in readLocal / readCloud / parked versions.
- No stored field added; format stays 7.

## 4. Pictures
Nothing to see (a damaged file is needed).

## 5. Not done / doubts
- The line lasts for this run of the app (no stored field allowed); after a restart the board is already saved without the lost things, only Earlier versions remembers.
- The board stays editable (not read-only). Everything unreadable is in Earlier versions as a whole board.
- Dates read by `board(from:)` paths other than the disk readers (import) still use 1970 when unreadable.
- Timeline year 0001/9999 (item 3) not touched.
- Shared files edited: Board.swift (small), DotGrid.swift, Timeline.swift, BoardStore.swift, BringBack.swift, AppModel.swift (one guard).
