# Lane access — items 12, 14, 15

## What's new
- 12: Before, VoiceOver saw a whole board as one element called "Board". Now every thing and every arrow on an ordinary board is read out on its own, in outline order, e.g. "Idea: Roof, done, 2 votes". Each has the actions Choose, Edit words and (where it can move) Move left / right / up / down, 10 points each.
- 14: Checked all 29 fixed letter sizes: every one is drawn board text, an invisible 1-point test label, or a typing field that must match drawn text. None is a button, chip or bar label (those already use Apple text styles, 96 places). So nothing changed here; the default look is untouched.
- 15: With "Differentiate Without Colour" on, a late timeline bar shows slanted white strokes on its red end, a late milestone has a dashed outline, and the colour legend card writes the colour's name before its words ("Yellow: Ideas"). Done bars already carry a tick mark. Off by default: no change at normal settings.

## How it works
- VoiceOver on a board: swipe moves through the things from the top (mind maps first, branch by branch; then the rest row by row; then arrows). Open the actions rotor to Choose, Edit words, or move a thing by 10 points. Ideas in a mind map place themselves, so they have no Move. Pinned things do not move.
- With the system setting Differentiate Without Colour, late bars and colour meanings show a pattern/word as well as colour.

## Spec
- Core `Access11.swift`: `Board.spoken(_:)`, `Board.spokenThings` -> `[SpokenThing]` (id, isArrow, sentence, canMove, canEdit). Sentence = kind word + ": " + words (lines joined by a space), then ", done" (doneDay set), ", to do", ", 1 vote"/", N votes", ", pinned", ", folded". Arrow: "Arrow from A to B: words" (a thing with no words is named by its kind, lowercase). Timeline and "Who does what" boards give an empty list.
- App `Access11.swift`: `BoardAccessChildren`, used by `CanvasView` via `.accessibilityChildren`; identifier "board.canvas", label "Board" and the count value stay on the canvas. Actions named "Choose", "Edit words", "Move left", "Move right", "Move up", "Move down" (move uses the arrow-key nudge of 10).
- `TimelinePainter.patterns` (set from `accessibilityDifferentiateWithoutColor` in TimelineView); hatch in `TimelineProgress.drawState`; legend word in `LegendCardRow`.
- Test: `Access11Tests.testSpokenSentenceAndOrder`.

## Pictures
Nothing to see at normal settings. For 15: turn on System Settings > Accessibility > Display > Differentiate Without Colour; `-board <timeline sample>` with a late bar; a board with a legend. VoiceOver check on a sample board.

## Not done / doubts
- 13 (timeline bars, "Who does what" messages) not built; timeline/sequence views still one element.
- Not tested with VoiceOver on a device: `.accessibilityChildren` over a Canvas should keep identifier "board.canvas"; screen tests that look for it should be run once by the lead.
- 14: the spec's "largest text sizes" check remains a visual matter on cards, which already use text styles.
