# Notes for 0.2 — builder "shapes" (picks 15 and 16)

## 1. What's new

**Four more shapes (pick 15)**
- Before: 4 flow shapes — Box, Round box, Oval, Diamond. Round box and Oval could not be added directly; you added a Box and changed it.
- Now: 8 flow shapes. New are **Person** (a head-and-shoulders figure with its words under it), **Document** (a sheet with a wavy bottom edge), **Slanted box** (something goes in or comes out) and **Store** (a cylinder: where things are kept).
- The new shapes do everything a Box does: the 9 colours, the to-do tick, words typed in place, arrows, the green plus for the next step, falling in line, Copy, Line up / Even gaps / Same size, and the picture and the text that go to PARAGON.
- Words always stay inside the shape: under the figure of a Person, above the wave of a Document, between the slanted sides, between the lid and the bottom of a Store. A shape grows wider first and then taller when its words need room, like a Box.
- Arrows end on the real edge: half way up the slanted side of a Slanted box (9 points inside its box), on the wave under a Document (9 points above its bottom), at the shoulders of a Person (24 points inside at its normal size).

**One plate with all shapes (pick 15)**
- Before: the tool pill had a Box tile and a Diamond tile. The bar of a chosen shape showed 4 small shape buttons.
- Now: the Box tile opens a small plate with all 8 shapes — hold the tile, or press the small corner mark on it (Mac and iPad). A plain press on the tile adds the shape you picked last, and the tile shows that shape's mark. Diamond keeps its own tile.
- The bar of a chosen shape has ONE button, **Shape**, instead of 4. It opens the same plate, and the shape can be changed into any of the 8 kinds (before: 4).
- On the iPhone the plate comes up from the bottom as a low sheet; on the Mac and the iPad it is a small pop-up.

**Lanes in frames (pick 16)**
- Before: a frame was one plain area. Only things lying wholly inside it travelled with it.
- Now: a chosen frame has **Lanes** in its bar: no lanes, or 2, 3, 4 or 5 lanes, as rows or as columns. Each lane has a name. The lanes share the frame evenly and stretch when the frame is sized. The line between two lanes can be dragged; no lane gets narrower than 60 points.
- A thing now belongs to a frame — and to a lane — when its MIDDLE is inside (before: only when all of it was inside). This is true for every frame, with or without lanes. Moving a frame carries its things; sizing a frame moves nothing.
- While a thing is dragged, the frame or the lane under its middle lights up softly, so you see where it will belong.
- To PARAGON: "As a note" lists the things of a frame with lanes lane by lane, under the lane's name. "As a project" makes one group of tasks per lane.

## 2. How it works (guide text)

**More shapes.** Press the Box tile to add a shape. To pick another kind, hold the tile (on the Mac and the iPad you can also press the small corner mark on it): a plate shows all eight — Box, Round box, Oval, Diamond, Person, Document, Slanted box, Store. Press one and it appears in the middle of the view, ready to type in. The tile remembers your pick: the next plain press adds the same kind again. Diamond also keeps its own tile.

**Changing a shape.** Choose a shape and press **Shape** in its bar. The plate shows what it is now in full colour; press another kind. Its middle, words, colour and arrows stay. A shape you sized yourself keeps its size.

**What the new shapes mean.** A Person is somebody who does something — the words stand under the figure. A Document is a paper, a form, a file. A Slanted box is something that goes in or comes out. A Store is a place where things are kept: a list, a shelf, a database.

**Lanes.** Choose a frame and press **Lanes**. Pick rows or columns and how many (2 to 5), or "No lanes" to take them away again. Press a lane's name twice to type it; Return keeps it, Tab keeps it and goes on to the next lane, Escape leaves it as it was. Drag the line between two lanes to make one bigger and the other smaller. Sizing the frame stretches all lanes with it.

**What belongs to a frame.** A thing belongs to the frame (and the lane) its middle is in. While you drag a thing, that frame or lane lights up. Move the frame and everything that belongs to it comes along; size the frame and nothing else moves. A frame lying wholly inside another frame travels with the bigger one.

**Lanes in PARAGON.** In a note, each frame with lanes gets its own part: the frame's name as the heading, then every lane's name with its things under it, in reading order. In a project, every lane becomes a group of tasks named after the frame and the lane.

## 3. Spec

**Kinds (Core `Board.swift`, `ShapeOutline.swift`)**
- Stored names (never change): `person`, `document`, `slanted`, `store`. `ItemKind.flowShapes` = box, round, oval, diamond, person, document, slanted, store (the plate's order); `isShape` is true for all 8.
- Words: Person, Document, Slanted box, Store. Own sizes: Person 110 × 96, Document 150 × 68, Slanted box 160 × 56, Store 130 × 80.
- Widest a shape grows by itself while typing: Person 220, Slanted box 330, Document and Store 300 (as a Box).
- An older app reads an unknown kind as a Box (0.1 behaviour); "opens read-only" is another builder's part.

**Outlines (Core `ShapeOutline`, painted by App `ShapePaths.swift` / `ShapeDraw.swift`)**
- Person: the figure takes the top 62 % of the height (`figurePart`). Head: a circle, radius 24 % of the figure's height, 1 below the top. Shoulders: the upper half of an oval, starting 6 % of the figure's height under the head, standing on the figure's base line; as wide as 1.15 × the figure's height, at most the width − 4. Words: under the figure, 4 from each side, from 4 below the base to 2 above the bottom, set in the middle of that room. Height for words: (words + 6) ÷ 0.38, rounded up.
- Document: top corners rounded by 7. The bottom edge is a wave that swings `min(9, 14 % of the height)`: its middle line lies one swing above the bottom; the left half dips to the bottom, the right half rises one swing above the middle line. Words: 12 from each side, 9 from the top, down to 4 above the wave's highest point. Height = words + 32.
- Slanted box: the top edge is pushed `min(18, 20 % of the width)` to the right of the bottom edge. Words: inside the upright part, 6 from each slanted side, 11 from top and bottom. Height = words + 22.
- Store: an oval lid and an oval bottom, each `min(9, 14 % of the height)` high as a half; the lid's front lip is drawn as a line. Words: 10 from each side, 3 under the lip, 3 above the start of the bottom curve. Height = words + 34.
- Lines: without a colour the plate's fill with the edge colour, 1.4 wide; with a colour the soft tint with the colour's line, 1.8 wide; round joins and ends. Day and night come from `Paint` as for a Box.
- `ShapeOutline.textBox(kind, frame)` gives the room for words for all 8 kinds; `ShapeFit.wordsWidth` / `ShapeFit.height` use it for the 4 new kinds. `ShapeOutline.holds` says whether a point is inside the drawn outline.
- Typing in place: the field covers the text box (`Item.typingFrame`).
- To-do tick: top right corner as before; for a Person beside the head (3 inside the right end of the shoulders, 6 below the top) (`ShapeOutline.tickSpot`).

**Arrows (Core `ShapeOutline.inset`, `Route.Path.meeting`)**
- The route is worked out from the boxes round the two things as before; then each end is pulled in along its own direction by the inset of that side: Slanted box left/right = half the slant (9 at 160 wide); Document bottom = the swing (9); Person left/right = up to the shoulders at mid-height (24 at 110 × 96); 0 everywhere else. A straight piece stays straight; the words on the arrow sit in the middle of the shortened line. Between plain boxes nothing changes.
- Used where arrows are drawn (`CanvasDraw.drawLink`) and where an arrow's words are typed (`CanvasView.editor`).

**The plate (App `ShapePlate.swift`)**
- `ShapePlate`: heading in the shapes colour with Cancel (Escape), 8 tiles in 2 rows of 4, each 54 high: the mark (26) with the kind's word under it; the current kind in full colour. Width 344 as a pop-up; the full width as a sheet.
- `PlatePresenter`: a pop-up when the width is regular (Mac, iPad, a big iPhone on its side), a sheet with a height detent (230; Lanes 250) when it is compact (iPhone).
- Tool pill, `ShapeTool`: the tile shows the mark of the shape picked last. Press = add that shape. Hold 0.4 s = the plate. Corner mark (a small filled corner, 7 points) = the plate; on the iPhone the corner only shows and takes no presses. After a pick the plate closes first, then the shape is added and typing begins.
- The last pick is kept on the device (`UserDefaults` key `tool.lastShape`); Diamond is never kept (it has its own tile); with `-sampleData` nothing is read or kept (`ItemKind.boxTile(stored:)`).
- Bar of a chosen shape, `ShapeChip`: one "Shape" button showing the current kind's mark; the pick is one Undo step (`setKind`, rules unchanged: middle, words, colour stay; an untouched shape takes the new kind's own size).
- Letter keys are unchanged (B Box, U Round box, O Oval, D Diamond); the 4 new kinds have no key.
- Identifiers: `tool.box` (kept), `tool.shapes` (corner mark), `plate.shapes`, `plate.shape.<stored name>` (adding), `plate.cancel`, `sel.shape` (bar button), `sel.shape.<stored name>` (kept; now inside the plate, for all 8 kinds).

**Lanes (Core `Lanes.swift`)**
- Stored: one optional field `lanes` on a frame item: `{ "way": "rows" | "columns", "names": [text …], "cuts": [0…1 …] }`. `cuts` are the lines between lanes as parts of the lanes' room, rising, one fewer than names. Missing = a plain frame. Cuts that make no sense are read as even lanes; fewer than 2 names are filled up to 2.
- 2 to 5 lanes. The frame's own name band (30 high) stays above the lanes; the lanes share the rest. Name band of a lane: 24 wide at the left of a row, 24 high at the top of a column.
- Giving a frame lanes, or another number: names that fit stay, the lanes are even again, and a frame too small grows (rows: height ≥ 30 + 60 × lanes; columns: width ≥ 60 × lanes). Another direction keeps all names. "No lanes" removes the field.
- Dragging a line: both lanes beside it keep at least 60; the line stops there. Sizing the frame: never smaller than 120 × 80, and never so small that the narrowest lane falls under 60 (`Item.leastFrameSize`).
- Which lane holds a point (`Lanes.index(at:in:)`): by its place along the lanes; a point on a line counts for the lane after it; a point in the frame's name band counts for the first row (or the column under it).
- An unnamed lane shows "Lane 1", "Lane 2" … faintly on the live board; never in a picture.

**Belonging (Core `Lanes.swift`, `BoardEdit.carried`)**
- A thing belongs to a frame when its middle is inside (`Board.frame(_:holds:)`). A frame belongs to another frame only when it lies wholly inside. Of a mind map only the centre counts; its ideas travel with it.
- `carried(by:)` uses this for every frame: moving a frame (drag, arrow keys, Line up …) carries what belongs to it. Sizing carries nothing.
- `spot(of:)`: the frame and lane of a thing — the smallest frame round its middle when frames lie in each other.
- A lane's name band also catches a press on the frame (`Board.hit`), so a frame can be chosen and dragged there; the lanes themselves stay free for what lies in them.

**Lanes on the board (App `LanesView.swift`)**
- Drawn on the frame, under everything in it: name bands tinted with the frame's colour (13 % by day, 20 % by night), lines 1.1 wide at 60 % of the colour, names 12 semibold in the colour — upright (bottom to top) in a row's band, level in a column's band; a name too long for its band ends in "…".
- Light while dragging (`SnapShow.over` → `BoardPainter.frames`): the lane under the middle of each dragged thing is filled with 17 % (night 24 %) of the frame's colour and the frame's outline is 2.6 wide; a frame without lanes is filled with 14 % (night 20 %). A frame that is dragged itself does not light up. Never in a picture.
- Lines of a chosen frame: a grip (34 × 5, the frame's colour) in the middle of each line; the whole line takes a drag, 7 points to each side. One Undo step per drag. On the Mac the pointer becomes a resize arrow.
- A lane's name: two presses on its name band. The field lies level (a row: 170 wide at the top of its band; a column: as wide as the column, 110 to 220). Return or Done keeps, Tab keeps and goes to the next lane, Escape leaves it, a press elsewhere keeps. One Undo step per name.
- Bar of a chosen frame: "Lanes" (full colour when the frame has lanes), then Colour, Copy, Words, Remove. The plate: "No lanes", and for Rows and for Columns the numbers 2 3 4 5; what the frame has now is in full colour; one Undo step per pick.
- Identifiers: `sel.lanes`, `plate.lanes`, `lanes.none`, `lanes.rows.2` … `lanes.rows.5`, `lanes.columns.2` … `lanes.columns.5`, `lanes.line.<n>`, `lanes.nameField`.

**To PARAGON (Core `ParagonLanes.swift`, hooked into `Paragon.swift`)**
- The 4 new kinds are flow shapes: they appear in "Flow" lines and as "Steps" tasks exactly like a Box.
- As a note: after "Flow", per frame with lanes `## <frame name>` ("Lanes" when it has none), then per lane that holds something with words `### <lane name>` and its things as `- ` lines, in reading order (rows: left to right; columns: top to bottom). Empty lanes and frames with nothing in them are left out. Sticky notes and free text in a lane are listed there and also under "Notes" as before.
- As a project: per lane a task group `### <frame name>: <lane name>` (only `### <lane name>` when the frame has no name) with the lane's flow shapes as `- [ ]` tasks, placed before "### Steps"; those shapes are not repeated under "Steps".
- "Copy the board as text" is unchanged (it does not mention lanes).

## 4. For the lead

**Pictures — launch arguments (all with `-sampleData`)**
- `-board Lanes` — the new made-up board "Lanes and shapes" (`Sample.lanes`): a frame "Web shop order" with the rows Customer / Shop / Warehouse and a flow Person → Document → Slanted box → Box (to do) → Store.
- `-board Lanes -plate shapes` — the plate with all shapes, open over the tool pill.
- `-board Lanes -pick Customer -plate shape` — the "Change the shape" plate of the chosen Person.
- `-board Lanes -pick Web -plate lanes` — the Lanes plate of the chosen frame (and the grips on its lines when the plate is closed: `-board Lanes -pick Web`).
- `-board Lanes -pick "Order comes" -lit` — the Shop lane lit as if the chosen thing were being dragged.

**Screen test**: `UITests/ShapesUITests.swift` (1 test: the plate opens, Person adds a thing, `sel.shape` and `sel.lanes` exist). Written and compiled (`build-for-testing` on the Mac), not run. On a touch screen it opens the plate by holding `tool.box`; on the Mac by `tool.shapes`.

**Icons**: nothing wanted. Used `Glyph.new(.person / .document / .slanted / .store / .lanes)` and the existing `.seedBox / .seedRound / .seedOval / .seedDiamond`. The small corner on the Box tile is a drawn shape, not an icon.

**When merging with the other builders**
- Arrows: wherever an arrow's route is drawn or its words are placed, append `.meeting(a, b)` to `Route.path(…)` (today in `CanvasDraw.drawLink` and `CanvasView.editor`). `Board.hitLink` was left on the plain route on purpose.
- `ItemKind` switches without a default need the 4 kinds: `word`, `defaultSize` (Board.swift), `Lettering.fit` and `drawItem` (CanvasDraw.swift), `itemChips` (BoardView.swift).
- Small hunks in shared files: `Board.swift` (kinds on their own `case` line, `lanes` field with its own key line), `Shapes.swift` (3 new `case` lines), `BoardEdit.swift` (`carried`, `resize`, `hit`: one line each), `Paragon.swift` (1 + 3 lines), `CanvasDraw.swift` (7 places), `CanvasView.swift` (6 places, 1–3 lines each), `BoardSession.swift` (1 stored line `laneTyping`), `SnapShow.swift` (1 stored line `over`), `BoardView.swift` (Box tile → `ShapeTool`, 4 shape buttons → `ShapeChip`, `LanesChip`, the unused `shape(…)` helper removed), `Sample.swift`.
- The old Core test `testCarriedByAFrameTakesWhatLiesWhollyInside` still passes (its half-out note has its middle exactly on the edge) but its name is out of date; the new rule is tested in `ShapesLanesTests.testAThingBelongsWhereItsMiddleIs`.
- Stored format: the `lanes` field and the 4 kinds are lost or turned into Boxes if 0.1 saves such a board — the format number 2 (yours) is what protects them.

**Left open**
- ⌘Z while a lane's name is typed undoes a board step, not the typing (the Board menu only knows the board's own typing). Escape leaves the name as it was.
- The plus-handle drag ("pull out the next shape") does not light a lane; only dragging a thing does.
- No letter keys for the 4 new shapes; B always adds a Box, whatever the tile shows.
- "Copy the board as text" does not list lanes.

**Only a real device or a run of the app can prove**
- Hold versus press on the Box tile (a tap gesture and a long-press gesture on one tile) on iPhone, iPad and with the Mac's pointer.
- That typing begins in the new shape after a pick from the pop-up (Mac, iPad: 0.25 s after it closes) and from the sheet (iPhone: when it has gone).
- The sheet's height on the iPhone (230 for shapes, 250 for lanes) with the largest text size.
- A lane's name being kept when you press elsewhere (it relies on the field losing the keys), and Tab going on to the next lane.
- Dragging a lane's line with a finger, and the Mac's resize pointer over it.
- The look of the upright lane names and of the four shapes by night in the app itself (checked only in an off-screen drawing made with the same outline code).
