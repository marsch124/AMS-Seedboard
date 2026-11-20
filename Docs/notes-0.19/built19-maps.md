# Seedboard 0.19 — lane "maps" (branch wt19-maps)

Core: `Core/Sources/SeedboardCore/Maps19.swift` (new), small edits in Arrows.swift (Arrow gets `plainMiddle`, `through`; `unit` no longer private), Outline.swift. Core tests: `Maps19Tests.swift` (4 tests, all green; 558 total).
App: `App/Sources/Maps19.swift` (new; SF Symbol enum `Marks19Maps`, session methods, Grow plate), edits in ArrowDraw, CanvasView, CanvasDraw, BranchLook, BarActions, MapCommands, BoardView. UI test: `UITests/Maps19UITests.swift` (More menu shows the two new lines; compiled, not run).
New `Glyph.system(String)` case (BoardView.swift) so a bar/menu line can wear an SF Symbol. Other lanes may add the same case: merge by hand.

## 13 Bent arrows
- Before: arrows could not be bent. Now: a chosen arrow shows a small diamond knob in the middle (end dots stay round). Drag it: the arrow becomes a smooth curve through that point (two curves meeting with the same direction, any line style). Knob is hollow when straight, filled when bent. Press twice on the knob = straight again. Live drag, one Undo step on let-go. Read-only boards: no knob drag.
- Stored: `Link.bend = [dx, dy]` from the plain line's middle; under 4 points = straight (nothing stored).
- Menu of an arrow (right-click / press-and-hold): new line "Straighten" (grey unless bent; symbol `line.diagonal`). Bar of a chosen bent arrow: "Straighten" appears (wide word). Mac Board menu: "Straighten the Arrow".
- Dashes: Link.dashed already existed. The arrow MENU said "Dashed"; now "Dashed (maybe)" (id menu.dashed). The bar button still says "Dashed" (left; say if you want it changed too).
- Rules in Core: `Route.bent`, `Route.bentPieces`, `Route.bend(toReach:plainMiddle:)`, `Route.takesKnob` (reach 13 points on screen), `Board.bendLink`, `straightenLink`, `knobHit`.
- ids: none new on the knob (it is drawn). Menu: menu.straighten.

## 20 Branches thick near the middle
- Before: even strokes, 3.4 / 2.4 / 1.8 by depth. Now (lines and curves looks): tapered filled line, main branch 5 pt at the middle idea down to 3.4 at the far end of the words' underline; second level 3.4 to 2.4; third 2.4 to 1.8; deeper 1.8. Round ends. `Route.branchTaper`.
- Boxes look uses an even 1.8 line.

## 21 Number the Branches
- Mac Board menu: "Number the Branches" / "Stop Numbering the Branches". iPhone/iPad More menu (and Mac More): "Number the branches" / "Stop numbering the branches" (id more.numberBranches), shown on boards with a mind map.
- Numbers 1, 2, 3 … on main branches: right side top to bottom, then left side top to bottom, per map. Look = the step-number badge (round, 17 pt, white ring) but filled in the BRANCH's colour, at the top outer corner of the branch's words (not in front of the words: no room in the layout). Stored `Board.numberBranches`.
- As text: yes. "Copy as text" (`outlineText`) writes "2. Food" for main branches when on. PARAGON task text is NOT changed (only the plain-text copy).

## 22 Move to the Other Side
- Menu line "Move to the Other Side" (symbol `arrow.left.arrow.right`, id menu.otherSide) on a main branch of a both-sides map; Mac Board menu same words. The branch (with all under it) goes to the other side and stands last there. One Undo step. Not offered for deeper ideas, one-sided maps, read-only.

## 24 Map look
- "Map Look" submenu (Mac Board menu; More menu "Map look", ids more.mapLook, more.mapLook.lines / curves / boxes) with the words Lines, Curves, Boxes (check mark on the one in use). Stored `Board.mapLook`.
- nil (nothing stored) = Curves = what 0.18 drew (smooth curve to the branch, underline under the words). Choosing Curves stores nothing again.
- Lines: same but straight to the branch. Boxes: each idea (not the centre) in a rounded box (soft fill, branch-colour edge, 1.6 line; 5 x 2 pt around the words), joined by thin right-angle lines with 8 pt rounded corners. Undoable.

## 25 Grow Ideas from This
- Menu line "Grow Ideas from This" (symbol `lightbulb`, id menu.grow) on an idea with words; Mac Board menu same. Opens a small sheet: heading "Grow Ideas from This", the idea's words, "Thinking on this device…", then up to 3 chips (ids grow.chip.0..2). A chip press adds it as a child idea (last) and the chip goes; "Add All" (grow.addAll, full colour, Return) adds the rest and closes; "Cancel" (grow.cancel, Escape) becomes "Done" once something was added. Nothing found: "No suggestions for this one." (grow.none). Each add is one Undo step.
- On-device only. Apple's FoundationModels (`SystemLanguageModel.default`, only `#if canImport(FoundationModels)` + `#available(iOS 26, macOS 26)` + availability == .available), prompt asks for five short ideas in the idea's language; else NaturalLanguage `NLEmbedding.wordEmbedding` for the language found by `NLLanguageRecognizer` (English as second try; longest word if a phrase). The SDK installed has FoundationModels; deployment targets are iOS 17 / macOS 14 so it is guarded. Not seen working: no device/simulator run (the model needs Apple Intelligence; the word list fallback is the likely path on a simulator).
- Rule in Core: `GrowIdeas.clean` — trimmed, bullets/numbers/quotes removed, no doubles (capitals and accents ignored), not the idea's own words, not already a child, empty or over 40 characters out, max 3.

## Signs:
- Diamond knob in the middle of a chosen arrow (hollow = straight, filled = bent): drag to bend, press twice to straighten.
- Round numbered badge in a branch's colour on a main branch: its number (Number the Branches).
- Not seen: no screen run (no simulators). Menus, plate and drawing built and compiled only.
