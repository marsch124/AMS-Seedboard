# Built in the `share` lane (0.5, pick 22) — 18 Nov 2026

Branch `wt-share`. Findings: thought-to-action 8, thinking-flow 7, apple-platform 4.

## What is built, as it shows on screen

### "Share…" takes the place of "Share a picture…"
- **More** (the board's top bar): the line **Share…** stands where "Share a picture…" stood (after "Copy the board as text"; not shown on an empty board, as before). On iPhone and iPad the line **Print…** follows it.
- **File menu** (Mac, and an iPad with a keyboard): **Share…** stands where "Share a Picture…" stood; **Print…** with **⌘P** is new, in the File menu's own print place. Both are greyed when no board is open or the board is empty.
- **Menu of a thing or of several** (right-click on the Mac, press and hold on iPhone and iPad): the new line **Share this…**, after a thin line, just before "Remove". It opens the plate with "What is chosen" already picked. (A timeline and a "Who does what" board have no such menu, so the line is not there.)

### The Share plate
A small plate (the Mac: 400 points wide, a sheet on the board's window; iPhone: a sheet 440 points tall that can be pulled to full height; iPad: a card as tall as its content). Colour: the boards' green.
- Heading: the share mark and **Share**.
- **What** — up to three tiles in one row (a tile is as wide whether two or three are offered):
  - **Whole board** — always.
  - **What is chosen** — only when something is chosen. A chosen idea brings everything under it; a chosen frame brings what lies in it.
  - **Each frame a page** — only when the board has at least one frame with a name. Frames without a name are no pages.
- **As** — three tiles: **Picture**, **PDF**, **Words**.
- The chosen tile has a soft green fill, a green outline and bolder words; the others a hairline outline. Each tile is its mark over its word.
- One grey line under the tiles says what he gets:
  - Whole board: "One picture of the whole board." · "The whole board on one page, sharp at any size." · "The board's words as a small text file."
  - What is chosen: "One picture of the chosen thing." / "One picture of the 3 chosen things." · "The chosen thing on one page, sharp at any size." / "The 3 chosen things on one page, sharp at any size." · "The words of the chosen thing as a small text file." / "The words of the 3 chosen things as a small text file."
  - Each frame a page: "One picture of the named frame." / "4 pictures, one of each named frame." · "One page with the named frame, its name on top." / "4 pages, one for each named frame, its name on top." · "The words frame by frame, each under its frame's name, as a small text file."
- With "Each frame a page", a smaller line says what stays out: "1 thing lies outside the named frames and stays out." / "3 things lie outside the named frames and stay out." (A whole mind map counts as one thing.)
- Buttons at the bottom right: **Cancel** (Escape on the Mac) and the full-colour green **Share** (Return on the Mac). While it is made the button says **Making…**.
- Share makes the file and opens the system's own share choice at the Share button (AirDrop, Mail, Messages, Save to Files …). When something was shared the plate closes; when the share choice is left without sharing, the plate stays, so another form can be tried. Cancel shares nothing.
- If nothing could be made, a brick-red line on the plate says: "The picture could not be made." · "The PDF could not be made." · "There are no words to share here." · "The share choice could not be opened."
- From More and File the plate opens at "Whole board"; from "Share this…" at "What is chosen". The form (Picture, PDF or Words) he shared in last is remembered on this device and picked the next time (the first time: Picture).
- On a timeline and a "Who does what" board only "Whole board" is offered (they place their things themselves).
- Asked for on an empty board (only possible through the launch word): the line at the bottom says "There is nothing to share yet."

### What is shared
- **Picture**: a PNG as before — white ground, day look, 40 points of air, twice the size (plain size when a side is over 3000 points). Name: "<board>.png"; what is chosen: "<board> - part.png"; each frame a page: one picture per named frame, "<board> - <frame>.png" (two frames of one name: the second ends " 2").
- **PDF**: one file "<board>.pdf" (what is chosen: "<board> - part.pdf").
  - Drawn by the same painter as the board, as lines and real letters. White ground, day look.
  - Paper: A4 (Letter in the United States, Canada and Mexico), by the device's region. A page lies on its side by itself when what is on it is wider than tall; a timeline always lies on its side. With "Each frame a page" every page chooses for itself.
  - A white edge of 28 points. At the top a small grey line: the board's name at the left (bold, at most 70 letters), the date at the right ("18 Nov 2026"; with several pages "18 Nov 2026 · 2 of 4").
  - "Each frame a page": one page per named frame in reading order (row by row from the top, each row from the left; two frames are one row when the second starts above the middle of the first). The frame's name stands as the page's heading under the small line (15 points, bold); the frame itself with what lies in it is drawn below.
  - The board is never drawn larger than life size; a bigger one is made smaller until it fits. It sits at the top of the page, in the middle sideways.
  - On paper the soft shadows under shapes, sticky notes and name boxes are left out (in a PDF a shadow would become a small picture made of dots).
- **Words**: a text file "<board>.txt" ("<board> - part.txt") with the list that "Copy the board as text" makes. What is chosen: only those things (one chosen thing gives just its words). Each frame a page: frame by frame — the frame's name, a line of dashes under it, then the list of what lies in the frame; two empty lines between frames.
- Characters a file name cannot carry ("/", ":", "\") become "-"; a board without a name is "Board".
- Pictures on the board (photos) are read from their stored files for this one drawing and are not kept in memory afterwards, in the shared picture, in the PDF and in print.
- The files are made in the device's own throw-away folder ("Share"); what was shared more than an hour ago is thrown away at the next Share.

### Print…
- Mac: **File ▸ Print… ⌘P** opens the system's print page as a sheet on the board's window. iPhone and iPad: **Print…** in More opens the system's print page (AirPrint); on the iPad it hangs at the top right, under More.
- It prints the PDF of the whole board: one page, fitted, on its side by itself when the board is wider than tall (a timeline always). The print job carries the board's name.
- Lines at the bottom when it cannot: "There is nothing to print yet." · "The page could not be made." · "Printing is not possible here."

## Checked
- The PDF was made from three sample boards with the Mac debug build and looked at: "Lanes and shapes" (each frame a page), "Build timeline", "Balcony makeover" (two photos), and one chosen shape.
- Zoomed to 800 %: lines and letters stay sharp (they are drawn lines and real letters). The words can be found: every word of the three boards was read back out of the PDF as text.
- Dots: the Lanes PDF and the timeline PDF hold no picture at all; the Balcony PDF holds exactly its two photos (photos are pictures and stay pictures). Nothing else came out as dots in these samples.
- Both photos of the Balcony board were read from their stored files (in the PDF and in the PNG).
- The Share plate was seen on the Mac by day (Whole board + Each frame a page; Picture, PDF, Words; Cancel, Share).

## NOT seen running (say so in the release notes to the lead)
- Pressing **Share**: the system's share choice, on any device, and the plate closing afterwards.
- **Print…**: the system's print page, on any device. (Printing was not tried; the Mac's print permission is in `project.yml` since the groundwork.)
- Everything on iPhone and iPad (built for the simulator only; no simulator was used).
- The plate by night, and the plate with all three "What" tiles (something chosen).
- "Share this…" in the right-click and press-and-hold menu, and the two File menu lines, were not clicked.
- A "Who does what" board and a mind-map board as PDF were not looked at (same painter; the timeline and the shapes board were).
- The screen test was written and compiled, not run.
  (The last picture round did not come about: the Mac was under very heavy load from the other builders and the debug copy got no window from the system for over 40 seconds. The one day picture is from before that.)

## Launch words
- `-share` — opens the Share plate a moment (1.2 s) after the board shows. With it: `-shareWhat chosen|frames` and `-shareAs picture|pdf|words` choose the tiles; `-pick <word>` chooses a thing first.
  Example: `-board Lanes -pick Stock -share -shareWhat chosen -shareAs pdf -sampleData`
- `-print` — opens Print… a moment after the board shows.
- Debug builds only: `-shareTo <folder>` — makes the files of `-shareWhat` / `-shareAs` (PDF when not said) in that folder without the share choice, and writes `made.txt` beside them (the file names, and how many pictures were read from their stored files). For looking at a PDF.
- Tip for pictures on a busy Mac: add `-ApplePersistenceIgnoreState YES` (as the screen tests do).

## Identifiers
- More: `board.share`, `board.print` (iPhone and iPad).
- Menu of a thing: `menu.share`.
- The plate: `share.plate`; `share.what.whole`, `share.what.chosen`, `share.what.frames`; `share.as.picture`, `share.as.pdf`, `share.as.words`; `share.line`, `share.leftOut`, `share.problem`; `share.cancel`, `share.share`.

## Marks
- Used: `NewMark.share` (the plate's heading, "Share this…"), `NewMark.pdf`, `NewMark.words`, `NewMark.picture` (the As tiles); `AppMark.seedBoard`, `.seedSelectAll`, `.seedFrame` (the What tiles).
- `NewMark.print` is not used by this lane (menu lines carry no marks). No new mark is wanted.

## Stored data
- No new stored field; the board format is untouched.
- This device only (`UserDefaults`): `share.form` — the form he shared in last ("picture", "pdf" or "words"). Not read with `-sampleData`.

## Rules and tests
- Rules: `Core/Sources/SeedboardCore/SharePages.swift` (what can be shared, the named frames in reading order, a part as a small board, the pages, what stays out, the words, paper by region, fitting a page, file names, the plate's lines, the date line).
- 8 data tests in `Core/Tests/SeedboardCoreTests/Share05Tests.swift`; all 302 rule tests pass.
- 1 screen test: `UITests/ShareUITests.swift` (the plate offers What and As, the line follows the tiles, Cancel closes it) — compiled (Mac build for testing succeeded), not run.
- Both builds green: the Mac (with the screen tests) and the iPhone/iPad simulator build.

## Files
- New: `App/Sources/SharePlate.swift` (the plate, the lines in More and File, "Share this…", making the files, the share choice, launch words), `App/Sources/BoardPaper.swift` (the PDF, Print…, pictures from their stored files), the Core file, the two test files, this note.
- Small hunks: `BoardView.swift` (More: 3 lines; one modifier line `ShareHost`), `Menus.swift` (File: "Share…" in place of "Share a Picture…"; a new print group of 2 lines), `BoardMenu.swift` (1 line), `BoardPicture.swift` (`png(of:fromFiles:)`), `PictureViews.swift` (1 line in `drawPictureBody`), `CanvasDraw.swift` (2 lines: no shadow on paper), `SequenceDraw.swift` (1 line: the same).

## NOT built (not in the lane's brief; from the three findings)
- "Outline on a second page" in the PDF; printing across several sheets ("Readable: 3 pages side by side", 2 / 4 / 6 / 9 sheets); a plate before printing; separate lines "Export as PDF…" / "Save as PDF…" (Share ▸ PDF does it; the Mac's print page has its own "Save as PDF"); dragging a PDF out; "What is chosen" and "Each frame a page" for Print… (it always prints the whole board).
- A sharper picture for very big boards (the PNG rule is as in 0.4; the PDF is the sharp form).

## Small choices I made (the lead may change them)
- Words are shared as a small text file (finding TA 8), not as loose text — "Copy the board as text" already gives loose text.
- The plate remembers the last form on this device.
- The plate stays open when the share choice is left without sharing.
- Print… is in More only on iPhone and iPad, as the brief says; the Mac has it in the File menu.

## Seen and left alone (for the lead)
- `SharePicture` (end of `Menus.swift`) and `BoardPNG` (`BoardPicture.swift`) are no longer used by anything in this lane. Left in place so the join stays easy; they can go after the join if no other lane uses them.
- The shared picture and the PDF draw the plain to-do ring: `BoardPicture` does not hand `todoStates` (what was read back from PARAGON) to the painter. If the three marks of pick 16 should show on paper too, set `painter.todoStates` in `BoardPicture.png` and in `PaperPage` (BoardPaper.swift) at the join. A part ("What is chosen", a frame's page) has new identities, so the states would have to be matched by place there.
- The `send` lane makes named frames headings in "Copy the board as text" (TF 1). "Words" for "Each frame a page" writes its own heading (the name and a line of dashes); after the join the two may want the same look.
- Pictures from their stored files: this copy reads them with `PictureStore.shared.fileBytes(name)` (in `PaperPictures.image`, BoardPaper.swift), on the main thread while one page is drawn. Another lane added `PictureStore.shared.fullImage(name)` (the whole picture file, read off the main thread); it is not in this copy. At the join `PaperPictures.image` may switch to it — one place.
- `TimelineDraw.swift` has one more soft shadow (the dates plate over a bar that is being dragged); it never shows in a picture or a PDF, so it was left.
