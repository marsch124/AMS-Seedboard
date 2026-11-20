# built19 — lane canvasb (picks 10, 12, 14, 15)
Branch wt19-canvasb. Core: `Canvas19.swift` (rules), test `Canvas19Tests.swift` (4 tests). App: `Bar19.swift` (SF Symbol enum `Marks19Canvas`, `RecentColours`, session methods, `withCanvas19` bar/menu lines). Screen test `UITests/Canvas19UITests.swift` (compiles-by-build only, not run).
Also touched (small): BoardView.swift (new `Glyph.symbol(String)` case = an Apple SF Symbol by name, + Mac "Board" menu lines), CanvasDraw.swift (small note text 13), BarActions.swift (3 one-line wraps + colour order), Thinking.swift/BoardSession.swift (record colour used). LEAD: other lanes needing SF Symbols may need the same `Glyph.symbol` case — merge it once.

## 10 Colour row, last 3 colours first
Before: fixed order (notes: yellow pink blue green orange purple; others: pink orange teal blue purple green yellow red grey). Now: the last 3 colours used (newest first, no doubles, only colours that row offers) come first, then the rest in the usual order; "No colour" (shapes/arrows) stays first. Kept per device in UserDefaults key `recentColours19` (last 6 remembered). Recorded when a colour is picked in the single row (`setColour`) or the several-chosen row (`colourChosen`). Same dot ids as before (`colour.<name>`, `board.colours`). Also the Colour list in menus (same function). Not for branch recolour "New Colours" or home/list colour menus.

## 12 Stack
Bar and context menu word "Stack" (id `sel.stack` / `menu.stack`), SF Symbol `rectangle.stack`, shown with 2+ chosen stackable things; wide word (icon only on iPhone), drop 6. Mac Board menu "Stack" (no key). Stackable: sticky notes, flow shapes (box, round box, diamond, oval, person, document, slanted, store), free text; not frames, ideas, pictures, sketches, tables, doors, pinned or hidden things; not on timeline / Who-does-what boards. Rule: reading order (`Thinking.readingOrder`); the first (top-left) stays; others go under it, left edge = its left edge, 10 pt gaps. One undo step. Chosen things stay chosen.

## 14 Small note
"Small Note" / "Normal Note" (ids `sel.smallNote` / `sel.normalNote`, menu.*), SF Symbol `square.arrowtriangle.4.outward` (both; swap in `Marks19Canvas`). In the bar and menu of a chosen sticky note, or when ONLY notes are chosen (shows "Normal Note" if all already small). Small = textSize "small", 96 x 64, text 13 pt instead of 15 (Lettering.style). Normal = 150 x 110 (the note default), textSize nil. Top-left corner kept. Note: a normal note that was resized by hand goes back to 150 x 110. A small note's height still grows if its words need more room (existing rule). Pinned notes untouched.

## 15 Put in a frame
"Put in a frame" (id `sel.putInFrame` / `menu.putInFrame`), SF Symbol `square.dashed`, wide word, drop 6. Mac Board menu "Put in a Frame", shortcut ⇧⌘F (⌥⌘F is taken by "Focus on the Frame"). Frame = union of chosen things (pictures with caption) grown 24 pt each side, empty name, inserted underneath everything; then the frame is the only chosen thing and its name field opens (same as the Frame tool: Escape = cancel makes the frame vanish again via the new-thing rule). Refused when: an idea of a map is chosen without its centre (map would be cut) — choosing the centre brings its whole map (visible ideas); timeline/who-does-what things; read-only board. One undo step. Left out: the 30 pt name band of the frame lies over the top 6 pt of the 24 pt air (the brief said 24 exactly).

## Could not see
No simulator run; bar layout (new buttons are wideWord/drop 6, so they go behind the "…" when narrow), the symbol looks, and the frame-name field opening were not looked at. The UI test is written and compiles with the app build only.

Signs: no new colour. New marks (SF Symbols): rectangle.stack = Stack; square.dashed = Put in a frame; square.arrowtriangle.4.outward = Small/Normal Note (both). Colour row: first dots = the last colours used (no mark of its own — say so in the guide).
Build: Core 558 tests green; iOS + Mac app builds green, no new warnings.
