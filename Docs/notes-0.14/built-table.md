# Lane table — idea 25: a table

## What it does
A small grid of cells on an ordinary board. A new table is 3 columns x 3 rows, empty. The first row is the heading row (bold, on a light band of the table's colour). Thin grid lines; every column is as wide as its widest cell (at most 220 points, longer words wrap); every row as high as its highest cell. Text size 15 (the same as a shape's), day and night colours from Paint. The same painter draws the PDF and the picture for PARAGON.

## How you make one (exact words)
- Mac menu Insert > "Table" (grey on a read-only board, a timeline and a Who does what board).
- Shapes plate ("Add a shape": hold the Box tile or press its corner): a word line "Table" under the shapes. Id `plate.shape.table`.
- Right-click on empty board: "New table here" (plus mark, `menu.table`), lands where pressed.
- A new table is chosen (not typed in); its bar says what to do.

## Typing
- Two presses on a cell types in that cell in place (a green ring round the cell). Words, Return or Space on a chosen table types in the cell typed in last (else the first).
- Tab keeps the words and goes to the next cell (the first of the next row after the last of a row); after the last cell it ends. Return ends. Escape = Cancel (the cell goes back).
- Each cell is one step for Undo.

## The bar of a chosen table
"Add row", "Add column" (plus mark), "Remove row", "Remove column" (minus-circle mark; grey when only one is left), "Words", "Colour", "Duplicate", behind "..." the rest; "Remove". Ids: `sel.table.addRow`, `sel.table.addColumn`, `sel.table.removeRow`, `sel.table.removeColumn`. Same lines (without Words) in the right-click menu with `menu.` ids, plus Colour, Copy, Cut, Duplicate, Remove.
Add row / Add column put the new one after the row / column of the cell typed in last, else at the end. Remove row / Remove column take the one of the cell typed in last, else the last. A table keeps at least 1 row and 1 column (max 60 rows, 20 columns). No tick / to-do on a table.

## PARAGON, search, outline
- Note text: a table is a plain list under "Notes" (and under its frame's heading): `- <top-left cell or "A table">` then `  - Row heading — Column heading: words` for each filled cell. Missing headings say "Row 1", "Column 1".
- Search (board list, device search): every cell's words are found. "Copy as outline" has the same list. Counts as ONE thing in the board's line ("1 idea").
- No change in PARAGON.

## Core
`Table14.swift` (TableRules, TableSpot, Item.searchableWords); `Board.add(.table)` makes 3x3. Tests: `Table14Tests` (5, all green, 515 in all). Screen test `UITests/Table14UITests` (built, not run; Mac/iPad: the plate corner takes presses).

## Does NOT do
No merged cells, no column dragging, no cell colours, no arrows tested into cells, no number formulas. The iPhone plate corner is hold-the-tile only (as for shapes). Not seen on a screen (no simulator allowed): layout, ring, band colours by night, field position at zoom.

## Shared files touched
CanvasDraw.swift (the fit and draw stubs, `editingCell`), CanvasView.swift (double press, Tab, field on the cell, painter.editingCell), BoardSession.swift (cell typing blocks: `cell`, `lastCell`, `cellWanted`, add() selects a table), BarActions.swift (table lines + empty menu line), Menus.swift (Insert > Table), ShapePlate.swift (Table line), Core: BoardEdit, Home (readableText), Outside, Finding09, Paragon, Outline. New: TableDraw.swift, TableSession.swift. No new stored field.
