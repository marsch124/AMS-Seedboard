# 0.14 lane timeline: ideas 18 and 29

## 18 Hide finished bars (built)
- What it does: leaves every done bar and milestone out of the rows (and a phase whose rows are all done; an empty phase stays). Rows below move up. Arrows to a hidden done bar are not drawn. Nothing is removed or changed; the picture of the board is the same code, so it follows the rows shown. Stored in `Board.hideDone` (true; removed when off). One Undo step.
- Words: button "Hide done" (becomes "Show done") in the timeline's own controls, after Today / Catch up; shown only when something is done (or hiding is on). While on, a small line above the controls: "3 done hidden · Show" (the word Show is a button). Mac menu (the one with Fold All Phases): "Hide Done Bars" / "Show Done Bars".
- Identifiers: `timeline.hideDone`, `timeline.doneHidden` (the line), `timeline.showDone`.
- Core: `Board.hidesDone`, `hiddenDoneIDs`, `hiddenDoneCount`; folded into `hiddenTimelineIDs`/`shownTimelineRows`. `shownPhaseGroups` now skips a hidden phase.
- Not: no keyboard key, no right-click line, not on read-only boards (button and menu off).

## 29 Plan against now (built)
- What it does: "Set the plan" writes each bar's and milestone's start/end into `Item.planStart/planEnd` (replaces an earlier plan). A bar whose days now differ gets a faint dashed outline (same colour, ~45% opacity) where it was planned, and its row name column shows small grey "2 days late" / "3 days early" (by last day; a bar that only changed length but ends on the planned day shows no words, only the ghost). A bar added after the plan has none. "Clear the plan" removes all.
- Words: More menu (timeline) "Set the plan", "Clear the plan" (off when no plan); Mac menu "Set the Plan", "Clear the Plan". Message after setting: "The plan is set: N rows as they stand today." One Undo step each.
- Identifiers: `more.setPlan`, `more.clearPlan`.
- Core: `Item.planSpan`, `slipDays`, `slipWords`, `movedFromPlan`; `Board.hasPlan`, `setPlan()`, `clearPlan()` (TimelinePlan14.swift).
- Not: no right-click line (no fitting mark); the word is not shown on a done bar differently; no "plan" day shown on screen.

## Tests
Core/Tests/.../Timeline14Tests.swift (3 tests). No screen test (no new page). Plan not set on bars without days.
## Not seen
No picture taken; ghost outline and the slip words' fit in a narrow names column not seen on screen.
## Files touched
Core: Timeline.swift, TimelinePlan14.swift (new). App: TimelineBars, TimelineDraw, TimelineSession, BoardView (More menu), Menus.
