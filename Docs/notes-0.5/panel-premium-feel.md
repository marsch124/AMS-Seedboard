# Panel before 0.5 — premium feel (18 Nov 2026)

Lens: motion, touch feedback, first impression, empty states, day and night colours, the board's look, the home page, tool tiles, the bar, sheets. Read from the code at commit a6e6f58 (0.4, build 4), `Docs/SPEC.md`, and the pictures in `Docs/pictures/0.3` and `0.4`. Nothing was built or run; what only a device can show is marked "not seen on a device".

Not proposed again: picks 9, 22, 23, 27 of `PANEL-0.2.md` (turned down).

## Where it already feels careful
- The colours: one colour per part, kept through tools, bar, headings and sheets; bright paper notes at night; the purple for everything that leads to PARAGON.
- The board's drawing: rounded arrow corners, arrows side by side, the frame that follows a shape's own outline, the faint day shadow under shapes, hand-drawn marks everywhere.
- Finger sizes and the one-row bar: nothing wraps, nothing is too small to press.

## Where it feels like a prototype — in one line
Nothing moves and almost nothing answers. In 18,000 lines there are 7 animations (all "whole board" / Today), 3 haptics, no hover state, and no pressed state of the app's own. Things pop in, jump and vanish. The ten findings below are ranked by how much each lifts the app.

---

## 1. The board glides instead of jumping — BUG + IDEA
**Today:** Zoom in / out by button or key changes the size in one jump of 25 % (`BoardView.swift:382, 388`; `BoardSession.swift:677-684`). When a new idea lands outside the view, the board jumps to it (`BoardSession.swift:745-755`). On the iPhone the view jumps to life size when typing starts and jumps back after (`BoardSession.swift:694-714`). "Show the whole board" is wrapped in a 0.2 s animation in three places (`BoardView.swift:389`, `CanvasView.swift:580`, `BarActions.swift:429`), but the drawing is one Canvas, which cannot be animated that way: the drawing jumps at once, and only the bar beside a chosen thing slides after it for 0.2 s (this part is the BUG; not seen on a device).
**Better:** One glide for every move of the view that the owner did not make with his own fingers. The session steps the view itself, frame by frame, from where it is to where it shall be, so drawing, frame, bar and typing field always agree.
- Zoom step (buttons, ⌘+ / ⌘−, Actual size): 0.22 s, ease-out; the point in the middle stays put; the "100 %" read-out counts along.
- Whole board / two presses on empty board: 0.30 s, ease-out.
- Bringing a new idea into sight, and the iPhone's zoom for typing: 0.18 s.
- A finger, a scroll or a key landing during a glide ends it at once, where it is. Pinch and slide stay 1:1 as today.
- "Reduce Motion" on: jumps as today.
- Remove the three `withAnimation` wrappers.
One small data test: half-way through a zoom glide, the board point under the middle is still under the middle.
**Size:** M. **Risk:** low–medium. One new timer in the session; screen tests read the end state, so they wait 0.3 s at most. Must never fight the "opens where you left" rule (no glide when a board opens).

## 2. The hand feels what happens (haptics) — IDEA
**Today:** Three haptics in the whole app: an idea lifts after a hold (`CanvasView.swift:411`), the same on a "Who does what" board (`SequenceView.swift:365`), the press-and-hold menu opens (`BoardMenu.swift:211`). Falling in line with a guide, joining an arrow, dropping an idea on a new parent, ticking To do and a finished Send are silent. The Mac trackpad gets nothing.
**Better:** One small file (`Feel.swift`) with eight named moments, so every place uses the same one:
1. **Catch** — a guide line appears while dragging or sizing (`CanvasView.swift:446, 455, 458`): iPhone selection tick; Mac trackpad `alignment` tick (the same one Keynote gives). At most one per 0.12 s.
2. **Lift** — a shape, note or picture starts to move (`CanvasView.swift:415-417`): light impact, strength 0.6.
3. **Set down on a target** — an idea dropped under another idea, a map hung on a map (`CanvasView.swift:495, 502`): rigid impact, 0.7.
4. **Joined** — an arrow lands on a shape (`CanvasView.swift:508, 524, 548`): rigid impact, 0.8.
5. **To do on** — light impact (off: nothing).
6. **Exactly 100 %** — a pinch passes life size: one selection tick; Mac `levelChange`.
7. **Sent** — Send succeeded: success notification. **Not sent:** error notification (`SendSheet.swift:200-212`).
8. **The end** — pinch reaches the smallest or largest zoom: rigid impact, 0.5, once.
Nothing while the Pencil draws. Nothing for plain button presses (too much buzz cheapens it).
**Size:** S. **Risk:** low. iPad has no haptic motor (only with a trackpad or Pencil Pro), so this is felt on iPhone and on the Mac trackpad.

## 3. Things land, lift and leave softly — IDEA
**Today:** A new shape is simply there (`BoardSession.swift:380-392`). A removed thing is simply gone. When an idea is added, the whole mind map is laid out again and every branch jumps to its new place in one frame (`BoardSession.swift:102-113`). A thing being dragged looks exactly like a thing lying still — the same 6 % shadow (`CanvasDraw.swift:323-325`). Fold / unfold: the ideas under it blink away.
**Better:** A small motion layer in the painter, on only while something is in motion (0 cost at rest):
- **Lands:** a new thing grows from 92 % to 100 % and fades in, 0.16 s ease-out.
- **Leaves:** fades out and shrinks to 94 %, 0.12 s.
- **Lifts:** while dragged, by day the shadow goes from black 6 % / radius 2 / 1 down to 16 % / radius 8 / 4 down, in 0.10 s, and back on the drop. By night (shadows do not show on charcoal) the outline is drawn 15 % lighter instead. No glow.
- **Makes room:** when a mind map is laid out again, every idea and branch glides from its old place to the new one, 0.20 s ease-out. Same for Line up, Even gaps, Same size and Undo / Redo.
- **Folds:** the ideas under a folded idea slide into it and fade, 0.18 s; unfold is the reverse.
- "Reduce Motion" on: off. Boards over 150 things: off (no speed work is asked for).
The picture for PARAGON and the small pictures always draw the end state.
Trap for the builder: the app has its own `TimelineView` (`App/Sources/TimelineView.swift`), so Apple's frame clock must be written `SwiftUI.TimelineView`.
**Size:** L. **Risk:** medium. Touches the one painter everything goes through; must be cut the moment a finger lands; needs one real-device look for smoothness. Can ship without the "Makes room" part first (then M).

## 4. Buttons show the press; the pointer is noticed — IDEA
**Today:** Every tool tile, bar button, zoom button, card and list row is a plain button with no pressed look of its own (`BoardView.swift:364, 408, 516`; `ChosenBar.swift:170, 180, 203, 238`; `HomeView.swift:199, 245`; `RootView.swift:199, 260`). The full-colour main button goes 25 % see-through while pressed (`Theme.swift:106`, `Look.swift:48`), so the board shines through it — washed out, close to grey. On the Mac and with an iPad trackpad nothing reacts when the pointer is over a tile, a card or a row (no hover code outside the lanes, `LanesView.swift:316`).
**Better:** One button style, `PressStyle`, used everywhere in place of `.plain`:
- **Pressed:** the tile shrinks to 95 % and its soft tint doubles in strength, in 0.08 s; it springs back in 0.18 s.
- **Main button pressed:** stays solid, 12 % darker, 97 % size. Never see-through.
- **Pointer over (Mac, iPad trackpad):** tile and bar button — tint one step stronger; list row — a 5 % wash; home card — its edge turns boards green at 60 % and its shadow goes from 6 % / radius 2 to 12 % / radius 6, in 0.12 s. On the iPad, cards also take Apple's own `lift` pointer effect.
**Size:** S–M (one style, about 20 call sites). **Risk:** low. Identifiers do not change.

## 5. Send feels like a hand-over — IDEA
**Today:** The moment the app exists for is the quietest one. Send → the button says "Sending…" (`SendSheet.swift:147`) → the page closes → a green capsule with one line for 4 s (`AppModel.swift:532` → `BoardView.swift:125-131`), the same green capsule that says "Nothing to paste." Nothing to press, nothing felt.
**Better:**
- On success the Send button shows a white hand-drawn tick on purple for 0.45 s, then the page closes (success haptic from finding 2).
- The line that follows is PARAGON purple (#6B4EA8 day, #7F62C6 night) with the send mark in front, and a small "Open" pill at its end (white words on white 22 %, the same pill as the notice's Undo, `BoardView.swift:104-110`). It opens the new note in PARAGON (`AppModel.openInParagon` exists). It stays 6 s instead of 4. No "Open" for "Only the to-do boxes" (there is no note).
- The identifier `board.flash` stays.
**Size:** S. **Risk:** low.

## 6. The empty board and the first start invite — IDEA
**Today:**
- An empty board: two grey lines in the middle, "An empty board / Press a tool below to start, or paste a list to get a mind map." (`BoardView.swift:52-64`). Below wait nine tiles with marks only; their names show on the Mac under the pointer and nowhere on iPhone and iPad.
- First start on the iPhone: the list, a green button, and one grey line "No boards yet. Press New board." (`RootView.swift:119-123`). The Mac and iPad get a home page with drawings; the iPhone gets a line.
- An empty board's card says "Empty" in grey (`HomeView.swift:217-221`).
**Better:**
- Empty board: the sprout mark, 40 points, boards green at 70 %; the line "What is on your mind?"; under it three starting buttons in their own colours, each with mark and word: **Mind map** (pink), **Sticky note** (amber), **Paste a list** (green; pale when nothing is copied — asked with `hasStrings`, which shows no paste banner). 36 high on iPhone / iPad, 28 on the Mac. One press does what the tool does and the invitation fades in 0.15 s. The Mac adds one quiet line: "or double-click anywhere for a sticky note" (true today, `CanvasView.swift:583-588`). No words under the tool tiles (that was turned down).
- iPhone with no boards: instead of the grey line, the sprout, "Plant a seed", and the starter cards themselves (the existing `StarterCard`, two in a row). One press makes the first board. They leave when the first board exists.
- Empty card: a faint sprout (22 points, 35 %) instead of the word.
**Size:** M (three small parts). **Risk:** low. `board.empty` keeps its identifier; new ones `empty.mindmap`, `empty.note`, `empty.paste`.

## 7. Home shows his boards first, one green button — IDEA (picture first)
**Today:** (pictures `0.3/ipad-home-starters.png`, `0.4/mac-starters-heading.png`)
- The nine starter cards fill the first screen: three rows, about 820 of 1366 points on an upright iPad, about 600 of 760 on the Mac. His own boards — what he comes back for — begin below, half cut off (`HomeView.swift:51-56` before `58-60`).
- Two solid green "New board" buttons are on screen side by side (`RootView.swift:78-92`, `HomeView.swift:94-103`), though 0.2 decided that it is "the only solid green in the list". Pressing either lays the same nine cards over the nine already showing.
- A board card cannot be pressed and held: Rename, Pin, Colour, Remove are only in the list (SPEC 2.1 Note).
**Better:**
- Starters become one strip that slides sideways: cards 132 wide, picture and name, no grey line, 8 apart, "Edit" at the right as today. It costs about 140 points of height instead of 600–820.
- Then Pinned, Recent, Sent to PARAGON as today — now in sight at once.
- The header keeps the sprout and "Plant a seed" and loses its button; the list's "New board" is the one green button again.
- Board cards get the list's own press-and-hold menu (`RootView.swift:275-295`).
**Size:** M. **Risk:** medium — it moves things he has seen and may like. One picture with before / after, numbered, before any building; the picker ("Starters", large, centred — his word in 0.4) is not touched.

## 8. Mind-map branches: thick to thin, words on the line — IDEA (picture first)
**Today:** Every branch line is 2.6 points, from the middle idea to the last twig (`CanvasDraw.swift:250-251`). An idea on a branch is bare words standing beside the end of its line (`CanvasDraw.swift:308-310`); only the first level is bold (`CanvasDraw.swift:79`). It reads as words joined by wires.
**Better:** Two steps, shown side by side in one picture:
- **A (weights only, size S):** main branch 3.4, second level 2.4, third and deeper 1.8. The map gets a trunk-and-twigs rhythm at no risk.
- **B (A + words on the line, size M):** the branch line runs on under the idea's words as an underline in the branch colour, 2 points under the words, and the ideas under it start from the end of that underline. Each idea then sits on its branch — the look of the best mind-map apps. Press areas and the chosen frame stay as they are.
**Risk:** A none. B medium: the lines meet an idea at its foot instead of its middle, so every mind-map picture in the docs, the small pictures and the PARAGON picture change (same painter — wanted, but to be looked at).

## 9. Small pictures that can be read — IDEA
**Today:** A small picture is the whole board shrunk, at most 60 % (`BoardThumb.swift:59`). Words come out 2–3 points tall — grey fuzz. A timeline is a strip one sixth of the card's height in an empty card (Timeline and Trip plan in `0.3/ipad-home-starters.png`). Lines thin out to hairlines. The picture pops in when it is ready (`BoardThumb.swift:141-146`).
**Better:** The painter learns it is drawing small:
- Words that would be under 5 points tall are drawn as soft rounded bars (ink at 22 %, 40 % of the line's height) — shapes of text instead of fuzz. Words of 5 points and more stay words.
- No line thinner than 1 point in the picture.
- A timeline's picture shows only the days that have bars (one day of air each side) and fills the card's height.
- The picture fades in over 0.15 s.
Kept per version as today, so no extra work on a redraw.
**Size:** M. **Risk:** low–medium (one more switch in the painter; the PARAGON picture is not touched).

## 10. Eight small rough edges, fixed together — BUG
1. **Night: white words on pale lavender.** On the iPad by night the Send button in the top bar is #A387EC, not the #7F62C6 the code asks for (`Look.swift:31`; measured in `0.3/ipad-picture-night.png`) — the top bar lightens it. White on it is 2.9 : 1 (the spec promises 4.7 : 1). Make the fill hold its colour in the top bar; check iPhone and Mac by night too.
2. **The "not in iCloud" dot is white on the chosen row** (`RootView.swift:266`) — a leftover from 0.1's solid green row. The row is now a pale tint, so by day the dot cannot be seen. Amber always.
3. **List dots use day colours at night** (`RootView.swift:236`, `Paint(night: false)`), the cards beside them use night colours (`HomeView.swift:212, 227`): one board, two shades. Follow day / night.
4. **"Board removed. It is kept for 30 days…" is said where nobody sees it** (`AppModel.swift:353`): the line is drawn only inside an open board (`BoardView.swift:125`), and the board has just closed. Draw the line at the window's level.
5. **Every message is happy green**, also "The picture could not be made." (`Menus.swift:83`) and "That could not be read as a picture." (`ClipBoard.swift:234`). Problems in brick red (`Part.kept`), PARAGON in purple, the rest green.
6. **Messages pop.** The green line, the Undo notice, the arrow banner and the lines at the top appear and vanish in one frame (`BoardView.swift:71-133`). Slide up 8 points and fade in, 0.18 s; fade out 0.25 s.
7. **The press-and-hold menu's fade never runs** (`BoardMenu.swift:133` asks for it, nothing starts it). Open: fade in and grow from 96 %, 0.12 s; close: fade, 0.10 s.
8. **Three plates side by side, two looks.** On the iPhone the tool row casts a shadow (`BoardView.swift:345-347`); the Undo and zoom boxes beside it are flat outlines (`BoardView.swift:393-394, 502-503`). Give both the bar's own shadow (black 10 %, radius 5, 2 down — `ChosenBar.swift:64`).
**Size:** S–M all together. **Risk:** low. Item 1 needs a real look by night on all three devices.

---

## Looked at and left alone
- The chosen frame is always green while the bar takes the chosen kind's colour (`ChosenFrame.swift:160`): two colours for one choice, but green as "this is chosen" is a clear rule — keep.
- "How it works" is one long page with every heading green (`SettingsView.swift:101-122`). It could wear each part's colour and mark and fold by part; a matter for the guide's own round, not for feel.
