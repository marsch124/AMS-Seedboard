# Notes for 0.2 — builder "pencil" (pick 2: drawing by hand)

Nothing here was run on a device, a simulator or the Mac's screen (the builders' rule). Both apps compile, the rules are tested as data (11 new tests), the made-up sketch board was painted once outside the app to look at its lines.

## 1. What's new

### Pick 2 — drawing by hand

- **You can draw on a board.** Before: a board held ideas, shapes, notes, text, frames and arrows — nothing drawn by hand. Now: lines drawn with the Apple Pencil, a finger or the mouse lie on the same endless board, between everything else.
- **The Pencil just draws.** On the iPad, put the Pencil on empty board and it draws at once — no tool to choose first. On a shape, a note or an idea the Pencil still chooses or moves it, as a finger does. A finger never draws by itself; it slides the board as before.
- **A new tool, Draw** — the 8th in the tool row (before: 7 tools). While it is on, a finger (iPhone, iPad) or the mouse or trackpad (Mac, iPad) draws too, on empty board and across things. Two fingers still slide and zoom. Press the tool again, press Done, or press Escape to leave it.
- **A small plate while Draw is on:** Pen or Rubber, three thicknesses (thin 2 points, medium 4, thick 7.5), and 10 colours (plain ink first, then the 9 board colours), and Done. The thickness and colour you used last come back next time on that device.
- **The rubber takes whole lines.** Rub across a line and the whole line goes. Everything rubbed out in one go comes back with one Undo.
- **Lines that belong together are one sketch.** Lines drawn within 5 seconds of each other and no more than 40 points apart become one sketch; a pause or a jump starts a new one. A sketch is chosen, moved, copied, put in a frame, lined up, removed and undone like a sticky note, and it travels to your other devices the same way. Dragging its corner knob stretches its lines.
- **A sketch is caught only on its lines,** never anywhere in its box — so a note or a word inside a drawn ring is still easy to press. A finger catches a line within 22 points on screen, the mouse or Pencil within 6.
- **One line, one Undo.** Each line you draw is one step.
- **The Pencil feels its pressure:** pressing lightly makes the line up to 35 % thinner, pressing hard up to 35 % thicker.
- **The Pencil's double-tap** (and squeeze on a Pencil Pro) follows what you chose in Settings › Apple Pencil: "switch between tool and eraser" swaps pen and rubber; "show colour palette" opens or closes the Draw plate; "off" does nothing. When the Pencil rubs and no plate is showing, one small line says "The Pencil rubs out" with a Pen button.
- **"Only Draw with Apple Pencil"** (iPad Settings) is honoured: with it on, a finger slides the board even while the Draw tool is on, and the plate says so.
- **Day and night:** a line keeps a colour name, not a fixed colour, so it changes with day and night like everything else. Plain ink is dark by day and light by night.
- **PARAGON:** the picture shows the sketches. In the note or project text a sketch is one plain line under Notes: "A sketch (see the picture)". A sketch never carries the To do tick and never becomes a task.
- **The board's count line** now counts sketches: "2 notes · 3 sketches".
- **Older app:** a board with a sketch on it opens in Seedboard 0.1 to look at, not to change (the rule for things an older app does not know).
- **Writing into a box with the Pencil (Scribble):** nothing had to be built — the place where you type in a box, note or idea is an ordinary text field, so the iPad's own Scribble should work there once the field is open (two quick presses on the thing first). Only a real iPad can show it.

## 2. How it works (guide text)

**Drawing**
- On the iPad with the Apple Pencil: just draw on empty board. The Pencil on a shape, note or idea chooses or moves it.
- Drawing over a sketch you already made adds to it — the Pencil draws on, over and across its own lines. To choose a sketch with the Pencil, tap one of its lines; then you can drag it. A finger chooses and moves a sketch at any time.
- With a finger, the mouse or a trackpad: press Draw (the last tool at the bottom). Now a drag draws, also across things. Two fingers still slide and zoom the board. Press Draw again, Done or Escape when you are finished.
- The plate above the tools: Pen or Rubber; Thin, Medium, Thick; the colours. Choosing a thickness or a colour takes the pen again.
- Rubber: rub across a line and the whole line goes. A sketch with no lines left disappears.
- Lines drawn shortly after each other (within 5 seconds) and close together (within 40 points) are one sketch. Wait a little longer, or draw somewhere else, and a new sketch begins.
- A sketch is pressed on one of its lines. Drag it to move it, drag the small knob at its corner to stretch it, Copy and Remove are in the bar at the top. Undo takes back one line at a time.
- Double-tap the Pencil (or squeeze a Pencil Pro) to swap pen and rubber — or whatever you chose in Settings › Apple Pencil.
- If "Only Draw with Apple Pencil" is on in the iPad's Settings, fingers never draw.
- Sent to PARAGON, a sketch is in the picture; the text says "A sketch (see the picture)".

**Lines the writer must change** (`Guide.swift`, `SPEC.md`): the list of tools (7 → 8, Draw last); "With the Pencil" in the touch builder's guide part ("The Pencil chooses and moves things like a finger" → add: on empty board it draws); the count line's words (sketches added); the list of what a board holds; the PARAGON note's Notes section.

## 3. Spec

### Stored (format 2 — the number was not changed by me)
- New kind word: **`drawing`** (`ItemKind.drawing`, word "Sketch", `countLine`: "1 sketch" / "n sketches").
- New item field: **`strokes`** (optional list; written only for a drawing). Each stroke: **`colour`** (palette name; "" = plain ink), **`width`** ("thin" | "medium" | "thick"; another word is drawn medium and written back as it was), **`points`** (flat list x0, y0, x1, y1 … from the drawing's corner, rounded to 0.1), **`pressure`** (optional; one number 0…1 per point, rounded to 0.01; only when the Pencil drew it). Unknown fields inside a stroke are carried. A list with an odd number of numbers loses its last one; a pressure list of the wrong length is dropped.
- `StoredFieldsTests` golden list for format 2: `strokes` added to the item names. The stroke's own names are pinned in `InkTests.testADrawingGoesToTheFileAndBackAndAnOlderFileStillOpens`.
- An older app: the kind is unknown and the format is 2 → read-only, kind word and `strokes` written back untouched (existing rule).
- Device only (UserDefaults, not iCloud, not used with `-sampleData`): `ink.width`, `ink.colour`.
- No `text`, no tick: `beginEdit` refuses a drawing; `toggleTodo` leaves drawings out; the To do, Colour and Words chips are not offered (only Copy, Choose more, Remove).

### Rules — `Core/Sources/SeedboardCore/Ink.swift` (all pure)
- `InkWidth`: thin 2, medium 4, thick 7.5 board points.
- Box: the box of all points (rounded to 0.1) with `Ink.margin` = 6 round it; a dot is 12 × 12. `Board.addStroke(points:pressure:colour:width:to:)` makes a new drawing on top of everything or grows the given one (older strokes stay where they were on the board). Points that are not numbers are dropped; a press that went nowhere is one point.
- Thinning: `Ink.thin` — Ramer–Douglas–Peucker, pressure as a third direction (0.1 of pressure weighs 0.3 points). Tolerance `Ink.tolerance(scale)` = 0.4 screen points, at most 0.5 board points. (The made-up floor plan: 11 lines, 140 points, the whole board file 4.3 kB.)
- Joining: `Ink.joins` — the new stroke began ≤ 5 s (`joinSeconds`) after the last stroke ended AND its box is ≤ 40 points (`joinReach`) from the box of the drawing that stroke went into (`Board.drawingToJoin`; the drawing must still be there). The time is kept by the open board (`InkDesk.lastDrawing`), not stored.
- Resizing: `Board.resize` → `scaleDrawing`: the lines stretch with the box, thickness stays, margin stays 6, never less than 4 points of drawing a side, a flat line stays flat. "Same size" leaves drawings out (`sizeable`).
- Pressing: `Board.hit` exact = within 2 board points of a line's edge; `hit(_:scale:least:)` = within `max(least / 2, 6)` screen points (finger 22, mouse / Pencil 6) of a line's edge, topmost drawing first, before the small-thing rule; never the empty inside of the box. The choosing box takes a drawing by its box.
- Rubber: `Board.strokes(near:from:reach:)` — every stroke within `Ink.rubber` = 10 screen points of the rubber's way since the last sample (so a quick rub cannot jump over a line); `removeStrokes` — whole strokes go, the box shrinks to what is left, an empty drawing is removed with its arrows.
- Width under pressure: `Ink.width(base, pressure)` = base × (0.65 + 0.7 × min(p / 0.6, 1)^0.7): 0 → −35 %, about 0.25 → the chosen width, 0.6 and more → +35 %. No pressure → the chosen width.
- The drawn line: `Ink.runs` — straight pieces, every corner rounded by a quadratic curve whose ends lie on the two pieces and whose control point is the corner. The curve's reach along each piece = min(half the shorter piece, 2 × 0.6 / sin(half the turn)): a gentle bend is rounded mid-point to mid-point (smooth), a sharp corner stays within 0.6 points of the drawn corner. With pressure the line is cut into runs of one width, in steps of max(0.2, 6 % of the chosen width); a long straight piece whose pressure changes is cut so no step shows.
- PARAGON: `noteBullets` adds "- A sketch (see the picture)" in board order ("(on the board)" when no picture goes along); `ParagonExport.label` of a drawing = "A sketch" (for an arrow joined to one).

### Painting — `App/Sources/InkDraw.swift`
- `InkDraw.stroke` paints the runs with round ends and round joins; `BoardPainter.drawInk` paints a drawing (called from `drawItem`), so the live board, the Mac, the home pictures and the PARAGON picture are one code. Colour: `InkDraw.colour` = `paint.line(name)`, "" = `paint.ink`. A chosen drawing has the usual green outline and only the size knob (`handles`).

### Hand — `App/Sources/InkDesk.swift`
- `BoardSession.ink` (`InkDesk`): `on` (Draw tool), `rubber`, `width`, `colour`, `wet` (`WetLine`).
- `inkClaims` (TouchLayer's `InkHook.claims`, once per touch): Pencil → Draw on: always; off: not while the arrow tool is on, and only where `inkBare` — no arrow end, no handle of the one chosen thing, no thing (drawings that are not chosen are left out), no arrow within 9 screen points. Finger → only with Draw on and not `InkDesk.pencilOnly` (iPad idiom and `UIPencilInteraction.prefersPencilOnlyDrawing`). Pointer (iPad mouse / trackpad) → only with Draw on. Never on a read-only board or a timeline.
- `inkBegan`: ends typing, clears the choice, takes the keys; pen → `wet.begin`; rubber → `liveStart` + first rub. `inkMoved(real, predicted)`: all in-between samples are added, the predicted ones are drawn and replaced each time. `inkEnded(cancelled)`: pen → thin, join or new, `change { addStroke }` = one undo step; rubber → `liveEnd(keep:)` = one undo step; cancelled (second finger, system) → nothing kept.
- Pencil tap with no tool on (moved ≤ 4 screen points, ≤ 0.35 s) on a drawing's line (6 screen points) chooses that drawing instead of leaving a dot. Elsewhere a tap leaves a dot.
- Mac: `inkMouse` in `CanvasView.dragGesture` — a drag that begins while Draw is on is a line (or the rubber), all the way to its end.
- Leaving the tool (again, Done, Escape, the arrow tool, a thing that starts typing) also takes the pen again.
- Pencil double-tap / squeeze (`pencilTaps` on the touch layer): iOS 17.5+ SwiftUI `onPencilDoubleTap` / `onPencilSqueeze` (at `.ended`) with `preferredPencilDoubleTapAction` / `preferredPencilSqueezeAction`; before 17.5 a `UIPencilInteraction` (double-tap only). switchEraser / switchPrevious → swap pen and rubber; showColorPalette / showInkAttributes / showContextualPalette → Draw tool on / off; ignore / runSystemShortcut → nothing.

### Wet line — `InkLayer` in `App/Sources/InkViews.swift`
- A second, light `Canvas` over the board (under the text field, no presses, hidden from VoiceOver). Only it listens to `WetLine`; a sample repaints the one running line (the same `InkDraw.stroke`, real + predicted points) — the board's own Canvas, `Lettering.fit` and the map layout are not touched until the lift. The rubber shows a ring of 10 screen points.

### Screens — `App/Sources/InkViews.swift`
- `DrawTool` in `ToolPill` after Frame: `tool.draw`, 40 × 40 like the other tools, part colour `Part.drawing` (new: day #BF2F52, night #F2879C), full colour while on, value "On" / "Off".
- `DrawPlate` above the tools row (`draw.plate`): `draw.pen`, `draw.rubber`, `draw.thin`, `draw.medium`, `draw.thick` (tiles of `Finger.shape`: 36 × 36 iPhone / iPad, 30 × 28 Mac), dots `draw.colour.ink` and `draw.colour.<palette name>` (26 points iPhone / iPad, 22 Mac; ring round the one in use), `draw.done` (full colour). Wraps onto more rows when narrow. `draw.pencilOnly` (the line about the Settings switch), `draw.rubberLine` + `draw.backToPen` (tool off, Pencil rubbing).
- Marks used: `Glyph.new(.draw / .rubber / .thin / .medium / .thick)`.

### Tests
- `Core/Tests/SeedboardCoreTests/InkTests.swift`, 11 tests: thinning; box and growing; joining; scaling; pressing a line; rubber; file round trip + older file + newer stroke; moved / copied / framed / snapped / removed; the drawn line (corner and bend); pressure; PARAGON line. Core total 201 (was 190), all pass.
- `UITests/DrawUITests.swift` (written and compiled, NOT run), 2 tests: blank board → `tool.draw` → plate buttons there → thick, red → drag on `board.canvas` → `board.count` "1 sketch" → Undo "Empty" → Redo → Rubber, drag across → "Empty" → Done, plate gone; `-board Sketch` → "2 notes · 3 sketches".

## 4. For the lead

**Pictures**
- `-sampleData -board Sketch` → the made-up board "Sketch ideas" (`App/Sources/SampleSketch.swift`): a floor plan (thick ink walls, medium inner walls, thin blue door with pressure, teal window), "Lake side" in a red ring with an orange arrow (pressure), a thick green tick beside a note; two notes, four words. The lines are the same on every run.
- add `-draw` → the Draw tool on and its plate showing. With `-night` for the night look.
- `-pick`: a sketch has no words, so it cannot be picked by `-pick`.
- The home page shows the sketch board's small picture (one more made-up board: 10 instead of 9).

**No `ICON-WANTED`.** All five marks were in `NewMark`.

**Decisions to check with the owner**
1. **The Pencil over a sketch draws, it does not move it** (unless the sketch is chosen; a Pencil tap on a line chooses it). The brief said "the Pencil on a thing chooses or moves it"; for sketches that would make every line that starts on an older line drag the sketch away. One line in `inkBare` brings the strict rule back.
2. Joining: 5 seconds and 40 points (`Ink.joinSeconds`, `Ink.joinReach`). A longer pause in the middle of one sketch starts a second sketch on top of the first — they move separately. Raising the seconds is one number.
3. Plain ink is the first colour (and the start colour); it is not one of the 9 palette names, it is stored as "".
4. A Pencil double-tap set to "show colour palette" turns the Draw TOOL on — fingers then draw too until it is left.
5. Arrows can be joined to a sketch (it works like a note there); PARAGON's Flow then says "A sketch".
6. Thicknesses 2 / 4 / 7.5 points.

**Merging**
- `Board.swift`: `case drawing` and `case strokes` on their own lines; two lines in `word` / `defaultSize`. The shapes builder adds kinds to the same switches.
- Every `switch` over `ItemKind` without a `default` needs `.drawing`: `Lettering.fit`, `BoardPainter.drawItem`, `SelectionBar.itemChips` (done here; a new switch by another builder will not compile until it has it). `BoardPainter.handles` got its own `case .drawing`.
- `SelectionBar.itemChips`: the Words chip is now inside `if item.kind != .drawing` — the selection-bar builder must keep that.
- `CanvasView.swift`: 4 hunks (the `InkLayer` line in the ZStack, `dragGesture`'s two lines, `ink:` + `.pencilTaps` on `TouchLayer`, one line under Escape). `BoardSession.swift`: 3 (the `ink` property, a guard in `beginEdit`, the first line of `toggleTodo`). `BoardView.swift`: 3. `CanvasDraw.swift`: 3. `Theme.swift`: `Part.drawing`. `AppModel.swift`: `-draw`. `Sample.swift`: one line. Core: `BoardEdit` (resize, contains, countLine), `Fingers` (hit), `Tidy` (sizeable), `Paragon` (noteBullets, label).
- `TouchLayer.swift` is untouched.

**Left open**
- The tool row is 8 tools = 374 points wide; on an iPhone narrower than 394 points it scrolls sideways (it did not before). The "Box" plate of the shapes builder may change that anyway.
- No letter key for Draw on the Mac ("D" is the diamond), no pencil-shaped pointer on the Mac.
- "Copy the board as text" does not mention sketches.
- The rubber takes whole lines only (as briefed); no lasso, no changing the colour of a line afterwards.
- A very large sketch (hundreds of lines) is repainted whole on every slide of the board, like everything else on it; no stored picture of it.
- Pencil hover: nothing built.
- The Pencil's later, more exact pressure values (`touchesEstimatedPropertiesUpdated`) are not taken; the first values are used.

**What only a real iPad with a Pencil can prove** (the simulator has no Pencil; none of this was touched by hand)
1. The Pencil on empty board draws at once, and the line is under the tip without a felt delay (the wet line is a SwiftUI Canvas repainted per sample, with the predicted samples in front). Also on a long line of several seconds, and on a board with much on it.
2. No jump when the tip lifts and the wet line becomes the kept line (thinned to 0.4 screen points, rounded to 0.1).
3. A hand resting on the glass while the Pencil draws leaves nothing and moves nothing (the touch layer ignores fingers while the Pencil is down — also when the hand lands BEFORE the Pencil).
4. Pressure feel: is ordinary writing the chosen width, does it swell and thin pleasantly (the curve is a first guess: 0.25 of full force = the chosen width, 0.6 = +35 %).
5. Double-tap (Pencil 2, Pencil Pro) and squeeze (Pencil Pro) arrive and follow Settings › Apple Pencil; the small "The Pencil rubs out" line appears.
6. "Only Draw with Apple Pencil" on: a finger slides the board with Draw on, and the plate's line shows.
7. A Pencil tap on a sketch's line chooses it; a Pencil drag across its lines draws; a chosen sketch moves under the Pencil.
8. Scribble: hand-writing into the open text field of a box, note or idea.
9. Draw on with a finger: one finger draws, a second finger landing throws the line away and the two slide and zoom.
10. iPad with trackpad or mouse and Draw on: a click-drag draws.
11. Mac: a trackpad drag (three-finger drag or click-drag) draws smoothly; Escape leaves the tool.
