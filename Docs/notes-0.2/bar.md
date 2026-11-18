# Notes for 0.2 — builder "bar" (picks 7, 18 and 17, and the Home row)

## 1. What's new

### Pick 7 — the bar beside the chosen thing, and calmer handles

- **The bar is where the chosen thing is (Mac and iPad).** Before: the bar for a chosen thing sat at the top edge of the board, however far away the thing was. Now: it floats 12 points above the chosen thing (above its plus-handles when it has some). When there is no room above, it stands 12 points below. It always stays 8 points inside the visible board, follows the thing while the board slides or zooms, and is out of the way while the thing is dragged or its words are typed — it comes back when you let go or finish typing. The same goes for several chosen things (the bar stands over the box round all of them) and for a chosen arrow.
- **One row on the iPhone.** Before: the bar was a block of up to 3 rows at the top. Now: it is always exactly one row, still at the top under the title. The main buttons keep their word, the others are marks only, and what does not fit goes into a "…" button that opens the rest as a short list from the bottom. (An idea: "Idea under", "Next idea", "…", To do, Remove. A shape: Shape, Colour, Words, Duplicate, Choose more, To do, Remove — all in one row.) The same rule holds on a narrow iPad or Mac window: the bar loses words first, then buttons, never a second row.
- **One colour per bar.** Before: one bar carried up to four colours (pink, blue, green, purple, grey buttons side by side). Now: every button of a bar wears the colour of what is chosen — pink for an idea, blue for a shape, amber for a note, teal for a frame, grey-blue for an arrow, green for several things. Only two stand apart, at the end behind a thin line: **To do** stays purple, **Remove** is red (it was grey).
- **The arrow's bar fits one row.** Before: 10 buttons that wrapped to two rows on the Mac. Now: 7 — Words, **Line** (opens Right angles / Straight / Curved), **Ends** (opens One way / Both ways / No ends), Dashed, Turn round, Colour, Remove.
- **"Copy" in the bar is now called "Duplicate"** (it always made a second one right beside the first; ⌘D as before). Real Copy, Cut and Paste are new — see pick 17.
- **Plus-handles are small dots.** Before: four green 18-point plus buttons round every chosen shape, also on a side where an arrow already left — they sat on arrow heads and on the arrows' words. Now: a side that already has an arrow has no plus; the others are small 10-point outline dots that grow to 18 points and show their plus when the pointer comes near (Mac). On iPhone and iPad they are shown at 18 points with the plus, and the press area is still at least 32 points. A plus never sits on an arrow's word.
- **The frame follows the shape.** Before: every chosen thing got a rectangle round it — a diamond too. Now: the green frame follows the thing's own outline with a 3-point gap: a diamond gets a diamond, an oval an oval, a round box a round frame, a Person its head and shoulders, a Document its wavy edge, a Slanted box its slant, a Store its cylinder.
- **Size knobs on all four corners.** Before: 1 knob, bottom right. Now: 4 knobs, one on each corner of a shape, a note and a frame. Dragging a corner keeps the opposite corner exactly where it is — also at the smallest size, and also when the words inside need more room. The edges still catch their neighbours' edges (pick 11).
- **The timeline's bar** got the same calm look in a small way: its buttons wear the timeline's orange, Remove is red, and its "Copy" is called "Duplicate" too.

### Pick 18 — right-click and press-and-hold menu, pointer feedback

- **A menu on every thing.** Before: there was no menu on the board at all. Now: right-click a thing on the Mac (or Control-click), click with two fingers on an iPad trackpad, or rest a finger (or the Pencil) on it for half a second:
  - on a thing: Words, Colour ▸, To do, Copy, Cut, Duplicate, Arrow from here; for an idea also Idea under, Next idea, Fold; for a frame Lanes ▸; for a shape Shape ▸; and Remove. With several things chosen: To do, Copy, Cut, Duplicate, Line up, Even gaps, Same size, Remove.
  - on an arrow: Words, Line ▸, Ends ▸, Dashed, Turn round, Colour ▸, Remove.
  - on empty board: Paste, New note here, New box here, New idea here, Select all, Show the whole board. The new thing and the paste land exactly where you pressed.
- On the Mac it is the system's own menu. On iPhone and iPad it is a small plate just above your finger, in the colour of what you pressed, with Cancel.
- **Press-and-hold does not fight dragging.** A press that moves is a drag, as before (an idea still lifts after a quarter of a second). Only a press that has not moved for half a second opens the menu — and if you then move your finger after all (more than 10 points), the menu goes away and the drag carries on.
- **The pointer shows what it will do (Mac).** Over a size knob it becomes a diagonal resize arrow; over a plus-handle or an arrow's end dot a pointing hand; the plus-handle under it grows.

### Pick 17 — copy, cut and paste

- **⌘C, ⌘X, ⌘V** work on the board (Mac, and iPad or iPhone with a keyboard); they are the Edit menu's Cut, Copy and Paste lines, and they are in the right-click / press-and-hold menu. Before: there was no copy or cut; ⌘V could only paste text.
- **Copy** takes the chosen things with the arrows between them. A chosen idea is copied with everything under it, folded or not. It goes onto the clipboard in 3 forms at once: Seedboard's own (for pasting into a board), the words (for a text field, Notes, Mail — one thing gives its words, several give the same outline as "Copy the board as text"), and a picture.
- **Paste** makes new things — the arrows between them are kept — where the pointer is, at the spot you pressed (menu), or else in a free place near the middle of the view. Paste the same again at the same spot and each one lands 28 points further right and down. It works in **another board** too. Ideas pasted while an idea is chosen hang under that idea; a branch pasted on empty board becomes a small map of its own in the branch's colour.
- **Text from elsewhere**: one line becomes a sticky note, a list (two lines or more) a mind map — as before, but now at the pointer or the pressed spot.
- **Drag text in**: words dragged from Safari, Notes or any app and dropped on the board become a sticky note at that spot (a list becomes a mind map). Before: nothing happened.
- **Option-drag copies (Mac)**: hold Option while you let go of a drag and a copy lands there; the things themselves go back. One step for Undo.
- **Choosing box with a finger**: while "Choose more" is on, a finger drag on empty board draws the choosing box and adds what it catches. Before: a finger could only slide the board; the box needed a mouse.
- While words are typed, ⌘C, ⌘X, ⌘V and ⌘A belong to the words, as everywhere.
- On a timeline board Copy, Cut and Paste do nothing (greyed out on the Mac).

### Home

- **A "Home" row at the top of the boards list** (Mac and iPad), above Pinned. Before: once a board was open there was no way back to the home page. Now: press Home and the page with the starters and all boards is back. (On the iPhone the list itself is the home, as before.)

## 2. How it works (guide text)

**The bar for what you have chosen**
- Choose a thing and its bar appears right above it (on the iPhone: one row at the top). It holds what you can do with that kind of thing. Every bar has one colour — the colour of that kind of thing; To do is purple and Remove red, at the end.
- A button with only a mark shows its name when you rest the pointer on it. On the iPhone, "…" opens the buttons that found no room.
- The bar goes out of the way while you drag the thing or type in it, and comes back.
- Colour opens a row of dots under the bar; the colour in use wears a ring.
- For an arrow, Line and Ends each open a short list.
- Duplicate (⌘D) makes a second one beside the first.

**Handles**
- The small dots round a chosen shape or note add the next shape in that direction: press one, or drag it to where the next shape should be (or onto another shape to join the two). A side that already has an arrow has no dot.
- The small squares on the four corners change the size. The opposite corner stays where it is.
- The two dots at the ends of a chosen arrow move that end to another side or another shape.

**The menu of a thing**
- Mac: right-click (or hold Control and click). iPad with a trackpad or mouse: click with two fingers. Finger or Pencil: rest it on the thing for half a second without moving.
- On empty board the menu pastes, makes a note, a box or an idea right there, chooses everything, or shows the whole board.

**Copy, cut, paste**
- ⌘C copies what is chosen, ⌘X cuts it, ⌘V pastes — also into another board. Without a keyboard: Copy, Cut and Paste are in the menu of a thing and of empty board.
- What you copy can also be pasted into other apps: as words, or as a picture.
- Text copied elsewhere and pasted on the board becomes a sticky note; a list becomes a mind map. With one idea chosen, the list (or copied ideas) hangs under it.
- Drag words from another app onto the board to make a note there.
- Mac: hold Option when you let go of a drag to leave a copy there.
- iPhone and iPad: switch on Choose more, then drag a finger over empty board to draw a box round the things you want.

**Home**
- Mac and iPad: "Home" at the top of the boards list closes the board and shows the home page.

## 3. Spec

### The bar (`App/Sources/ChosenBar.swift`, `BarActions.swift`; rule `BarPlace.spot` in `Core/…/ChosenBar.swift`)
- Two views, one content (`ChosenBar`): `FloatingBar` (horizontal size class regular: Mac, iPad) inside `BoardExtras` in `CanvasView`; `ChosenBarTop` (compact: iPhone, narrow iPad window) in `BoardView`, where `SelectionBar` was. Not on timeline boards. Not on a board that cannot be changed.
- Place (`BarPlace.spot(box:bar:room:)`, screen points): `box` = the chosen thing's box on screen grown by 5 (3 gap + 2), reaching up and down as far as its plus-handles at their grown size; several things: the box round all; an arrow: the box round its line grown by 6. The bar is centred over the box, `gap` 12 above; if its top would be less than `air` 8 from the room's top: 12 below; if that does not fit either: at the room's top edge. Across it is clamped to 8 from the room's left and right. `room` = the board view minus 64 points at the bottom (the tools). A thing that has slid out of sight keeps its bar at the nearest edge.
- Hidden (floating bar only): while a drag is going on on the board (`BarDesk.dragging`: a thing, an idea, a size knob, a plus, an arrow end, the choosing box — not while the board itself slides), while words or a lane's name are typed, while the arrow tool is on. The iPhone's top bar stays, as in 0.1.
- One row, always (`ViewThatFits`), first that fits: (1) Mac/iPad: every button, words on `.word` and `.wideWord` buttons; (2) every button, words on `.word` buttons only; (3) every button, a word only on the first main button and on buttons that open a list (Line, Ends), and no "N chosen" label; (4…) as (2) with one more button behind "…" each time — the buttons with the highest `drop` number go first, the later one first among equals; (last) the row scrolls sideways. `drop` 0 buttons are never hidden.
- "…" (`sel.overflow`): opens `ActionList` — a pop-up on Mac/iPad, a sheet with a height detent on the iPhone (`PlatePresenter`; height = lines × 42 + 76, lines 2…9). It is lit while open and while a hidden button is switched on (Choose more).
- Tint: `BarActions.part(of:)` — idea → mind map, shape → shapes, note → notes, text → text (ink), frame → frames, arrow → arrows, several of one kind → that kind, mixed → boards. To do → `Part.paragon`; Remove → `Part.kept` (red). A hairline (1 × chip height − 10, primary 16 %) stands before the first of To do / Remove.
- Chips: height 28 Mac / 36 iPhone+iPad (`Finger.chipHeight`), mark 15, word in `Txt.pill`, corner 8, gap 5 / 8; a mark-only chip is square; press area +4 up and down on touch. Plate: `Theme.plate`, corner 13, 5 padding, shadow as before.
- Buttons per kind (identifier · show · drop):
  - idea: Idea under `sel.child` · word · 0; Next idea `sel.sister` (not the middle idea) · word · 0; Words `sel.words` · wideWord · 1; Fold/Unfold `sel.fold` (has ideas under it) · wideWord · 3; Both sides/One side `sel.sides` (middle idea) · wideWord · 3; Colour `sel.colour` (not the middle idea) · wideWord · 2; Move up/down `sel.moveUp`/`sel.moveDown` (iPhone, iPad; not the middle idea) · icon · 5; Duplicate `sel.copy` · wideWord · 4; Choose more `sel.more` (iPhone, iPad) · icon · 2; | To do `sel.todo`; Remove `sel.remove`.
  - shape: Shape `sel.shape` (the plate, `ShapeChip`) · word · 0; Colour · word · 2; Words · wideWord · 1; Duplicate · 4; Choose more · 3; | To do; Remove.
  - note: Colour · word · 2; Words · word · 1; Duplicate; Choose more; | To do; Remove.
  - text: Words · word; Duplicate; Choose more; | To do; Remove.
  - frame: Lanes `sel.lanes` (`LanesChip`) · word · 0; Colour · word; Words; Duplicate; Choose more; | Remove.
  - several: "N chosen" (`sel.count`); Line up `sel.lineUp` (2+), Even gaps `sel.evenGaps` (3+), Same size `sel.sameSize` (2+) · wideWord · 3; Duplicate; Choose more; | To do; Remove.
  - arrow: Words · word · 0; Line `sel.line` → list `sel.style.elbow|straight|curve`; Ends `sel.ends` → list `sel.ends.<raw value>`; Dashed `sel.dashed` · wideWord · 3; Turn round `sel.turn` · wideWord · 3; Colour · wideWord · 2; Choose more · 4; | Remove.
  - any newer kind of thing (e.g. a drawing): Duplicate, Choose more, | Remove — until it gets its own list in `BarActions.itemBar`.
- Kept identifiers: `board.selectionBar`, `board.colours`, `colour.none`, `colour.<name>`, every `sel.*` of 0.1 and of the other 0.2 builders. `sel.copy` is the Duplicate button. New: `sel.overflow`, `sel.line`, `sel.ends`, `sel.count`, `plate.actions`, `plate.back`, `plate.cancel` (as on the other plates).
- Colour dots: unchanged look (22 / 30 points, ring on the one in use), under the bar.

### Frame and controls (`App/Sources/ChosenFrame.swift`; rules `Controls`, `Corner` in Core)
- Drawn by `ChosenLayer`, a layer over the board's own drawing (never in a picture). `BoardPainter` no longer draws the frame or the handles.
- Frame: `paint.chosen`, 2 screen points wide, 3 screen points outside the outline (`Controls.frameGap`): box → rounded box (corner 9 + gap); round → capsule; oval → oval; diamond → diamond with every edge pushed out by the gap; person, document, slanted, store → their own outline (`ShapePaths`) on the box grown by the gap; note → corner 4 + gap; frame → 14 + gap; middle idea → 11 + gap; an idea on a branch and free text: the box grown by 5 across and 4 down, corner 9 (as 0.1).
- Plus-handles (`Controls.round`): middle 17 screen points outside the box (`Controls.reach`), on right, down, left, up of a shape and a note; right and down of free text; the one outward side of an idea. Not on a side where an arrow leaves or arrives (`Board.sidesWithArrows`, from the drawn arrows) — ideas keep theirs. Not where its 18-point box would touch the words of an arrow. At rest: 10-point dot, plate fill, green outline 1.6. Under the pointer (within 9 points) on the Mac, and always on iPhone and iPad: 18 points, green, white plus. Sizes shrink with the zoom below 100 % down to 55 %, as before.
- Size knobs: 9-point squares (corner 2.5, plate fill, green outline 1.8; 2.6 under the pointer) on the four corners of the frame round a shape, a note and a frame. Press areas: `Fingers.control` — 9 points round each control always; at least 32 points for a finger when no thing lies under it.
- Sizing (`Corner.rect`, `Board.size(_:corner:from:by:reach:)`, `BoardSession.liveSize`): the dragged corner follows, the opposite corner is fixed; least size 44 × 28 (a frame: 120 × 80 or what its lanes need); snapping as pick 11; when the words inside make the thing bigger than asked, it grows towards the dragged corner.

### Menu (`App/Sources/BoardMenu.swift`)
- Mac: `PointerCatcher` (an `NSView` behind the board) hears right mouse down and Control + left mouse down inside the board, not where a bar lies over it (`BoardShield` on the tools, the zoom buttons and the floating bar), not inside the thing being typed in; builds an `NSMenu` (`MacMenu`) and pops it up at the pointer. Menu items carry the identifiers below.
- iPad pointer: a tap recogniser with `buttonMaskRequired = .secondary` in `TouchSurface`.
- Finger and Pencil: `HoldWatch` in `TouchSurface` — a timer of 0.5 s from landing (`Fingers.hold`); cancelled when the press strays more than 4 points (`Fingers.still`, the same distance at which the board starts a drag) or a second finger lands. When it fires: the menu opens, a medium tap is felt, the press stays alive but its moves are held back; more than 10 points from the landing (`Fingers.letGo`) closes the menu and hands the moves on (a drag); lifting ends the press without a "press" on the thing. Not on a plus-handle, a size knob or an arrow's end dot.
- What is pressed is chosen first (added to the choice while Choose more is on); on empty board the choice is cleared. Typing is ended, the arrow tool switched off.
- The plate on iPhone/iPad (`BoardMenuLayer`, identifier `board.menu`): 250 wide, lines 40 high, heading with the kind's name in its colour and Cancel (`plate.cancel`); placed by `BarPlace.spot` round the pressed spot (above the finger, else below, 8 inside); scrolls when taller than the board; a press anywhere else closes it. Lines that lead on (Colour, Line, Ends, Shape, Lanes ▸ Rows/Columns) open in place with a way back (`plate.back`); colours show as dots.
- Identifiers: `menu.words`, `menu.colour`, `menu.colour.<name>`, `menu.colour.none`, `menu.todo`, `menu.copy`, `menu.cut`, `menu.duplicate`, `menu.arrow`, `menu.child`, `menu.sister`, `menu.fold`, `menu.lanes`, `menu.lanes.none`, `menu.lanes.rows|columns`, `menu.lanes.<way>.<n>`, `menu.shape`, `menu.shape.<kind>`, `menu.lineUp`, `menu.evenGaps`, `menu.sameSize`, `menu.remove`; arrow: `menu.line`, `menu.style.<raw>`, `menu.ends`, `menu.ends.<raw>`, `menu.dashed`, `menu.turn`; empty board: `menu.paste`, `menu.note`, `menu.box`, `menu.idea`, `menu.selectAll`, `menu.fit`.
- A board that cannot be changed: a thing's menu has only Copy; empty board has Select all and Show the whole board.
- Pointer (Mac): tracking area on `PointerCatcher`; over a size knob `NSCursor.frameResize` for that corner (macOS 15 and later; a crosshair before), over a plus-handle or an end dot of the chosen arrow the pointing hand; the hand of Space-and-drag is left alone.

### Copy, cut, paste (`App/Sources/ClipBoard.swift`; rules `Clip`, `Board.clip`, `Board.paste`, `Board.addWords` in `Core/…/Clip.swift`)
- Clipboard forms: `com.schabbauer.seedboard.clip` (JSON of `Clip`: `format`, `items`, `links`), plain text (`Clip.text`), PNG (the board painter on the clip as a small board, white ground). Nothing is stored in a board file: **no new stored fields**.
- `Board.clip(of:)`: the chosen things, ideas with all ideas under them, the arrows whose two ends are both copied; a timeline's rows and things of a kind this version does not know are left out; the top idea of a copied branch carries its branch's colour.
- `Board.paste(_:at:)`: new identities for every thing and arrow; the clip's middle lands on the point; frames go underneath; a branch without its parent becomes a middle idea (its ideas keep the branch colour); maps are laid out; returns the things to choose. `Board.paste(_:under:)`: a clip of ideas only hangs under an idea (the existing "hang under" rule). A clip from a newer Seedboard (`format` above this version's) is refused with a line of words.
- Where: the menu's pressed spot; else the pointer when it is over the bare board (Mac, iPad pointer); else `freeSpot` near the middle of the view. At a spot, the same clip pasted again within 20 points lands `Clip.step(again:)` = 28 × n right and down; after Copy the copied things' own place counts as the first paste.
- Words (`Board.addWords`): two non-empty lines or more → `addMap`; else one sticky note. With one idea chosen: under that idea (`BoardSession.paste`, as 0.1).
- Keys: Mac — the system's Edit ▸ Cut/Copy/Paste reach the board through `.onCommand` (`ClipKeys`) while the drawing surface has the keys; Delete and Select All are untouched. iPad/iPhone — `ClipCommands` replaces the pasteboard group with Cut ⌘X, Copy ⌘C, Paste ⌘V: on the board they act on the board, anywhere else they are passed to the text field that has the keys. As a second way, `CanvasView.handleKey` answers ⌘C/⌘X/⌘V when no menu line took them. Cut = Copy + Remove (one undo step).
- Drop: `.onDrop` of plain text on the drawing surface → `addWords` at the drop point.
- Option-drag (Mac, `BoardSession.dropCopy`): decided when the drag is let go; everything the drag moved (a frame with what lies in it, a map with its ideas) is put back and `Board.duplicate` makes the copies at the drop offset; one undo step.
- Choosing box: with Choose more on, a finger drag on empty board is the choosing box; what it catches is added to what was chosen before the press.
- Line of words after Copy: "Copied. Paste it here or in another board." / "N things copied. …".

### Home row
- `RootView.swift`, `BoardList`: first row of the list when not on the iPhone layout; `model.open(nil)`; bold and tinted while no board is open; identifier `boards.home`.

### Tests (Core, `BarClipTests.swift`, 8 tests; Core total 230)
bar place; sizing from a corner; no plus on a side with an arrow + four knobs + not on words; a still press of 0.5 s; copy with inner arrows (+ text, + newer clip refused); paste with new identities at a spot (+ another board, + frame underneath, + the 28 step); a branch copies with its children (+ hangs under an idea); words become a note / a list a map.

## 4. For the lead

**Launch arguments for pictures** (all with `-sampleData`; iPhone = one row at the top, iPad and Mac = floating above the thing)
- shape: `-board Summer -pick Worth` · idea on a branch: `-board Summer -pick Loan` · middle idea: `-board Summer -pick Summer` · note: `-board Summer -pick timber` · arrow: `-board Summer -pickArrow Yes` · several: `-board Summer -pickAll "New idea,Worth,plan"` · frame: `-board Lanes -pick "Web shop"` · the new shapes' frames: `-board Lanes -pick Customer` (Person), `-pick "Order form"`, `-pick "Order comes in"`, `-pick Stock`.
- add `-colours` for the colour dots, `-more` for the "…" list (iPhone; shows only when the bar has a "…"), `-plate line` or `-plate ends` with `-pickArrow` for the arrow's two lists, `-plate shape` / `-plate lanes` as before.
- NEW `-menu`: 1.2 s after the board shows, opens the menu of the picked thing (or picked arrow; with nothing picked: of the spot 30 % across, 25 % down). iPhone/iPad: the plate — good for pictures. Mac: the system's real menu pops up and stays until it is closed (a screen capture from outside shows it).
- No plus on a side with an arrow: `-board Arrow -pick Stock`. Bar below the thing: any thing near the top edge. Night: `-night`.

**Screen tests** — written, NOT run: `UITests/BarUITests.swift` (2 tests: every kind's bar exists and is under 60 points high; Copy in a thing's menu, then Paste in the menu of empty board of ANOTHER board, then Undo). It compiles (`build-for-testing`, Mac). Changed because a button moved: `MapsUITests.testMoveDownChangesTheOrder` (iPhone: opens `sel.overflow` first when `sel.moveDown` is not in the row) and `ShapesUITests` (ends the typing before it looks for `sel.shape` / `sel.lanes`, because the floating bar hides while typing).

**Joining with the two builders still at work**
- `BoardView.swift`: `SelectionBar` is gone (its place: `ChosenBarTop(session:)`); `ToolPill` and `ZoomCluster` each got one line `.modifier(BoardShield(…))`. If the Pencil builder added a `case .drawing` to the old `itemChips`, drop that hunk: `BarActions.itemBar` has a `default:` that gives a new kind Duplicate and Remove; give it its own list there.
- `CanvasDraw.swift`: the selection rectangle, the handle drawing, `handles(for:)`, `Handle`, `HandleKind`, `handleGap`, `handleSize` are gone (one cut at the end of `draw` and the top of "Handles"). Anything that used `BoardPainter.handles` uses `session.chosenControls()` / `Controls.round` now. `painter.selection` is still set but no longer read.
- `CanvasView.swift`: 12 small hunks — `Target.size` and `Drag.sizing` carry a `Corner`; `target(at:)` asks `session.control(at:…)`; `BoardExtras(session:)` after `LaneOverlay`; `.onPasteCommand` removed, `.background(PointerCatcher)` and `.modifier(ClipKeys)` added; `BarDesk.shared.dragging` set in `begin`, cleared in `pressEnded` and `resetPress`; finger choosing box; `dropCopy()` in `finish`; `clipKey` in `handleKey`.
- `TouchLayer.swift`: `hold` (press and hold) and `secondary` (two-finger click); 5 small hunks in `pressed`, `giveUpFingers`, `hovered`, `init`. A stroke claimed by `ink:` never reaches `pressed`, so drawing and press-and-hold do not meet.
- A sequence board (own view): `ChosenBarTop` and `ClipBoard.canCopy/canPaste` only check `isTimeline` — add the sequence kind there, or its things get the ordinary bar on the iPhone.
- A drawing thing: Copy/Paste and Option-drag carry any stored field of an `Item` untouched, but they only shift `x`/`y`. If strokes are stored in board coordinates (not relative to the thing's corner) they will not move with a paste — same for `Board.duplicate` and `move`.
- Other files touched lightly: `ShapePlate.swift` (`BarChip` height 28 → `Finger.chipHeight` + press room; it was 28 next to 36-high chips on touch), `TimelineBars.swift` (5 words/tints), `SeedboardApp.swift` (`ClipCommands()` twice), `RootView.swift` (Home row).
- Left in place although unused now: `BoardSession.liveResize` (SnapShow.swift).

**ICON-WANTED**
- ICON-WANTED: Home — a small house (now the sprout mark `seedSprout`).
- ICON-WANTED: Copy — two sheets, one behind the other, or a clipboard with a sheet (now `deckClipboard`).
- ICON-WANTED: Select all — a dashed box with a tick (now `addCircle`).
- ICON-WANTED: Line with right angles, straight line, curved line — three marks for the arrow's "Line" list and its button (now all `seedArrow`).

**Left open**
- iPad pointer: no resize arrow or hand (the plus-handles are always big there); the menu and paste-at-pointer work.
- Option-drag shows the copy only when the drag is let go (no copy trailing behind, no plus on the pointer).
- Option-drag of a frame copies what lies in it; Duplicate and Copy of a frame take only the frame (unchanged rule of `Board.duplicate`).
- A Person's frame follows head and shoulders only; the name under it is marked by the corner knobs.
- "Paste a list as a mind map" (More menu, Board menu ⇧⌘V) is unchanged and now overlaps with plain ⌘V.
- The bar forgets an open colour row when it hides for a drag or for typing.

**Only a real run can prove**
1. Mac: Edit ▸ Cut/Copy/Paste turn black and act while the board has the keys, and stay with the words while typing; ⌘C/⌘X/⌘V arrive; Delete and Select All still work.
2. iPad with a keyboard: ⌘C/⌘X/⌘V on the board, and in a text field (board words, search, Send page) they still copy and paste words — `CommandGroup(replacing: .pasteboard)` passes them on by hand.
3. Mac: right-click and Control-click open the menu on a thing, an arrow and empty board, not on the tools; the resize arrow and the hand show; the dot grows; nothing of this slows a left click or a drag.
4. iPhone/iPad: the half-second press opens the plate; holding an idea a little shorter and dragging still lifts it; moving after the plate opened turns into a drag; two-finger click on a trackpad.
5. The bar: sits right on Mac and iPad at every zoom, hides and returns; one row on every iPhone width; the "…" sheet; pop-ups from a bar that floats.
6. Paste from Seedboard into Notes/Mail (words) and into Preview/Pages (picture); paste of text copied in another app (iOS may ask "Allow Paste").
7. Text dragged in from Safari on Mac, iPad (side by side) and iPhone lands as a note at the drop spot.
8. Sizing from each of the four corners feels right with snapping and with long words.
