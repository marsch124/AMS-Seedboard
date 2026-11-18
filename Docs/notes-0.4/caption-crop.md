# Notes for 0.4 — builder "caption and crop" (words under a picture, showing only part of a picture)

Nothing here was run on a device, a simulator or the Mac's screen. Both apps compile, the rules are tested as data (7 new tests, total 291), one screen test is written and not run.

## What the user can now do

- **Caption.** A chosen picture has a button **Caption** in its bar and in its right-click / press-and-hold menu. Two quick presses on a picture do the same. The caption is typed in place, under the picture. Return ends the typing, Escape cancels, Shift + Return makes a new line. Other letter keys on a chosen picture still do not start typing.
- The caption stands 6 points under the picture, centred, as wide as the picture (longer words wrap onto more lines), in small grey letters (12 points on the board, grey like other quiet text). It is not part of the picture's box: the chosen frame and the corner knobs stay on the picture; the caption moves, scales (zoom) and is copied with it. Empty = no caption. The caption is the picture's own words (it is not a new stored thing).
- Everything that measures a board gives the caption its room: Show the whole board, the picture for PARAGON / Share / Export, the small pictures in the list, and a mind map that grows steps a note, shape or picture aside when it would cover the picture's caption.
- Pressing on the caption chooses the picture.
- **Search boards** finds a caption. **Copy the board as text** says "A picture: After the makeover" (and "A picture" without a caption, as before). The PARAGON note says "A picture: After the makeover (see the picture)" (or "(on the board)"). A picture still has no to-do tick.
- **Crop.** A chosen picture has a button **Crop** in its bar and menu. It opens the page **Crop the picture**: the whole picture fitted into the page, a frame over it with four round corner grips, everything outside the frame dimmed. Drag a grip to change the frame, drag inside the frame to move it. The frame never leaves the picture and is never smaller than 44 points on screen (and never less than 5 percent of the picture's width or height). Buttons: **Cancel** (Escape on the Mac), **Whole picture** (the frame becomes everything), **Save** (full colour). The page opens with the picture's present part in the frame.
- Save changes the picture's box so that the **scale stays** (a point of the picture covers as many board points as before) and the kept part stays exactly where it was on the board. **Whole picture** then Save brings everything back the same way. One Undo takes a crop back. The picture's file is never changed, so a crop can always be changed again or taken back.
- Resizing a cropped picture by a corner keeps the cropped shape. Duplicate, Copy and Paste carry the crop (and the caption).
- **Crop is greyed** on a picture whose file is "Picture not here yet".

## Limits

- The room kept for a caption is a careful guess of how many lines the words take (the screen wraps the real words). On a very narrow picture with long words the screen may take one line more than the room kept; then the last line can reach a little past the box that "Show the whole board" or the picture for PARAGON measures.
- Only mind-map growth makes room for captions. Other moves (lining up, even gaps, dragging) work on the picture's box as before.
- Board format is now 4: a board with a crop opens in an older Seedboard (format 3) to look at, not to change.

## For the lead

**Files touched.** New: `App/Sources/CropPage.swift`, `Core/Tests/SeedboardCoreTests/CaptionCropTests.swift`, `Docs/notes-0.4/caption-crop.md`. Core: `Board.swift` (field `Item.crop`, coding, `currentFormat = 4`), `Pictures.swift` (`cropPicture`, `Item.cleanCrop`, `shownPart`, `captionWords`, `captionFrame`, `reach`, `captionLines`), `BoardEdit.swift` (`bounds` uses `reach`; a press on the caption hits the picture), `Room.swift` (makes room for `reach`), `Outline.swift` and `Paragon.swift` (the picture line with its caption). App: `PictureViews.swift` (drawing: crop and caption, `PictureCaption`, `-cropPicture`), `BarActions.swift` (Caption and Crop in bar and menu), `BoardSession.swift` (`beginCaption`, `beginEdit(caption:)`, `cropping`), `CanvasView.swift` (double press, caption field), `ShapeDraw.swift` (`typingFrame` for a picture), `BoardView.swift` (the sheet), `NewMarks.swift` (`.caption`, `.crop`, stand-ins `.seedText` and `.seedFrame`: the lead swaps them), `SamplePictures.swift` (second picture captioned "After: herbs and a small table"). Tests: `SafetyTests.swift` (list for format 4), `PictureTests.swift` (format by `Board.currentFormat`), `UITests/PictureUITests.swift` (new test). Not touched: Guide, SPEC, README, project.yml, Sequence*, Timeline*, TouchLayer.

**Identifiers.** `sel.caption`, `sel.crop` (bar), `menu.caption`, `menu.crop` (menu), `crop.page`, `crop.cancel`, `crop.whole`, `crop.save`, `crop.frame`, `crop.grip.topLeft` / `topRight` / `bottomLeft` / `bottomRight`. The typing field of a caption is the usual `board.field`.

**Launch words.** `-sampleData -board balcony -cropPicture` opens the crop page for the first picture (and chooses it); `-pickPicture` chooses it only.

**Guide/SPEC lines for the writer.** Format 4; the Caption and Crop buttons; the page "Crop the picture"; the caption in the texts and in search.

**Not proven.** Nothing was seen on a screen: the look of the caption (size, grey, centring, wrapping against the Core guess), the caption field lining up with the drawn caption, the crop page on iPhone, iPad and Mac (grip pressing by finger, mouse and trackpad; the sheet's size on the Mac; Escape), the board's redraw after a crop, a crop on a real photo, the screen test (written, not run), Crop greyed while a file is missing (decided when the bar is built).
