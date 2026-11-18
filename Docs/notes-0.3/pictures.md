# Notes for 0.3 — builder "pictures" (put a photo or a screenshot on a board)

Nothing here was run on a device, a simulator or the Mac's screen (the builders' rule). Both apps compile, the rules are tested as data (8 new tests, total 266), one screen test is written and not run.

## What the user can now do

- **Put a picture on a board** and move it, resize it, copy it, duplicate it, cut it, remove it and undo — like any other thing. It travels to the other devices with the board.
- **Ways in**
  - The **Picture** tool (the ninth tile, "Picture (P)"). iPhone and iPad: Apple's photo picker opens (up to 12 pictures at once, no permission question). Mac: an open panel titled "Choose a picture" with the button "Choose" (several files at once).
  - **Paste** (⌘V, the Edit menu, the keyboard bar, the board's menu): a screenshot or a copied picture lands in the middle of the view; on the Mac, image files copied in the Finder do too. If the clipboard holds words (and no copied file), the words win, because a copied table or web page brings a picture of itself along.
  - **Drop**: an image file or an image dragged from another app onto the board lands where it is dropped (Mac and iPad); more than one lands 28 points further down and right each.
  - **Mac:** the letter **P** (while nothing is chosen), **Insert ▸ Picture…**, and **Picture…** in the right-click menu of empty board (it lands where you pressed).
- A new picture is laid **at most 320 × 320 points** big, keeping its shape (a tiny one is made at least 120 long), and is chosen at once.
- **Resize:** drag any corner; the picture keeps its shape and the opposite corner stays. Never smaller than 44 × 28 points.
- **Arrows** can start and end at a picture like at a shape.
- **The bar and the right-click / press-and-hold menu** of a chosen picture: Duplicate, Choose more (iPhone/iPad), Remove in the bar; Copy, Cut, Duplicate, Arrow from here, Remove in the menu. No Words, Colour or To do; a double press or a letter key does not start typing.
- **Line up, Even gaps** work on pictures; **Same size** leaves them alone (fixed shape).
- **Copy the board as text** and the **PARAGON note** say one plain line for a picture: "A picture" (note and project text: "A picture (see the picture)", or "(on the board)"). The board's picture for PARAGON, Share and Export, and the small pictures in the list, show the pictures.
- **The board's count line** says "1 picture" / "2 pictures".
- **Not allowed:** pictures are refused on a timeline and on a "Who does what" board (the words: "A picture cannot be put on this board.").
- **Words shown on screen:** "Picture not here yet" (on a soft plate with the picture mark, when the file is missing or iCloud is still bringing it; the board fills in by itself when it arrives); "That could not be read as a picture." / "3 could not be read as pictures."; "Picture…" (menus), "Picture (P)" (tool).

## Limits and how the files are kept

- Each picture is scaled so its long side is at most **2048 pixels**, saved as **JPEG 0.8** (transparency becomes white), under a fresh name `<UUID>.jpg`, in a folder `Pictures` beside `Boards` — on the device (Application Support/Pictures) and in iCloud (Documents/Pictures). A file is written once and never changed.
- Removing a picture from a board never deletes its file (Undo works). A file is deleted only when **no board names it** (boards, removed boards, safety copies, earlier versions) **and** it is **older than 30 days**; the check runs once at app start, 25 seconds after launch. In any doubt (a copy unreadable, a file still only in iCloud) nothing is deleted.
- A board with pictures opens in an older Seedboard (format 3 is new in 0.3) to look at, not to change.

## For the lead

**Files touched.** New: `Core/Sources/SeedboardCore/Pictures.swift` (rules: `addPicture`, `scalePicture`, `pictureSize`, `PictureKeeping`), `Core/Tests/.../PictureTests.swift`, `App/Sources/PictureStore.swift`, `App/Sources/SamplePictures.swift`, `UITests/PictureUITests.swift`. Rewritten: `App/Sources/PictureViews.swift` (tool, `PictureDesk`, `PictureHost`, `PictureInsertLine`, `BoardSession.lay(pictures:at:)`, `drawPicture`). Small edits: Core `BoardEdit.swift` (resize, count line), `Tidy.swift`, `ChosenBar.swift` (knobs), `Arrows.swift` (arrows go round pictures), `Outline.swift`, `Paragon.swift`; App `ClipBoard.swift` (paste, drop, `PictureHost` hung on `ClipKeys`), `BoardSession.swift` (3 one-line guards: no words, no tick, no colour), `BarActions.swift` (picture bar, menu lines, "Picture…" in empty-board menu), `CanvasView.swift` (one line: `case "p"`), `Menus.swift` (Insert: Divider + one line), `Sample.swift` (one line in the list). Not touched: BoardStore, AppModel, TouchLayer, Guide, SPEC, README, project.yml.

**Identifiers.** `tool.picture` (existing), `sel.copy`/`sel.remove` (bar of a picture), `menu.picture` (empty-board menu line), `menu.*` as before. No new page, so no new Cancel/Save.

**Launch words.** `-sampleData -board balcony` opens "Balcony makeover" (two landscapes drawn in code, two notes, one arrow "becomes"); `-pickPicture` chooses the first picture (handled in `PictureHost`, not in AppModel). Sample pictures live in the temporary folder `SeedboardSamplePictures`; sample mode never touches iCloud.

**Hooks for the join.** The picture mark is still the stand-in `.new(.picture)` -> `.seedFrame` (NewMarks.swift); the placeholder plate draws its own small hand-drawn mark as paths (`BoardPainter.pictureMark`). `PictureStore` finds the iCloud Pictures folder through `AppModel.shared.store.kept` (the folder beside Boards) at its first use. The redraw on arrival goes through `session.objectWillChange` (in `PictureHost`), so no change to `CanvasView`'s drawing. A touch-layer hook was not needed: the drop uses the same `.onDrop` as dropped words. Guide/SPEC lines for the writer: tools 8 -> 9 (Picture); the list of what a board holds; the count line; Paste/Drop now take pictures; format 3.

**Not proven on a real device / screen.** The photo picker and the open panel (never opened); paste of a screenshot and of Finder files; drop from Safari, Photos, Files and the Finder; the redraw when a picture arrives from iCloud, and the "Picture not here yet" plate; the 25-second tidy pass against a real iCloud folder; the screen test (written, not run — it chooses the picture by `-pickPicture`, it does not press its pixels); corner resize by finger; how the pictures look in the small list pictures at 240 x 150; memory with many 2048-pixel pictures (cache is capped at 160 MB).
