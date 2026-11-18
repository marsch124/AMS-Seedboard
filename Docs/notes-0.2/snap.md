# Notes for 0.2 — builder "snap" (picks 11 and 14)

## 1. What's new

**Things fall in line (pick 11)**
- Before: a dragged thing stopped exactly where the finger or pointer let go. Two boxes were almost never on one line, so the arrow between them had a small kink.
- Now: while you drag, a thing catches its neighbours when it comes within 6 points on screen (at any zoom). It catches their left edge, middle and right edge, their top, middle and bottom, and the spot where the gap to its neighbours is the same as the gap between them. The nearest catch wins; sideways and up-down are caught separately.
- A thin pink line (1 point) shows what is in line; small pink marks show the gaps that are the same. They vanish when you let go.
- The same catch works while you size a thing (the edge you pull catches) and while you pull a new shape out of a green plus: a dashed outline shows where the new shape will land, and it lands in line with the shape it came from — the arrow is one straight piece.
- Holding ⌘ on the Mac while dragging switches the catch off.
- Ideas that hang in a mind map do not catch and are not caught (the map places them); a map's centre idea and everything else do. Frames catch by their edges only.
- Arrow keys move by 10 (with Shift 40) exactly as before, without a catch.

**A soft dot grid (pick 11)**
- Before: the board was one plain colour.
- Now: a soft dot every 24 points behind everything. Zoomed out, dots are left out so they never stand closer than 12 points on screen; below 40 % zoom they fade, at 20 % they are gone. The dots are never in the picture that goes to PARAGON or is shared.

**Line up, Even gaps, Same size (pick 14)**
- Before: with several things chosen the bar had 3 buttons (To do, Copy, Remove; on iPhone and iPad also Choose more).
- Now: 3 more — **Line up** (2 or more things), **Even gaps** (3 or more), **Same size** (2 or more shapes, notes or frames). Each is one step for Undo. On the Mac they are also in the Board menu.

## 2. How it works (guide text)

**Falling in line.** Drag a shape, note, text, frame or the centre of a mind map near another thing. When an edge or the middle comes close to a neighbour's, the thing jumps onto that line and a thin pink line shows it. When the gap to its neighbours is the same as the gap between them, small pink marks show the equal gaps. Let go and it stays there. The same happens when you pull the corner knob to size a thing, and when you pull a new shape out of a green plus — a dashed outline shows where it will land. On the Mac, hold ⌘ while dragging to place a thing freely. Ideas inside a mind map are placed by the map and do not take part.

**The dots.** The soft dots behind the board are 24 points apart and only there to help the eye. They are not part of the board: the picture sent to PARAGON or shared has none.

**Tidy several things.** Choose two or more things (Mac: Shift-press or drag a box round them; iPhone and iPad: Choose more). The bar then shows:
- **Line up** — puts them on one line. Spread more sideways than up-down they become a row (all at the same height, the average of their middles); otherwise a column.
- **Even gaps** — needs three or more. The two outer things stay; the ones between are moved so every gap is the same.
- **Same size** — gives every shape, note and frame the size of the largest one; each keeps its middle. Ideas and free text are as big as their words and stay as they are.
Ideas that hang in a mind map are left out. Undo takes each of these back in one step. On the Mac the three are also in the Board menu.

## 3. Spec

**Catching (Core `Snap.swift`, `Snap.move` / `Snap.resize`, `Board.moveSnapped` / `resizeSnapped` / `landing`)**
- Catch distance: 6 screen points = 6 ÷ zoom board points (`SnapShow.reach`). Reach 0 = no catch (⌘ held on the Mac, read from `NSEvent.modifierFlags` at every drag step).
- What is moved is taken as ONE box (the box round all moved things; ideas hanging under a moved centre are not counted in it).
- Sideways: the box's left and right edge each catch a neighbour's left or right edge; its middle catches a neighbour's middle. Up-down the same with top, bottom, middle. Edges never catch middles.
- Equal gaps (neighbours in the same row = lying over the box up-down by more than the reach; column likewise): (a) between the nearest neighbour on each side, when there is room: the gap on both sides is the same; (b) after two neighbours in a row: the gap to the nearer one equals the gap between the two; (c) the same before two neighbours.
- Per direction the smallest correction within reach wins (on a tie: edges/middles before gaps). The two directions are independent.
- Targets (`Board.snapTargets`): every thing that is not moving itself, except ideas with a parent; folded-away things are none. A frame is a target by its 4 edges only (no middle, no equal gaps); a moved set with a frame in it does not use its middle either. What a dragged frame carries moves with it and is not a target.
- Sizing: only an edge that moved against the size at the start of the drag catches, and only neighbours' edges. If the smallest size (44 × 28, frame 120 × 80) or the words hold the edge back, the guide is not shown.
- Pulling out of a plus (`Board.landing`): the new shape (the kind's default size, middle at the finger) catches like a dragged thing; the middle of the shape it comes from wins over every other catch, so `Route.path` gives 2 points (one straight piece). No landing when the plus belongs to an idea (adds an idea) or the finger is over another thing that is not a frame (the two are joined, as before).
- Not caught: ideas dragged inside a mind map; arrow keys (10 / 40 as before).
- One undo step per drag, as before (the catch happens inside the same live change).

**Guides (App `SnapShow.swift`)**
- Colour `Paint.guide`: #E0457B by day, #F58FB2 by night; 1 screen point wide, round ends.
- Line guide: through everything in line, 10 screen points past the outermost things at both ends.
- Gap mark: a line across each equal gap at the middle of where the two things lie side by side, with a tick of 8 screen points (±4) at each end.
- Landing outline: dashed (5 on, 4 off), 1.5 screen points, corner 9, in the chosen-green (`Paint.chosen`).
- Held in `CanvasView.snap`; emptied when the press ends, is taken away by the system, or a pinch begins.
- Drawn in `CanvasView` only, never by `BoardPainter` → not in `BoardPicture`.

**Dot grid (Core `DotGrid.swift`, drawn by `SnapShow.grid`)**
- A dot at every multiple of 24 board points (the board's zero point has one), 1.5 screen points wide at every zoom.
- Colour `Paint.dot`: #D5DAE2 by day, #2C2F36 by night.
- Thinning: the distance doubles (24 → 48 → 96) while it would be under 12 screen points: 24 from 50 % zoom up, 48 from 25 % to under 50 %, 96 below.
- Strength: full from 40 % zoom up, falling in a straight line to nothing at 20 %.
- Only dots inside the visible part are made (`DotGrid.dots(in:scale:)`); drawn straight after the background fill, under everything.

**Tidy (Core `Tidy.swift`)**
- `tidyable`: the chosen things without ideas that have a parent and without folded-away things.
- Row or column: row when the middles are spread at least as much sideways as up-down.
- `lineUp` (≥ 2): row → every middle to the average height of the middles; column → to the average sideways place. A map's centre takes its ideas along, a frame what lies wholly inside it (unless that was chosen itself).
- `evenGaps` (≥ 3): sorted by middle along the row/column; first and last stay; gap = (room between the outer two − sizes of the ones between) ÷ (count − 1); may be negative when there is no room (they then overlap evenly).
- `sameSize` (≥ 2 of box, round box, diamond, oval, note, frame): all take width and height of the one with the largest area (tie: the wider); middles stay. Ideas and free text are left out. (If a shape's words need more height than the largest has, it grows again downward, as shapes always do.)
- Buttons in the bar for several chosen things, after Copy: "Line up" `sel.lineUp` (shown from 2 tidyable), "Even gaps" `sel.evenGaps` (from 3), "Same size" `sel.sameSize` (from 2 sizeable). Marks `Glyph.new(.lineUp / .evenGaps / .sameSize)`, tint `Part.shapes`.
- Board menu (Mac, iPad keyboard): "Line Up", "Even Gaps", "Same Size" after "To Do"; greyed when there are too few. No key shortcuts.
- Session: `BoardSession.lineUp() / evenGaps() / sameSize()`, each through `change` = one undo step; nothing happens while words are typed.

**Stored fields:** none. Nothing new is written to a board file.

**Tests (Core, data only):** `SnapTests` 14, `DotGridTests` 3, `TidyTests` 4 — 21 new, 111 in all, all green.

## 4. For the lead

- **Launch arguments for pictures**
  - `-guides` — shows the pink guides of the chosen thing(s) where they stand (no drag needed). Example: `-sampleData -board cabin -pick Worth -guides` → a line through the row of shapes at "Worth it?" and one down to "Park it".
  - `-pickAll <words>` — chooses every thing whose words hold one of the comma-separated words. Example: `-sampleData -board cabin -pickAll "New idea,Worth,Make a plan"` → the bar with Line up, Even gaps, Same size.
  - The dot grid is in every board picture by itself (day and night).
- **Screen test:** none (no new screen). New identifiers: `sel.lineUp`, `sel.evenGaps`, `sel.sameSize`.
- **Icons:** `lineUp`, `evenGaps`, `sameSize` are already in `NewMark` — no ICON-WANTED.
- **Shared files touched (small hunks):** `CanvasView.swift` (one `snap` state, 2 draw lines, 3 resets, the move / size / plus cases of `update`, one line in `finish`), `BoardView.swift` (3 chip lines, 3 menu lines), `AppModel.swift` (`-pickAll`). `CanvasDraw.swift`, `BoardSession.swift`, `Board.swift`, `Route.swift` untouched. New files: Core `Snap.swift`, `DotGrid.swift`, `Tidy.swift` + 3 test files; App `SnapShow.swift`.
- **If pick 7 gives knobs on four corners:** `Snap.resize` already catches whichever edges moved (it compares the new size with the old), so nothing has to change there.
- **Left open / seen, not fixed (outside my brief)**
  - A shape that gets taller as its words are typed grows downward, so its middle moves and a straight arrow gets its kink back. A fix would be to grow it evenly up and down (`Lettering.fit`).
  - A shape pulled out of a plus takes the kind's standard size; one made by pressing the plus takes the size of the shape it comes from.
  - ⌘ switches the catch off on the Mac only; an iPad with a keyboard has no such key yet.
  - `Core/BoardTests.swift` and `Core/StartersTests.swift` are stray copies of the tests in `Core/Tests/…` (never built).
- **Only a real device can prove**
  - How the 6-point catch feels under a finger on iPhone and iPad (too sticky / too weak), and that guides are easy to see by day and by night.
  - That the dots look soft, not busy — especially by night (#2C2F36 on #17181B) — and that dragging stays smooth on a large Mac window at 50 % zoom (the most dots: one every 12 points).
  - ⌘ held during a drag on the Mac; the dashed landing outline while pulling out of a plus.
  - Nothing was launched or looked at: both apps compile and the rules are tested, the look is unseen.
