# Built: pictures (21, 22, 23, 24, 39)

## What's new
- 21 Caption room: before, the room under a picture counted 6.6 points a letter; now it is measured with the caption's own lettering (12 points), the same lines the screen draws, so nothing overlaps.
- 22 Line up and Even gaps: before they used the picture's box only; now a picture counts together with its caption.
- 23 PARAGON wording: picture and sketch lines now come from one wording rule ("A picture (on the board)", "A picture: After the makeover (see the picture)", "A sketch (on the board)"); the words themselves are unchanged.
- 24 Legend card: the small colour card in the corner now shows the legend mark at its top left, like the menu line.
- 39 Picture words: a chosen picture that has found words gets "Copy words" and "Words to a note" (a new sticky note right of the picture and its caption holding the words). Not shown when there are none.

## How it works
- A picture whose words were found shows two more buttons in its bar and menu: Copy words (puts the words on the clipboard, says "Words copied") and Words to a note (a yellow sticky note appears 24 points right of the picture, chosen). Line up and Even gaps treat a picture and its caption as one thing.

## Spec
- Core: `Item.captionMeasure` (default 6.6 pt/letter, the app installs `PictureCaption.install()` at start with `Lettering.measure` size 12), `Item.captionWrapped(_:width:)` (one function for drawing and layout), `Item.captionLines`, `Item.foundWords`, `Board.noteWithPictureWords(_:)`; `Pictures11.swift`.
- Tidy.swift lineUp/evenGaps use `Item.reach`.
- Paragon.swift: `ParagonExport.whereLine(_:picture:)`.
- Bar ids: `<prefix>copywords`, `<prefix>wordsnote` (mark: makeTyped stand-in, no new mark exists).
- Legend card: `GlyphView(.new(.legend), 14)` in MarksViews.swift `LegendCardRow`.
- Test: Pictures11Tests (4 tests).

## Pictures
- `-sampleData -board <a picture board>` with a caption; legend card: any board with colour words (`-board` with legend). Picture words need a picture with `pictureWords` set (none in samples).

## Not done / doubts
- 23 was already consistent in words; I made it one function and pinned it, wording unchanged.
- "Copy words"/"Words to a note" use the Make typed mark (no dedicated mark). Not seen on screen.
- Edited shared files: BarActions.swift, PictureViews.swift, SeedboardApp.swift (one init), MarksViews.swift.
