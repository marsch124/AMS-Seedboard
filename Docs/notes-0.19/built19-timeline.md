# 0.19 timeline lane: picks 26 to 32 (branch wt19-timeline)

Files: Core `Timeline19.swift` (rules), test `Timeline19Tests.swift` (5 tests), App `Timeline19.swift` (pages, marks enum, switch, spring, bubble), small edits in TimelineView / TimelineDraw / TimelineBars / BarActions / BoardMenu / Menus / BoardView. No new stored field (uses Item.note and Item.initials from the groundwork). Guide, SPEC, project.yml untouched.

SF Symbols (all in `enum Marks19Timeline`, App/Sources/Timeline19.swift): note = "note.text", repeatBar = "repeat", who = "person.crop.circle". There is no SF-symbol Glyph case in the app, so the three chips use `Image(systemName:)` directly; the Mac menu lines carry no icons (MacMenu shows words only).

## 26. Drag a bar between rows (soft gap)
- Before: dragging ONE bar up or down already moved its row (row changes after 0.2 row of dead zone), but rows below jumped instantly, and the bar snapped from row to row.
- Now: same rule (same threshold, same result, one Undo step), plus: the dragged bar follows the finger smoothly between two rows (offset = rest of the drag after the dead zone), and every row that is pushed aside starts where it was and slides to its new place on a spring (response 0.34, damping 0.66; a small bounce). Also used when a row is dragged by its NAME (carryRow, phases too). Off when "Reduce Motion" is on (Feel.moves false): then rows jump as before.
- Not done: phase bands and grid lines do not spring (only bars, diamonds and names).
- Could not see it move (no simulator). The spring is a `SpringFrame` (Animatable view) around the Canvas; `painter.rowShift` carries the offsets.

## 27. Note on a milestone
- Chip "Note" in the chosen bar of a milestone or bar (id `sel.note`; filled when a note exists). Mac right-click on a bar/milestone: line "Note…" (id `menu.note`). Page "Note": multi-line field (id `note.field`), counter "n of 280 letters", buttons Cancel (`note.cancel`, Esc) and Save (`note.save`, Return). Empty text takes the note away. Page id `timeline.notePage`.
- A row with a note shows a tiny note mark (SF "note.text" on a small round, neutral ink) right after the end of the bar / milestone. Tap on the bar or milestone: the note shows in a small bubble above it (below in the top rows), id `timeline.noteBubble`; it closes at the next press elsewhere or by tapping the bar again. Double-tap still edits the name.
- Bars may use it too: yes, same code (trivial).
- Limit 280 letters. The mark also shows in the picture that goes to PARAGON.

## 28. Dates big while held
- Before: the dates showed only after the bar moved (11 pt, small plate), form "1 Dec – 12 Dec 2026 · 12 days".
- Now: shown while held (after 0.28 s without moving) and while dragged or stretched, at 17 pt semibold on a plate 32 high, live, above the bar (below in the top row). Words: "1 Dec – 12 Dec · 12 days"; the year only for a day outside the current year ("1 Dec 2026 – 12 Jan 2027 · 43 days"); one-day bar "1 Dec · 1 day"; milestone "1 Dec". (Core: `Item.spanCallout`.) Only for one chosen bar. A plain quick tap does not flash it.

## 29. Weeks / Months switch
- Two buttons "Weeks" and "Months" in a small capsule ABOVE the zoom plate (right side, bottom of the screen, in the zoom cluster; I did not put it in the top bar because the zoom lives at the bottom, say if you want it elsewhere). ids `timeline.scaleSwitch`, `timeline.weeks`, `timeline.months`. The active one is full colour (timeline colour).
- Relation: it sets the same scale as the zoom. The zoom's minus / plus still step Days, Weeks, Months, and its middle word (`zoom.value`) still shows the current scale including "Days". At Days neither button is on. So the word "Weeks"/"Months" appears twice (switch and zoom word) but always says the same thing.

## 30. Group by colour
- Words: More menu (iPhone / iPad / Mac toolbar): "Group by colour" (id `more.groupColour`, matching its neighbours' sentence case); Mac Board menu bar: "Group by Colour"; Mac right-click on a timeline: "Group by Colour". Disabled when the colours already stand together or the board cannot be changed. Says "Grouped by colour: 3 colours." (or "The colours are in groups already.").
- Rule (Core `groupByColour`): bars and milestones of one colour stand together; colours in order of FIRST appearance from the top, over the whole board; inside a colour the old order; a colour is the item's own (empty = blue for bars, orange for milestones). Phases are headings and stay where they are; rows are grouped inside each phase block separately (rows above the first phase form their own block). Links untouched. One Undo step.

## 31. Repeat
- Chip "Repeat" (`sel.repeat`) in the chosen bar or milestone; Mac right-click line "Repeat…" (`menu.repeat`). Page "Repeat": segmented Day / Week / 2 Weeks / Month (`repeat.every`), stepper "6 times in all" 2 to 12 (`repeat.times`), a summary line (`repeat.summary`: "It comes 6 times: 1 Dec to 5 Jan. 5 copies go on the rows under it, as long as the bar and in its colour."), Cancel (`repeat.cancel`) / Repeat (`repeat.go`, full colour). Default: every Week, 6 times. Says "5 copies made, under the bar."
- Decisions for the lead: (a) "times" counts the bar itself as the first (6 times = the bar + 5 copies; min 2 makes sense that way). (b) "on the same row" is NOT possible: a timeline row holds exactly one item (rows are a list order). Copies go on the rows right under the bar, in date order, each as long as the bar, in its colour, with its name, who and note; not done, no plan, no "comes after". (c) Month keeps the day of the month, or the last day of a shorter month (31 Jan then 28 Feb). Copies outside 1900 to 2200 are left out. One Undo step.

## 32. Who does it
- Chip "Who" (`sel.who`; on when set) for a bar; Mac line "Who…" (`menu.who`). Page "Who does it": field "Initials, one to three letters" (`who.field`; letters only, capitals at once, max 3), Cancel (`who.cancel`) / Save (`who.save`). Empty takes it away. Bars only.
- A small round (16 pt) at the start of the bar inside it (bar at least 34 pt wide) or before its start when the bar is short; neutral grey fill (light 0.88, night 0.30), grey edge, ink letters. Not a signal colour.

## Tests
- Core: `Timeline19Tests.swift` (callout words, note and initials clean, group by colour with phase, repeat with colour/length/rows, monthly dates). Core total 559 passed.
- Screen test written, compiled only, NOT run: `UITests/Timeline19UITests.swift` (switch, then the three pages by identifier).

Signs: Note mark ("note.text" tiny round after a bar or milestone) = this row has a note, tap the row to read it. Grey round with letters at a bar's start = who does it. Weeks / Months capsule = the scale in one press. No new colour.

Not seen: all screens (no simulator by rule). Not done: no Guide / SPEC text. Merge hint: my edits to BoardView.swift (one Button in More), Menus.swift (one Button), BoardMenu.openTimeline (two lines swapped), BarActions.timelineMenu (new lines) are small and may touch other lanes' neighbours.
