# Built in 0.5 — lane "motion" (picks 1 and 3)

Branch `wt-motion`. Everything below is built. Both platforms build; 301 rule tests pass (7 new, `Motion05Tests.swift`).
No new stored field, no new page, no new identifier, no new mark, no new words on screen.

## Pick 1 — the board glides instead of jumping

Before: a zoom step, "Show the whole board", bringing a new idea into sight and the iPhone's zoom for typing all jumped in one frame. "Show the whole board" was wrapped in a 0.2 s animation in three places that could not work (the drawing is one Canvas): the drawing jumped and only the bar beside a chosen thing slid after it. Now: the board itself steps the view, frame by frame, so the drawing, the frame round a chosen thing, the bar beside it and the typing field always agree.

| Move | Time | Where |
|---|---|---|
| Zoom step of 25 %: the Smaller and Bigger buttons, View ▸ Zoom In ⌘+ / Zoom Out ⌘−, Actual Size ⌘0 | 0.22 s | the point in the middle stays exactly where it is; the "100 %" read-out counts along (half-way through a step from 100 % it reads 122 %) |
| Show the whole board: the button, ⌘1, the line in the right-click / press-and-hold menu of empty board, two presses on empty board on iPhone and iPad | 0.30 s | |
| Bringing an idea into sight: a new idea (Tab, Return, the plus), Shift-Tab, ⌘↑ / ⌘↓, walking a mind map with the arrow keys, a paste that lands out of sight | 0.18 s | the board slides just far enough, as before |
| The iPhone's zoom to life size when typing starts, and back when it ends | 0.18 s | if the keyboard comes up while that glide runs, the glide goes on to the new end instead of jumping |

- All glides are ease-out (quick at first, soft at the end: 87.5 % of the way after half the time).
- A finger or a click landing on the board, a scroll, a pinch, a slide, or a key (without ⌘) ends a glide at once, where it is. Pinch, scroll and slide stay 1:1 as before.
- Pressing a zoom button (or ⌘+ / ⌘−) again while a step still glides: the new step counts from the END of the running one, so three quick presses are three full steps (100 → 125 → 156 → 195 %), and the eye goes on from where the board shows.
- No glide when a board opens (it opens where it was left, at once), none when the window changes size, none on a timeline board (its own Today / scale steps are untouched).
- "Reduce Motion" on: everything jumps as in 0.4. Screen tests and pictures (`-sampleData`, `-stillMotion`): jumps.
- The three `withAnimation` wrappers are gone (`BoardView` zoom cluster, `CanvasView` two presses, `BarActions` menu line). The five in `TimelineBars.swift` / `TimelineView.swift` are the timeline lane's and were left.

## Pick 3 — things land, lift, leave, make room and fold softly

A small motion layer sits between the board and the live painter. It is on only while something is in motion; at rest it hands the painter the board itself.

- **Lands:** a new thing (a tool, a paste, a duplicate, a new idea, a thing brought back by Undo) grows from 92 % to 100 % round its middle and fades in, 0.16 s. Its mind-map branch fades in with it.
- **Leaves:** a removed thing fades out and shrinks to 94 %, 0.12 s (it is drawn on top for that moment). Its arrows go at once.
- **Lifts:** while a thing is dragged, by day its shadow goes from black 6 % / radius 2 / 1 down to black 16 % / radius 8 / 4 down in 0.10 s, and back in 0.10 s on the drop. Box, Rounded, Diamond, Oval: exactly those numbers. A sticky note: from its own 14 % / 3 / 1.5 to 16 % / 8 / 4. Things with no shadow of their own (the middle of a mind map, a picture, Person, Document, Slanted box, Store, a door): from none to 16 % / 8 / 4. By night no shadow changes; the outline is drawn 15 % lighter instead (a white line of 15 % over the thing's own outline). No glow. Words alone (an idea on a branch, free text), a sketch and a frame have no body and show no lift; whatever a dragged frame carries does.
- **Makes room:** whenever things stand somewhere else after a change that was not made under a finger, each glides from its old place and size to the new one, 0.20 s ease-out; arrows and branches follow. That covers a mind map laid out again (a new idea, typing that makes an idea wider, fold, move up / down, drop on a new parent), things pushed aside by a growing map, Line up, Even gaps, Same size, Undo and Redo — and also a nudge with the arrow keys, a drag that is taken back, and a newer version arriving from another device. A thing still gliding that is moved again goes on from where it shows.
- The thing being typed in never glides (it stays under its typing field); a thing under a finger follows the finger at once.
- The frame round a chosen thing and its knobs and plus-handles glide with the thing. The bar beside it is already at the end place (0.2 s).
- **Folds:** the ideas under a folded idea slide into it and fade, 0.18 s, then the dot with the number appears; unfolding is the reverse (they come out of the idea and fade in). The rest of the map closes up or makes room at the same time (0.20 s).
- **Off:** "Reduce Motion", screen tests and pictures (`Feel.moves`), boards with more than 150 things, timeline and "Who does what" boards (they draw themselves).
- The picture for PARAGON, the shared picture, the small pictures on the home page and the kept versions use the real board with no motion: always the end state. Nothing of this is stored.

## Launch words (DEBUG builds only, for pictures of a motion half-way)

- `-motionTry zoom | fit | add | child | remove | fold | move | lift` — makes that one change 0.8 s after the board shows; motion then runs even with `-sampleData`. `child`, `remove`, `fold`, `move`, `lift` need a chosen thing (`-pick <word>`).
- `-motionFreeze 0.5` — holds every motion at that part of its time (0…1), so a picture shows it half-way. Without it the motion plays for real.
- Example: `… -board Summer -pick Build -motionTry fold -motionFreeze 0.5 -sampleData`.
- Trap seen: by night put the words as `-pick "Make a plan" -motionTry lift -motionFreeze 1 -board Summer -night -sampleData`. Any word with a value AFTER `-night` (e.g. `-night -pick Worth`) leaves the app with no window at all (the system reads the left-over word as a file to open). Not mine, not fixed.

## What was seen running, and what was not

Seen on the Mac debug build (sample board "Summer cabin", pictures of the frozen half-way state and of the real end): zoom glide (read-out 122 % half-way, 125 % at the end), fold half-way and folded at the end, makes room with arrows following and the chosen frame gliding along, lands, leaves, lift by day and by night.

NOT seen: any of it in real motion with the eye (smoothness needs a look on a device — the note's own warning); nothing on iPhone or iPad (the iPhone's typing zoom glide, two presses on empty board, the keyboard arriving during the glide); the trackpad / finger cutting a glide; Undo / Redo, Line up, Even gaps, Same size, landing of a picture (they go through the same code as what was seen).

## For the join

New files: `Core/Sources/SeedboardCore/Glide.swift`, `Core/Sources/SeedboardCore/Motion.swift`, `Core/Tests/SeedboardCoreTests/Motion05Tests.swift`, `App/Sources/BoardGlide.swift`, `App/Sources/BoardMotion.swift`.

One-line hunks in existing files:
- `BoardSession.swift`: the `motion` property; `set` (tells the motion layer, one line before `board = fitted`); `live`, `liveEnd` (lift, drop); `pan`, `slide`, `zoom`, `pinch` (each begins with `stopGlide()`); new `stand(at:scale:)`; `typing(in:)` is renamed `typingJump(in:)` (the gliding `typing(in:)` is in `BoardGlide.swift`); `fit`, `placeIfNeeded`, `resized`, `reveal`.
- `CanvasDraw.swift`: the painter's `motion` property; the frames loop; one line at the top of the branch loop (`let ctx = motionLayer(…)`, which shadows the context so the branch fades — keep it the first line of the loop if the `looks` lane rewrites the branches); the things loop calls `drawInMotion`; `drawItem` is no longer `private`; the shape's and the sticky note's shadow lines go through `liftShadow(of:rest:)`.
- `CanvasView.swift`: the painter gets `session.shownNow` (3 lines where the painter is made); `session.stopGlide()` where a press lands and at the top of `handleKey`; the `withAnimation` wrapper gone.
- `BoardView.swift` (3 lines in `ZoomCluster`), `BarActions.swift` (1), `Menus.swift` (Zoom In / Zoom Out, 2), `TimelineSession.swift` (`actualSize`, 1), `ChosenFrame.swift` (2: the frame and the knobs read `shownThing(id)`).
- Likely to meet the `feel` lane in `BoardSession.pinch` / `zoom` and `CanvasView.begin`, the `looks` lane in the branch loop of `CanvasDraw`, the `door` lane in the `.door` drawing (a door needs nothing from this lane: it gets its lift from outside its own drawing).

A lane that adds a new way to move the view by a command should call it inside `session.glide(seconds) { … }`; a new way to move it by hand should begin with `session.stopGlide()`. A new painter for pictures needs nothing.

## Left for the lead to decide

- 120 pictures a second on an iPhone Pro: the clock asks for it, but iPhone gives it only when `Info.plist` holds `CADisableMinimumFrameDurationOnPhone = YES` (`project.yml`, not this lane's). Without it glides run at 60, which is fine.
- A nudge with the arrow keys now glides 0.2 s too (it falls under "makes room"). If it should stay instant, it is one line (`still:` in `noteMotion`).

## Drive-by, seen and left

- The `-night` word-order trap above.
- The plus-handle of a chosen folded idea lies on top of its dot with the number (was so before).
