# Notes for 0.2 — arrows (picks 12 and 13)

Builder `arrows`, branch `feat-arrows`. Rules: `Core/Sources/SeedboardCore/Arrows.swift` (where arrows run) and `ArrowEdit.swift` (ends, dashes, moving an end, the next shape). App: `App/Sources/ArrowDraw.swift` (painter) and `ArrowSession.swift` (actions and keys). Tests: `Core/Tests/SeedboardCoreTests/ArrowTests.swift` (22 tests; the package now has 112, before 90).

## 1. What's new

**Better arrows (pick 12)**

- Corners. Before: a right-angle arrow had sharp corners. Now: every corner is rounded with a radius of 8 points, and less (half the leg) where a leg is shorter than 16.
- Arrows on the same side. Before: two arrows on the same side of a shape lay on top of each other and looked like one. Now: they stand 14 points apart round the middle of the side (closer when the side is short). An arrow that runs dead straight keeps the middle, the others stand beside it. An arrow from A to B and one from B to A are two lines side by side, each with its own word.
- Round a shape. Before: an arrow ran straight on, hidden behind any shape that stood in its way. Now: it goes round the shape and passes it 12 points off. It goes round shapes, sticky notes and mind-map ideas; free text and frames are passed over. When no way round can be found the arrow runs as before.
- Moving an end. Before: an arrow always chose its own sides and could not be moved to another shape. Now: a chosen arrow shows a small dot at each end. Drag a dot to another side of the same shape, or onto another shape. A side chosen like this is kept when the shapes are moved. Drag the dot back to the side the app would pick, and the arrow chooses its own side again.
- Ends. Before: every arrow had one head at its far end, and nothing could change that. Now: three choices — One way (as before), Both ways (a head at each end), No ends (a plain line).
- Dashed. Before: every line was solid. Now: "Dashed" turns a line into dashes (the heads stay solid).
- The word on an arrow. Before: it sat in the middle of the line on a patch in the board's colour, so "Yes" swallowed a short arrow and a grey box showed inside a coloured frame. Now: it stands beside the line near its start — above a level line, to the right of an upright one — with no patch behind it. The typing field opens in the same place.
- A press on a curved arrow now follows the curve itself (before: the straight line between its two ends).
- The picture that goes to PARAGON shows all of this exactly as the board does (one painter).

**Tab makes the next shape (pick 13)**

- Before: the next shape of a flow could only be made with the green plus. Tab did nothing on a shape. Now: with a box, round box, diamond or oval chosen — or while its words are being typed — Tab makes the next shape with its arrow and starts typing in it. It goes the way the flow is running (the direction of the arrow that arrives at the shape; to the right when none arrives). ⌘→ ⌘↓ ⌘← ⌘↑ do the same in that direction.
- Before: the shape after a diamond was another diamond, after a round box another round box. Now: after a diamond or a round box comes a plain Box of the standard size (150 x 56), middle on middle. Every other shape is still followed by a copy of itself.
- Before: arrows out of a diamond had no words. Now: the first arrow out of a diamond says "Yes" and the second "No" by themselves (the third and later say nothing). The words can be changed like any others. This holds for Tab, the plus and the arrow tool.
- Before: the next shape always appeared 70 points away. Now: 100 points away when its arrow carries a word (Yes / No), so the word has room; 70 otherwise.
- A diamond's second Tab goes down (or to the right, when the flow runs down or up), so "No" gets its own side instead of squeezing in beside "Yes".

## 2. How it works (guide text)

**Arrows**
- An arrow finds its own way: it leaves the side that faces the other shape, bends with soft corners and goes round a shape that stands in its way.
- Several arrows on one side of a shape stand apart, so each can be seen and pressed. An arrow there and an arrow back are two lines.
- Press an arrow to choose it. A small dot shows at each end. Drag a dot to another side of the same shape, or onto another shape — a dashed line follows, and the shape the end would land on lights up. Let go on empty board and the end springs back.
- The bar of a chosen arrow has: Words; Right angles, Straight, Curved; One way, Both ways, No ends; Dashed; Turn round; Colour; Remove.
- The word of an arrow stands beside the line near its start. Press an arrow twice (or choose it and press Return, or Words) to type it.

**Building a flow with the keyboard**
- Choose a shape and press Tab: the next shape appears with its arrow, in the direction the flow is running, ready to type in. Type, press Tab again, and so on.
- ⌘ with an arrow key makes the next shape in that direction — ⌘↓ to go down, ⌘→ to go right.
- After a diamond (a question) or a round box (a start) comes a Box.
- The first two arrows out of a diamond say Yes and No by themselves. Press Tab on the diamond a second time for the No side.
- On a mind-map idea Tab stays what it was (an idea under it).

## 3. Spec

**Stored fields (all on an arrow, all optional, left out of the file when not set; old files load unchanged)**
- `fromSide`, `toSide`: `"up"`, `"down"`, `"left"` or `"right"` — the side the owner chose for the start / the end. Missing or an unknown word: the side is found by the app (rule of 0.1, now `Route.sides(from:to:)`).
- `tail`: `true` = a head at the near end too. Together with the existing `head`: One way = head true, no tail; Both ways = head true, tail true; No ends = head false, no tail. (A 0.1 app shows Both ways as One way and No ends as a plain line.)
- `dashed`: `true` = drawn with dashes.
- `Link.ends` (`LinkEnds`: `oneWay`, `bothWays`, `none`; words "One way", "Both ways", "No ends") and `Link.isDashed` read and write these. `Direction` is now Codable. Coding keys are on their own line under the old ones. The format number is not changed by this branch.

**Where an arrow runs (`Board.arrows()` → `[id: Route.Arrow]`; `Board.arrow(id)`)**
- Left out: arrows with a missing end, an end folded away, or both ends on the same item.
- Sides: the stored side if there is one, else the rule of 0.1.
- Sharing a side (`Route.offsets`, `Route.room`, `Route.spread` = 14): the arrows on one side of an item (leaving and arriving alike) are put in the order of where their other end lies (by its middle, top to bottom on a left/right side, left to right on a top/bottom side; equal: older arrow first) and stand 14 apart round the middle: -7/+7, -14/0/+14 … The room is the side's length less 16 (60 % of it on a diamond or an oval); with less room they share what there is. If exactly one of them runs dead straight (facing sides whose middles line up within 1 point), it keeps the middle and the others stand 14 apart beside it. An arrow that is alone on a side of a box, note, text or round box slides along that side (at most half its room) to stay straight when its other end had to make room.
- Meeting the outline (`Route.anchor`): off the middle, the end lies on the real outline — the slanted edge of a diamond, the curve of an oval, the round end of a round box (corner radius 9 on a box).
- Right angles (`Route.elbow`): facing sides: one straight piece when the ends line up within 1 point, else one bend half way (as in 0.1); arrows side by side bend one after the other (the bend moves by the arrow's place on the side), so they never share a piece. Any other pair of sides (after a side was chosen): the line leaves each side straight out for 16 points (`Route.reach`) and takes the way with the fewest corners, then the shortest (a corner counts as 24 points): straight on, one corner, two corners in one channel, three corners in two channels. Channels: half way between the two items, and 16 outside them.
- Round a shape: when the plain line would run through a shape, sticky note or idea (its box grown by 2), channels 12 points off the edges of the six nearest such things are added (`Route.clearance` = 12) and the best way that touches nothing is taken (simple ways before long ones). Things that lie on one of the two ends are not counted. No way found: the plain line stays.
- Straight: a straight line between the two ends; blocked: past one corner of the shape in its way, 12 off, when that keeps 6 clear of everything; else along one side of it (two corners); else past one corner however close; corners rounded 8.
- Curved: a curve that leaves each side straight out (pull = half the distance along that side's direction, at least 40 when the sides do not face each other). When the curve itself would run through something: the Straight way round, with wide corners (radius 24).
- Corners (`Route.rounded`): radius 8, or half the shorter leg beside the corner; under 0.5 the corner stays sharp.
- Heads (`Route.head`): 9 long, 5.5 to each side, tip on the item, pointing along the last piece of the line (so a Straight arrow's head now follows its slant). Both ways: a second head at the start. No ends: none.
- Line: 2.2 wide, round caps and joins; Dashed: 5 on, 6.5 off (looks like 7 and 4 with the round caps); heads are never dashed. Chosen: the 8-wide soft halo as before.
- Words (`Route.words`): 13 pt medium, ink colour (or the arrow's colour), no patch. Beside the first piece of the line: a level piece — the corner of the words 12 along and 4 above the start; below instead when the arrow is the lower of several on its side, or stands alone and the line then climbs. An upright piece — 8 to the right and 10 along; to the left when the arrow is the left one of several. To the left of a start that runs left the words run leftwards. If the first piece is shorter than 48 and the line turns to the side the words stand on, they stand beside the first later piece of 48 or more. Straight and Curved: on the side the line moves away from (when it moves more than 20); a Straight arrow that shares its side stands its words 28 further along.
- The typing field for an arrow's words (170 wide) opens where the words stand, aligned to the start.
- Finding an arrow under a press (`hitLink`): distance to the drawn line (curves as 12 short pieces), 9 screen points as before.
- The painter keeps the arrows of the last board drawn (`ArrowCache`) and works them out again only when a shape's place, size or kind, a fold, or an arrow's ends, sides or style changed. Measured: a board of 300 shapes and 329 arrows (44 of them going round shapes) takes about 3.5 ms.

**Moving an end**
- A chosen arrow (not read-only, not while typing, not with the arrow tool on) shows a dot at each end: radius 5 screen points (shrinks with the zoom below 100 % like the other handles), plate colour with a 2-point green edge. A press within 13 screen points of a dot takes it (the far end first).
- While dragging: a dashed green line from the other end to the finger; the item the end would land on gets the dashed green frame.
- Let go (`Board.moveEnd(of:start:to:)`): on its own item, or within 30 points of it — the end moves to the side nearest the point (the box cut in four by its diagonals, `Route.nearestSide`) and that side is stored; if it is the side the app would find anyway, nothing is stored. On another item (not a frame) — the end moves there and its stored side is cleared. Refused, nothing changes: a frame, empty board, the item at the other end, or when the same arrow (same from and to) already exists. One undo step.
- Turn round also swaps the two stored sides.

**The bar of a chosen arrow** — new buttons after the three styles: `sel.ends.oneWay` "One way", `sel.ends.bothWays` "Both ways", `sel.ends.none` "No ends" (the current one is filled), `sel.dashed` "Dashed" (filled when on). Marks `Glyph.new(.oneWay / .bothWays / .noEnds / .dashed)`. All existing identifiers are kept.

**Next shape (`Board.addNext`, `ItemKind.nextInFlow`, `Board.flowDirection(at:)`, `Board.wordForNewArrow(from:)`)**
- Tab (no Shift, ⌥, ⌃) with exactly one flow shape chosen, or while its words are typed: `addNext` in `flowDirection`. ⌘ + arrow key: `addNext` in that direction. The words being typed are kept first. Mind-map ideas, notes, text and frames are not touched (Tab on an idea is unchanged).
- `flowDirection`: opposite of the side at which the oldest arriving arrow arrives; none: right. A diamond that already has an arrow leaving on that side: down (when the flow runs sideways) or right (when it runs up or down), if that side is still free.
- `nextInFlow`: diamond → box, round → box, everything else itself. A changed kind gives a plain Box (150 x 56, no colour); the same kind copies size and colour as before. The new shape is placed middle on middle with its source.
- Word of a new arrow out of a diamond: no arrow leaves it yet → "Yes"; one leaves → "No" ("Yes" if that one says "No"); two or more → none. Applies to `addNext` and to `link(from:to:)` when no words are given (plus drag, arrow tool).
- Gap: 70; 100 when the new arrow carries a word.
- The plus dragged out of a diamond or round box and dropped on empty board also makes a Box.

**Changed test**: `EditTests.testAddNextJoinsAndKeepsKindAndSize` now uses an oval (a diamond is followed by a Box).

## 4. For the lead

- **Pictures**: `-sampleData -board Arrow` opens the new made-up board "Arrow looks" (8 shapes, 1 note, 9 arrows: both ways with a word, dashed, a plain line, there-and-back side by side, two out of one side, one going round a shape, words beside lines). It is the oldest board, at the bottom of Recent. New: `-pickArrow <word>` chooses the first arrow whose words hold it — e.g. `-board Arrow -pickArrow skip` shows the end dots and the bar with One way / Both ways / No ends / Dashed. `-board cabin -pickArrow Yes` shows the old sample with the new word placement.
- **Screen test**: none (no new screen), as briefed.
- **Icons**: no `ICON-WANTED`; `oneWay`, `bothWays`, `noEnds`, `dashed` were already in `NewMarks.swift`. Until they are drawn all four show the arrow-tool stand-in, so the three ends buttons differ only by their words.
- **Shared files touched** (small hunks): `Board.swift` (4 fields, keys, decoding in `Link`), `BoardEdit.swift` (`link`, `addNext`, `hitLink`), `CanvasDraw.swift` (old `drawLink` removed; two calls into `ArrowDraw.swift`), `CanvasView.swift` (cases `Target.end` / `Drag.end` and their five switch lines; the arrow's typing field; one line at the top of `target(at:)`; one line at the top of `handleKey`; an own `.onKeyPress` on the field placed above `.foregroundStyle`, away from the Return/Tab handlers; plus-drop makes a Box), `BoardSession.swift` (one line in `turnLinkRound`), `BoardView.swift` (4 lines in `linkChips`), `AppModel.swift` (`-pickArrow`), `Sample.swift` (the board).
- **Needs a real run to prove**
  - Tab while typing in a shape. My key handler sits nearer the field than the existing Tab handler and should be asked first. If Tab in a shape only ends the typing, put `if session.flowKey(press) { return .handled }` as the first line of the field's own Tab handler.
  - ⌘ + arrow while typing makes the next shape, so those keys no longer move the caret to the start/end of the line in a shape's words. If that is not wanted, take the four arrow keys out of the `keys:` list of my `.onKeyPress` on the field (they then work only on a chosen shape).
  - Dragging the end dots with a finger (catch area 13 points; pick 10 may want it bigger) and with the mouse; the look of dashes and dots at 50 % and 300 %.
  - Not launched, no simulator, no screen tests (as ruled). Both apps compile. The painter was checked off-screen (day and night) with a small drawing tool in the scratch folder.
- **Left open**
  - The text for PARAGON ("Flow:" lines, `A → B (words)`) still writes `→` for Both ways and No ends — `Paragon.swift` was not in my brief.
  - Long words on a short arrow can run on under the next shape (the plus gives 100 only for Yes / No). Three arrows on one side: the middle one's word can touch the upper line. Words of a curved arrow that shares its side can touch its neighbour.
  - The Flow starter and the Summer cabin sample keep their 70 gap; "Yes" fits beside the line there.
  - `BoardPainter.ground` is no longer used (still set by `BoardPicture`); remove when convenient.
  - `Docs/SPEC.md` 2 (bar of an arrow), 3.1 (Link fields), 3.5 (routing, `addNext`), 3.7 (handles, keys) and "not in 0.1" (no way to turn a head off) need the texts above; `Guide.swift` the guide text.
