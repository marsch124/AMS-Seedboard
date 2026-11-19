# Lane "pictures" — ideas 16 and 28 (Seedboard 0.14)

## 16. Lift out (the subject of a photo)
- What it does: a chosen picture gets a button "Lift out". The device (Vision's foreground mask, iOS 17 / macOS 14) cuts the person or thing out of its background; the result is a NEW picture with a clear background, laid just to the right of the old one (28 points gap, same middle height). The old picture stays. One step for Undo. The new picture is chosen.
- Words: button "Lift out"; while working a line "Lifting the subject out…" (2 s); nothing found: "No subject found in this picture" (problem tone); file not on the device yet: "That picture is not here yet."; board closed meanwhile: "The subject was not lifted out: the board was closed."
- Where: the chosen picture's bar (after Crop; dropped early on a narrow bar) and its right-click / More menu. Greyed while the picture's file is not here yet. Not on Timeline / Who-does-what boards (a picture cannot be there anyway).
- Identifier: `picture.liftout`.
- Files: the cut-out is saved as `<UUID>.png` (new `PictureStore.takePNG`, long side at most 2048, transparency kept), on the device and in iCloud like any picture. Tidy pass, "Pictures nobody uses", iCloud upload watch and export-back (`PictureFiles.adopt`, BringBack) now accept `.png` as well as `.jpg` (`PictureKeeping.isPictureFileName`). One old test said ".png is refused"; changed to ".gif is refused".
- Does NOT: no choosing of which subject (all found subjects together), no edge softening, no undo of the file itself (an unused file is tidied by the usual pass).
- Not seen: the real Vision result (no simulator / no run allowed); the layout of the new picture next to the old.

## 28. Drop, paste or choose a PDF
- What it does: a PDF that is dropped on a board (Finder, Files, Mail), pasted (a PDF file copied in the Finder, or PDF data on the clipboard) or chosen in the Mac's Picture… chooser becomes a picture: page 1, drawn on white, long side 2048 px (like other pictures, kept as JPEG). A PDF with more than one page first asks.
- Words: question "This PDF has 6 pages" (number = its pages) with buttons "Only page 1" / "All pages" / Cancel. "All pages" lays up to 20 pages in a row (20 points apart, left to right); more than 20 says "A PDF lays 20 pages at most. The first 20 of 47 are here." A PDF that cannot be opened: "That PDF could not be read." (several: "3 PDFs could not be read."). Cancel leaves that PDF out. A one-page PDF asks nothing.
- Where: the drop on the board, Paste (⌘V / Edit ▸ Paste), Mac Picture… chooser (Insert ▸ Picture…, tool, letter P) now also lists PDFs. The iPhone/iPad Photos picker shows photos only; on those a PDF comes by drop (iPad) or Paste. No new "Files" way was added to the "Add a picture" plate (it would need a new mark).
- Identifiers: `pdf.ask.first`, `pdf.ask.all`, `pdf.ask.cancel`. Launch word for pictures: `-askPDF` (shows the question with 6 pages).
- Mixed drops (pictures and PDFs together) work; `BoardSession.lay(pictures:)` hands anything with PDF bytes to `layMixed`, and `lay` got a `row:` parameter.
- Does NOT: choose a page range, keep the PDF itself, make text of it.
- Not seen: a real drop from Finder/Mail/Files, the dialog on screen, Mail's PDF drag on iPad.

## Shared files changed (in marked blocks)
`PictureStore.swift` (end: "0.14 — pictures made here", one `.png` filter line), `ClipBoard.swift` (PDF types in paste checks and drop), `BarActions.swift` ("0.14 (16)" block + two list lines), `PictureViews.swift` (dialog modifier, `lay` hook + `row:`, `-askPDF`, Mac chooser type). New: `App/Sources/PicturesFrom14.swift`, `Core/.../PicturesFrom14.swift`, tests `Pictures14Tests` (Core, 5 tests) and `UITests/Pictures14UITests.swift` (2 screen tests, built only). No new stored field, no format change.
