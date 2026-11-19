# Built: memory lane (items 6, 7, 8, 9, 19)

## What's new
- 6 PDF photos: before, every photo stayed open at full size until the last page was done (20 phone photos could use up the memory). Now only the photos of the page being drawn are open; they let go after each page.
- 7 Print and PDF: before, making the pages held the whole screen still. Now "Making the pages…" shows, the photo files are read in the background, and the screen gets a turn between pages.
- 8 Export all boards: before, the pictures, the packed file and the final copy were all in memory together. Now each picture is written to a temporary folder one at a time, zipped, and the zip is saved straight from that file; the temporary folder is cleared when saved or given up.
- 9 Undo: before, 120 steps whatever their size. Now 120 steps or about 40 MB, whichever comes first (the newest step is always kept). The Undo list says "Older steps were let go to save memory." when that happened.
- 19 Photos on a board: before, any number of sharp full-size photos could be asked for at once. Now at most 12 are open; the rest show their small copy until they are among the 12 most recently in view.

## How it works
- Undo list: a line under the hint says older steps were let go when the size limit (or the 120 count) removed some.
- Print and Share as PDF: a short "Making the pages…" line (Print) / "Making…" (Share plate) shows while it works.
- Export all: nothing changes on screen except it needs less memory.

## Spec
- Core `Memory11.swift`: `UndoBudget` (steps 120, bytes 40*1024*1024, `weight(of:)` rough size: 2000 + 200/link + 700+text bytes per item + 100 + 8/point (+8/pressure) per stroke; `toLetGo(weights:)`; `words`). `PictureKeeping.sharpMost = 12`, `sharpToKeep(_:most:)` (most recently asked for).
- `BoardSession`: `undoWeights`, `@Published undoLetGo` (reset when another device's version replaces the board). `UndoListPage` shows id `undoList.letGo`.
- `PictureStore.sharpImage`: gate at 12 (sharp + loading) while all are on screen (<2 s); after a load, extras beyond `sharpToKeep` go.
- `BoardArchive.make(name:files:fetched:fetch:missing:in:)` new overload (writes fetched files one by one, autoreleasepool). `ExportFile` now has `url` + `place` instead of `data`; `ZipDocument(url:)` (FileWrapper from file, lazy); `ExportPlace.clear()`.
- `BoardPicture.pdf` is now `async` (@MainActor); `PaperPictures.readFiles` (off main, `kCGImageSourceShouldCacheImmediately`), `PaperPictures.use(_:)` per page. `ShareMaker.files` is now `async`. `BoardPrint.ask` shows "Making the pages…" (flash, 60 s, cleared when done).
- Test: `Memory11Tests` (2 tests).

## Pictures
Nothing to see for 6, 8, 19. Print: `-sampleData -print` (line "Making the pages…" flashes). Undo list line: not reachable with sample data.

## Not done / doubts
- One very big page is still drawn in one go on the main thread (ImageRenderer needs it); only the file reading and the gaps between pages are free. A one-page board still pauses briefly during the draw.
- The PNG form of sharing is unchanged (still reads files on demand).
- "Nearest the view" for 19 is approximated by "most recently asked for" (pictures in view are asked each draw).
- Undo weights are a count-based estimate, not measured bytes.
