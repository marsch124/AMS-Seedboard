# 0.3 small fixes (wt-fixes)

## 1. Who does what: a message with a missing name
Before: a message from a file made elsewhere that names someone who is not on the board was counted (the list line "3 messages", the numbers, the copied text, the note and the project for PARAGON) but never drawn. Select-all and the arrow keys could also land on it.
Now: a message counts only when both its names are on the board. Left out of the count line, the numbers (1, 2, 3 follow the drawn ones), the copied text, the Send texts and the "ticked messages decide" rule; select-all and Up/Down skip it. It stays in the file untouched.

## 2. Mac: Actual Size (⌘0) and Show the Whole Board (⌘1)
Before: on a Who-does-what board both worked (life size; the whole diagram, never bigger than life size). On a timeline ⌘1 worked (whole plan) but ⌘0 did nothing at all (it asked for a zoom of 1 on a board whose zoom is steps of days/weeks/months).
Now: on a timeline ⌘0 goes back to the standard size, the Weeks scale it opens in, the day in the middle staying put. ⌘1 unchanged. Nothing is greyed out; no line does nothing.

## 3. iPhone: the "main thing" of a Who-does-what board
Found: "main thing" is the spot a small screen opens on (75 % zoom, `Board.mainThing`). On a Who-does-what board it took the first item's own stored place, which means nothing there (every item sits at 0, 0), so the opening was centred on the wrong box (the top-left corner of the empty board, not where the first name stands).
Now: it opens on the first name's box as the layout puts it. Sure of the cause; the exact on-screen change is small (a few points) and not seen on a screen.

## 4. Send to PARAGON as a project: the tally
Before: shapes inside lanes of a frame were counted as "ideas" ("all 2 ideas become tasks").
Now: they count as shapes ("Nothing is ticked: all 2 shapes become tasks."), as the flow shapes outside lanes do.

## 5. Narrow iPhones: tool rows
Worked out for a 375-wide iPhone (355 usable): a tile is its word plus 14, at least 50 wide; gaps 6; plate padding 12.
Timeline: Bar 50 + Milestone about 62 + Phase 50 + Comes after about 72 = 234, plus 18 gaps, plus 12 = about 264. Who does what: Who 50 + Message about 54 + Note 50 + Section about 52 = 206 + 18 + 12 = about 236. Both fit with 90 or more to spare (also a 320-wide SE: 300 usable). Nothing changed.

## 6. Mac: key S for Draw
Before: the Draw tool had no letter. Now S (Sketch) switches Draw on and off when nothing is chosen and no words are typed, as the other letters do. Its help text says "Draw (S)"; the Insert menu has a new line "Draw" with S, after the two extra shapes. On timeline and Who-does-what boards the key does nothing and the menu line is greyed (their Section tool's S is its own, unchanged).

## 7. iPad with trackpad
Before: `ScrollCatcher` is Mac-only (inside `#if os(macOS)`), so on iPad a timeline or Who-does-what board ignored a trackpad's two-finger scroll and ⌘-scroll. Both already had a `MagnifyGesture` for a pinch on the glass.
Now: a new `TrackpadCatcher` (iPad only) with a scroll recogniser (no touch types, all scroll types): two-finger scroll or mouse wheel slides the board, ⌘ + scroll zooms round the pointer. I did not add a second pinch recogniser, to avoid zooming twice: a trackpad pinch relies on the boards' existing `MagnifyGesture`.
Not provable in the simulator.

## For the lead
Files: Core `Sequence.swift`, `ProjectPlan.swift`; App `BoardSession.swift` (selectAll, one opening line), `SequenceSession.swift` (selectStep), `TimelineSession.swift` (actualSize), `Menus.swift` (Actual Size line, Draw line), `CanvasView.swift` (key S), `InkViews.swift` (help), `TimelineView.swift` / `SequenceView.swift` (one `#else` line each), new `TrackpadCatcher.swift`. Run `xcodegen generate` after merging.
Tests: new `FixesTests.swift`, 2 tests (missing names; lane shapes tally). Core total 260, all pass. Mac and iOS Simulator builds succeed.
Not proven on a device: the trackpad scroll and ⌘-scroll on iPad (the recogniser sits on the screen's top view and answers only inside the board's box); a trackpad pinch on those boards; the new opening spot on iPhone; ⌘0 on a timeline and key S were not clicked (no screen use).
Guide.swift: add S (Draw) to the list of keys; if it says ⌘0 is "actual size" generally, say that on a timeline it goes to Weeks; the Who-does-what text could note that a message with a missing name is not shown.
