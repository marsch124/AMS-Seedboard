# Notes for 0.2 — builder "touch" (picks 24 and 10)

## 1. What's new

### Pick 24 — a proper touch layer on iPhone and iPad (the Mac is unchanged)

- **Two fingers slide and zoom at the same time.** Before: two fingers could only zoom, and the zoom stayed pinned to the spot where the fingers first landed — to move the board you had to lift a finger and drag with one. Now: put two fingers down and the board follows them — it slides with them and grows or shrinks round the point between them, in one movement, as in Freeform. Zoom still goes from 20 % to 300 %.
- **Two fingers never choose or move a thing.** Before: the first finger of a pinch often landed on a shape, chose it and shoved it a little before the second finger arrived; the shove stayed and left an undo step. Now: when the second finger lands, what the first finger did is taken back — the shape is back where it was, no undo step is left, and what was chosen before is chosen again. (Only a real move is kept: one that went 30 points or more and where the second finger came half a second or more after the first.)
- **iPad with a trackpad or mouse.** Before: two-finger scrolling on the trackpad did nothing, and a pinch zoomed round the wrong place. Now: two-finger scroll slides the board; a pinch on the trackpad zooms round the pointer; the mouse wheel slides the board, and with ⌘ held it zooms round the pointer (1 % per point). A click-and-drag on empty board draws the choosing box, exactly as on the Mac — a finger on empty board still slides the board. Shift with a click adds a thing to the choice or takes it out. An idea follows the pointer at once (the 0.25-second hold is only for fingers).
- **Two quick presses on empty board show the whole board** (iPhone and iPad). Before: they made a sticky note (only when nothing was chosen). Now: they show the whole board, as the "whole board" button does. Two quick presses on a thing still open it for typing. On the Mac two clicks on empty board still make a sticky note. *(One switch brings the sticky note back — see "For the lead".)*
- **The Pencil is told from a finger.** Its taps and drags choose and move things like a finger does, and an idea follows it at once. A hand resting on the glass while the Pencil is down is ignored. This is the base the Pencil drawing is built on.
- **The swipe back from the screen's left edge** gives up whatever the finger had begun on the board, so the board does not also slide or move a thing while the page goes back.

### Pick 10 — finger-size press areas and a readable iPhone (the Mac's sizes are unchanged)

- **Every button on the board screen has a press area of at least 44 × 44 points** on iPhone and iPad. The press areas grew more than the look:
  - bar buttons (Copy, To do, Colour, Words, Remove …): 28 high before, 36 high now, press area 44 high; 8 points between them (before 5);
  - the four shape buttons: 30 × 28 before, 36 × 36 now, press area 44 × 44;
  - Smaller, Bigger, Whole board: 28 × 28 before, 36 × 36 now, press area 44 × 44;
  - Undo and Redo on the iPhone: 30 × 28 before, 36 × 36 now, press area 44 × 44, 8 points apart (before 2);
  - colour dots: 22 points before, 30 now, 14 points apart (before 7), press area 44 × 44; on the iPhone the ten dots now take two rows instead of one crowded row;
  - the tools at the bottom: they look the same (40 × 40), the press area is 46 × 46 (before 40 × 40);
  - the "Undo" in the short line after a step ("Made its own map"): the whole white pill is the button now, with a press area 44 high (before only the word itself, 22 high);
  - the full-colour buttons (Send, Cancel): press area 44 high (before about 34).
- **The green plus-handles and the size knob** keep a press area of at least 32 × 32 points on screen at every zoom. Before: at 50 % zoom the plus shrank to 10 points with a press area of 28; the knob was 7 points with a press area of 25.
- **Small things are easy to hit when zoomed out.** A thing that is smaller than 44 points on screen is caught in a 44-point area round it; between two close things the nearer one wins. Before: the extra area round an idea was 4–5 points at 100 % and only 2 at 50 %.
- **The iPhone opens a board readable.** Before: a large board opened whole at 50 %, with 7-point words. Now: a board that would have to shrink below 75 % opens at 75 % with its main idea (or first shape) in view; a board that fits at 75 % or more opens whole, as before. The "whole board" button (and two quick presses on empty board) still give the overview.
- **Typing on the iPhone zooms in.** When the view is smaller than 100 % and you start typing, it zooms to 100 % round the thing you type in; when you finish, it goes back to the zoom before. Ideas typed one after the other do not zoom out in between.

## 2. How it works (guide text)

**Moving around — iPhone and iPad**
- Slide with one finger on empty board to move the view. A quick slide that starts on an idea moves the view too; rest the finger on an idea for a moment (a quarter of a second) and it lifts, so you can hang it somewhere else.
- Put two fingers on the board to slide and zoom at the same time: the board follows your fingers and grows or shrinks round the point between them. Two fingers never choose or move anything — if your first finger nudged a shape before the second one landed, the shape goes back.
- Press empty board twice quickly to see the whole board.
- Smaller, Bigger and Show the whole board are at the bottom right.
- On the iPhone a big board opens at 75 % on its main idea, so the words can be read. While you type, the view is at least life size and goes back when you are done.

**With a trackpad or mouse on the iPad**
- Two fingers on the trackpad (or the mouse wheel) slide the board. Pinch on the trackpad, or hold ⌘ and scroll, to zoom round the pointer.
- Click and drag on empty board to draw a box that chooses everything it touches. Hold Shift and click to add a thing to the choice or take it out.
- Click a thing twice to type in it.

**With the Pencil**
- The Pencil chooses and moves things like a finger. An idea follows it at once.

**Lines the writer must change in the guide** (`Guide.swift`): 105 and 260 ("Two quick presses on empty board make a sticky note" — now Mac only; iPhone and iPad show the whole board), 116–117 (Shift-click and the choosing box now also with a trackpad or mouse on the iPad), 130 (pinch → two fingers slide and zoom), 132 (Mac, unchanged), 238 and 239 (zoom line; iPhone opens at 75 %).

## 3. Spec

### Touch layer (iPhone, iPad) — `App/Sources/TouchLayer.swift`, `Press.swift`
- `TouchLayer` (`UIViewRepresentable`) puts a clear `TouchSurface` (`UIView`) over the Canvas (`.overlay`, inside the `board.canvas` accessibility element, under the text field). On iOS the Canvas no longer has a SwiftUI gesture; the Mac keeps `DragGesture` + `ScrollCatcher`. The surface swallows raw touches (empty `touchesBegan…`), all work is done by recognisers, all with `cancelsTouchesInView = false`, `delaysTouchesEnded = false`, delegate = the surface.
- Recognisers:
  - `fingerPress` — `UILongPressGestureRecognizer`, `minimumPressDuration = 0` (begins at touch-down), `allowedTouchTypes = [direct, indirectPointer]`.
  - `pencilPress` — the same, `allowedTouchTypes = [pencil]` (its own recogniser, so a resting hand never blocks it).
  - `twoPan` — `UIPanGestureRecognizer`, `minimumNumberOfTouches = maximumNumberOfTouches = 2`, `allowedTouchTypes = [direct]`, no scroll types.
  - `pinch` — `UIPinchGestureRecognizer`, `allowedTouchTypes = [direct]`; also receives a trackpad's pinch (no touches: `numberOfTouches == 0` at `.began` → trackpad mode).
  - `scroll` — `UIPanGestureRecognizer`, `allowedTouchTypes = []`, `allowedScrollTypesMask = .all` (trackpad two-finger scroll and mouse wheel only).
  - `hover` — `UIHoverGestureRecognizer`: remembers where the pointer is.
  - `inkStroke` — `InkRecognizer` (own subclass): only touches the drawing hook claimed.
- Simultaneous recognition: `true` between the surface's own recognisers; `true` with any `UIScreenEdgePanGestureRecognizer` (the page's edge swipe) — the surface adds itself as a target and, when that swipe begins, gives the press up; `false` with everything else (a press on the board wins).
- Which touch goes where is decided once per touch in `gestureRecognizer(_:shouldReceive:)` (`verdict(for:)`; touches down are tracked weakly by identity + landing time and dropped when their phase is ended/cancelled):
  - first finger / pointer click → `fingerPress` (or `inkStroke` if claimed); a finger also goes to `twoPan` and `pinch`;
  - a further finger while one is down → only `twoPan` + `pinch`; the running press is given up (`.lost(takeBack: true)`) and nothing more of it reaches the board until that finger lifts; a finger's ink stroke is cancelled;
  - both fingers in the same moment → the press is ignored from its `.began`;
  - Pencil → `pencilPress` (or `inkStroke` if claimed); a running finger press is given up; fingers landing while the Pencil is down go to no recogniser.
- `Press` (startLocation, location, translation, time, kind finger/pencil/pointer, shift) replaces `DragGesture.Value` in `CanvasView.begin/update/finish`; `pressMoved` / `pressEnded` are the former `onChanged` / `onEnded` bodies, used by the Mac's `DragGesture` and by the layer. `PressPhase`: began, moved, ended, lost(takeBack).
- One press, by kind: finger — as 0.1 (4-point slop, idea lifts after 0.25 s, empty board slides); pointer — idea lifts at once, empty board draws the choosing box, Shift from `modifierFlags`; Pencil — idea lifts at once, empty board slides (until drawing claims it). Pointer and Pencil use exact press areas, a finger the finger-size ones.
- Press lost with `takeBack` (`CanvasView.pressLost`): a running move or resize is ended with `liveEnd(keep:)`, `keep = !Fingers.isShove(moved:after:)`; **shove = second finger within 0.5 s of the first, or moved less than 30 screen points** → the board goes back to where it was, no undo step. When not kept, `selection` / `selectedLink` are set back to what they were before the press landed. A slide of the view is kept. Lost without `takeBack` (system cancel): `resetPress()` as before (things stay as they stand).
- Two fingers (`TouchSurface.step`): at every change the middle between the fingers (`location(in:)` of whichever of `twoPan` / `pinch` is active with 2 touches) and the pinch's scale since the last step (the recogniser's `scale` is reset to 1 after each read, and at its `.began`) go to `Viewport.pinch(from:to:by:)` — the board point under the old middle lies under the new middle, scale × factor clamped to 0.2…3; sets `movedByOwner`. With fewer than two fingers down the board rests; a jump of the middle of 150 points or more in one step re-bases instead of moving. No inertia.
- Trackpad pinch: `zoom(to: scale × pinch.scale, around: pointer)`. Scroll: `pan(by: translation since last event)`; with ⌘: `zoom(to: scale × exp(clamp(dy, ±60) × 0.01), around: pointer)`. Pointer = last hover point, else the recogniser's location, else the middle of the view.
- Two presses within 0.42 s on empty board: `session.fit()` (eased 0.2 s) when `Finger.twoPressesFit` (true on iOS, false on the Mac → sticky note as before).
- `Info.plist`: `UIApplicationSupportsIndirectInputEvents = true` (via `project.yml`).

### Finger sizes — `App/Sources/FingerSizes.swift` (`Finger`, `pressRoom`)
- `Finger.on` (iOS), `Finger.phone` (idiom phone). `pressRoom(across, down)`: on iOS `padding(+)` → `contentShape(Rectangle())` → `padding(−)`: the press area reaches further than the look, layout unchanged; on the Mac nothing.
- iOS / Mac: chip height 36 / 28, press +4 above and below (44); chip and row gap 8 / 5; shape button 36 × 36 / 30 × 28, press +4 each side; zoom button 36 × 36 / 28 × 28, press +4, 6 extra points before "whole board"; Undo / Redo 36 × 36 / 30 × 28, press +4, gap 8 / 2; colour dot 30 / 22, gap 14 / 7, press +7 (44), row = `WrapRow` on iOS (wraps), plate = rounded rectangle radius 21 on iOS, capsule on the Mac; tool tile 40 × 40 both, press +3 on iOS (46); notice Undo: label = the whole pill, press +11 above and below; `FilledButton`: press +5 above and below; room beside the tools for the clusters 176 / 150.
- All identifiers are unchanged.

### Press areas on the board — `Core/…/Fingers.swift`
- `Fingers.button = 44`, `Fingers.control = 32`, `Fingers.close = 9` (screen points).
- `Fingers.control(at:boxes:onThing:least:close:)`: handles as drawn, in screen points. Caught within 9 points of the box always; up to a 32-point press area only when no thing lies exactly under the press; nearest wins. Finger: `least 32`; pointer, Pencil, Mac: `least 0` (9 points, as 0.1, but nearest instead of first).
- `Board.hit(_:scale:least:)`: exact hit first (as `hit(_:)`); otherwise every visible non-frame thing smaller than `least / scale` in a direction gets a press area of that size; nearest frame distance wins, ties to the topmost. Finger: `least 44`; pointer, Pencil, Mac: 0.
- The look of the handles is unchanged (`CanvasDraw` untouched).

### Readable iPhone — `Core/…/Viewport.swift`
- `resized(to:showing:readableAround:)`: with a main thing (iPhone only: `Board.mainThing` = middle idea of the first map, else first non-frame thing, else first frame) the board opens with `open(_:around:least: 0.75)`: fit as before when the whole board fits at ≥ 75 %; otherwise scale 0.75, main thing in the middle, but the view never goes past the board's edge (margins: 40 left/right, 70 top, 100 bottom); a direction in which the board fits is centred. Not a move by the owner.
- Typing zoom (`BoardSession.typing(in:)`, called from `CanvasView.onChange(of: editing)`, iPhone only): `typingBegan(round:least: 1)` — when scale < 1 and not already zoomed for typing: remembers the scale (`scaleBeforeTyping`), zooms to 1 keeping the thing's middle where it is on screen, then `reveal`. `typingEnded(round:)` — back to the remembered scale round the thing last typed in, `reveal`, and the board opens again as it stood if the owner had not moved it. While zoomed for typing, a changed room (keyboard) does not re-fit. A zoom by the owner or "whole board" while typing forgets the remembered scale.
- No stored fields. Stored format untouched.

### Tests
- `Core/Tests/SeedboardCoreTests/TouchTests.swift`, 7 tests: two fingers slide + zoom; shove taken back; small thing's press area + nearest wins; handle press area; iPhone opening; typing zoom; main thing. Core total 106 (was 99), all pass.
- `UITests/TouchUITests.swift` (written and compiled, not run): blank board, Bigger → 125 %, two presses on the canvas → 100 %, still "Empty". Skipped on the Mac.

## 4. For the lead

**The hook for Pencil drawing (pick 2)** — `InkHook` in `TouchLayer.swift`; plug it in at `CanvasView.touchLayer` (`TouchLayer(session:onPress:ink:)`, marked with a comment):
```swift
struct InkHook {
    var claims: (InkSample) -> Bool                       // asked ONCE when a Pencil, a single finger or the pointer lands
    var began: (InkSample) -> Void                        // the claimed stroke's first sample
    var moved: (_ real: [InkSample], _ predicted: [InkSample]) -> Void   // coalesced samples since last call + predicted ones
    var ended: (_ cancelled: Bool) -> Void                // cancelled = a second finger landed / the system took it
}
struct InkSample { location (view points, same room as Press.location → session.toBoard), force 0…1 (1 for finger/pointer), altitude, azimuth, time, kind (.pencil/.finger/.pointer) }
```
- `claims` is called before any normal handling. Return true and the touch never reaches choose / move; return false and it is a normal press. Typical: `sample.kind == .pencil && nothing under session.toBoard(sample.location)` (Pencil on empty board draws, on a thing moves it), or `drawToolOn` for a finger / pointer.
- Two fingers still slide and zoom while a finger draws; the second finger cancels the finger's stroke (`ended(true)`). A Pencil stroke is never cancelled by fingers (they are ignored while the Pencil is down).
- The samples come from `InkRecognizer` (`event.coalescedTouches` / `predictedTouches`), which Apple's own recognisers do not give. Not exercised by anything yet — no consumer exists.

**Decisions to check with the owner**
- Two quick presses on empty board now show the whole board on iPhone and iPad, per the brief; the sticky-note shortcut stays on the Mac only. It is documented in today's guide (lines 105, 260), so this takes a shortcut away on touch. To keep the sticky note: `Finger.twoPressesFit = false` in `FingerSizes.swift` (one line).
- The iPhone's selection bar is taller (chips 36 instead of 28, rows 8 apart): two rows are now 90 points high instead of 71. The colour dots take two rows on the iPhone (8 + 2). Pick 7 redesigns this bar anyway.

**Merging**
- `CanvasView.swift`: the bodies of `pressMoved` / `pressEnded` were left at their old indent ON PURPOSE so other builders' changes inside them merge cleanly — re-indent after the last merge. `begin/update/finish` now take `Press`; anything another builder reads from the value beyond `startLocation`, `location`, `translation`, `time` must be added to `Press`. Their snapping / arrow-end code runs for iPhone and iPad through the same functions.
- `target(at:)`: the handle loop became `Fingers.control(…)` and `board.hit(p)` became `board.hit(p, scale:least:)` — the arrow-end builder probably adds a case here too.
- `pinchGesture` is gone; `@State pinched` and `pinchBase` are still declared and now always false / nil on iOS (they can be deleted with their three uses after the merge).
- `Viewport.resized` got an optional third argument; `BoardSession.placeIfNeeded` passes it (pick 26 "reopen at its zoom and place" touches the same line).
- `project.yml` + `Info.plist`: one new key (`UIApplicationSupportsIndirectInputEvents`).
- SPEC lines that are now wrong: 74 (bar sizes), 186–187 (view; "there is no two-finger scroll handler"), 188 and 193 (press rules), 381.

**Pictures** (no new launch argument needed except one)
- iPhone: `-sampleData -board cabin` → opens at 75 % on "Summer cabin" (before: 50 %).
- iPhone / iPad: `-sampleData -board cabin -pick "Worth it"` → the bar with finger-size chips; add **`-colours`** (new) to show the colour dots open (two rows on the iPhone).
- No `ICON-WANTED`. No new marks.

**Left open**
- No inertia after a two-finger slide (Freeform glides on a little).
- With one finger lifted from a two-finger gesture the board rests until both are down again or all are lifted.
- Other screens (home list, Settings, Send page) were not resized — only the board screen named in the brief, plus `FilledButton` everywhere.
- The arrow's catch area is still 9 screen points for a finger.

**What only a real iPhone / iPad can prove** (the simulator cannot make these touches; nothing here was run on a device or simulator — both apps compile, the rules are tested as data)
1. A press still begins the moment the finger lands, and taps, drags, the 0.25 s hold and typing feel as in 0.1 (`UILongPressGestureRecognizer` with no delay).
2. Two fingers: slide and zoom together without a jump at the start (the slide begins after about 10 points, the zoom when the fingers' distance changes), when a finger is lifted, and when it comes back.
3. The first finger's shove is really taken back, and the selection does not flicker in a disturbing way, when the second finger lands a moment later.
4. iPad trackpad: two-finger scroll direction and speed, pinch round the pointer; mouse wheel step size (taken 1 : 1 from iPadOS — the Mac multiplies by 8); ⌘ + wheel.
5. iPad pointer: a click arrives as a pointer touch (choosing box on empty board, idea follows at once), Shift-click adds to the choice.
6. Pencil: taps and drags reach choose / move; a resting hand does not disturb; the Pencil taking over from a finger.
7. iPhone: the swipe back from the left edge over the board still goes back and leaves the board untouched; on iOS 26 a sideways slide on the board must NOT pop the page.
8. The press areas really reach beyond the look (44 points) — the `pressRoom` trick is standard SwiftUI but was not pressed by a finger here. If it should not reach, the buttons still work at their visible size (36).
9. iPhone typing: zoom to 100 % and back with the keyboard coming and going; a big board opening at 75 % in both orientations.
