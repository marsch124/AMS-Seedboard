# Built 0.19 — lane pencil (picks 38-42), branch wt19-pencil

Core tests 563 green (554 + 9: Pencil19Tests 6, Pencil19RecentTests 1, Pictures19Tests 2). iOS + Mac builds clean (no new warnings). UITests/Pencil19UITests.swift compiles (build-for-testing), not run.

## 38 Shapes by hand
Before: "Tidy shapes" (switch in the Draw plate, OFF by default via Finger.tidyShapesAtFirst) turned a held loop into a real Box/Oval/Diamond THING and a line between two things into an arrow link. Not ink. Now: with no switch, keeping the tip still ~0.4 s (InkShape.rest, existing rest detector) at the end of a stroke makes the stroke itself clean: still ink, same colour and thickness (pressure dropped, like the ruler). Recognised: rough box (rectangle), circle/oval (ellipse), triangle, diamond, straight line, arrow (shaft + head drawn in one stroke -> shaft + two barbs). Otherwise stays as drawn. Rules in Core/InkClean.swift (InkClean.clean). Numbers: line >= 36 pt and within 7 % of its length from the chord; loop >= 44x28, once round, fit 3.5 % of diagonal (existing InkShape.shape), triangle fit 4.5 %; arrow barbs 22 % of shaft (12-40 pt) at 28 deg. Not on highlighter or lasso; works with ruler-less pen, finger+Draw tool, Pencil, mouse. If "Tidy shapes" is ON and would make a thing of the line, that wins (old behaviour). One Undo = the stroke is gone (one step, as any stroke).
Tip line in the Draw plate (under the colour dots): "Hold at the end of a shape to make it neat." id draw.holdTip. Shown until the first snap or 3 plate openings (UserDefaults ink.holdTip, per device; always shown with -sampleData).
Code: App/Sources/InkDesk.swift (inkEnded), InkViews.swift, Pencil19.swift.
Not seen: a real Pencil/finger hold (timing and the numbers are guesses to tune).

## 39 Recent pen colours
Plate colour row: the last 3 colours used stand first, then the rest in the old order, no doubles (plain ink counts as a colour). Per device (UserDefaults ink.recentColours). Rule Core/InkRecent.swift. Before: fixed order ink, pink, orange ...

## 40 Round picture
Picture menu line (and bar overflow) "Round" -> when round the line says "Square". Id picture.round (menu.round / sel.round not used; `exact`). SF Symbols: Marks19.round "circle", Marks19.square "square". Round also crops a non-square box to a square round its middle (crop part narrowed on the longer side; scale unchanged; Crop > Whole picture gives it back) so a face is a true circle. Square sets the shape back but keeps the box/crop. Stored in Item.cropShape "circle". Drawn round on the board, in export and in thumbnails (same painter), marks drawn on the picture are clipped round. One Undo each. Refused on read-only boards. Core/Pictures19.swift (setPictureRound). Not done: the crop page has no Rectangle/Circle choice (menu line only); taps in the corner outside the circle still hit the picture.

## 41 Camera tile
New tile "Camera" (accessibility label "Camera", id tool.camera) right after the Picture tile, before Draw; mark = SF Symbol Marks19.camera "camera" (tile has no word, only the tooltip/label — a word does not fit a 30-40 pt tile; camera is a mark everyone knows). Opens the same CameraPage as plate "Take a photo"; photo lands via session.lay. Hidden on Mac and on devices without a camera (simulator too). Switch: CameraTile19.shown in Pencil19.swift.
Fit at 375 pt: 10 tiles do NOT fit at 32 pt (357 > 355), so I added a 30 pt step to the ToolPill ladder in BoardView.swift (40 -> 36 -> 32 -> 30 -> scroll). At 375 wide it now uses 30 pt tiles (337 pt), mark 18 pt (ToolSize.mark gains a <32 step). At 390+ it uses 32. Alternative if Martin dislikes the smaller tiles: CameraTile19.shown = false (camera stays behind holding Picture). Not seen on a screen.

## 42 Print Frame
Picture menu line "Print Frame" (toggle, id picture.printFrame, shows as on when set), SF Symbol Marks19.printFrame "photo.artframe". White border = 4 % of the shorter side, min 6 pt (Item.printBorder), picture drawn inside it; soft shadow (day 0.28 black, radius 5, 2 down; night 0.16, radius 4 — border stays white). Also in export/thumbnails. Stored Item.printFrame true. Undoable, read-only refused.

## Shared-file edits the lead should know about
BoardView.swift: new Glyph case `.system(String)` (+ GlyphView draws Image(systemName:)) — other lanes may add the same; ToolPill gets CameraTool; ladder step 30. BarActions.swift: pictureLooks(item) added in both picture menus. PictureWays.swift: CameraPage no longer private. InkDraw.swift: marks clip to the round/framed shape.
No new stored fields. project.yml untouched.

Signs: camera symbol = take a photo (tool row, pictures colour); "circle" = Round picture line; "square" = back to a rectangle picture; "photo.artframe" = Print Frame (highlighted when on). No new colours.
