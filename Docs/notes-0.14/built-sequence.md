# Lane "sequence" — built notes, 0.14

## Idea 23 — Blocks in "Who does what" (built)

**What it does.** A thin rounded frame round some messages with a word in a small tab at its top-left ("repeat", "if", "maybe" or your own), like the loop / alt / opt boxes of real sequence diagrams. The frame is drawn under the messages, in its colour, round every name the messages touch, with a little margin. The block is never placed by hand: it is placed from its first and its last message every time, so it follows them when they are moved. A block inside another gets less margin than the one round it (+8 points per block it holds), so the frames never touch. Room for the tab and the frame is made above the first and under the last message of a block.

**Make one.** Choose one or more messages (Shift-click / Choose more) -> Block (bar chip, beside To do) -> menu: `Repeat`, `If`, `Maybe`, `Other words…`. The block runs from the first to the last of the chosen messages in the order (messages between them are held too; notes and sections between are inside the frame). Only messages count; with none chosen the Block chip is not shown. The new block is chosen. "Other words…" opens the tab for typing at once (Escape takes the block away again). Starting colours: repeat teal, if orange, maybe blue, other words grey.

**Choose a block.** Press its tab (two quick presses = type its word). Bar for a block: `Words`, `Colour` (the usual palette; "No colour" = grey), `Remove block` (only the frame; the messages stay). Delete / Backspace also removes the frame only. Select all includes blocks.

**Removing messages.** A block that loses its first or last message shrinks to what is left (to the first and last remaining message of what it held); with nothing left it goes. Same when a name takes its messages along.

**PARAGON text** (Note for Resources: the numbered list; and the "copy as text" of the diagram): messages inside a block are written indented (3 spaces per block) under a line with the block's word and a colon, first letter capital: `Repeat:`. A block without a word says `Block:`. Nested blocks indent one more step. The project's task list (`- [ ]` lines, sequenceTaskLines) and the tasks sent to the Inbox are NOT changed (kept flat so PARAGON never reads them as sub-tasks).

**Count line** (home list / board count): "… · 2 blocks" (1 block).

## Exact words
Button (bar chip): `Block` -> menu lines `Repeat`, `If`, `Maybe`, `Other words…`. Block bar: `Words`, `Colour`, `Remove block`. Tab word typed on the board: stored in lower case from the menu ("repeat"), an empty word shows "block". PARAGON line: `Repeat:` / `If:` / `Maybe:` / `Block:`. Count: `1 block`, `N blocks`.

## Where
Sequence selection bar (bottom), for one message or several chosen. No Mac menu line, no key.

## Identifiers
`sel.block` (menu button), `sel.block.repeat`, `sel.block.if`, `sel.block.maybe`, `sel.block.other`, `sel.removeBlock`; for a chosen block also `sel.words`, `sel.colour`. `sequence.chosen` says the block's word ("repeat").

## Core (SeedboardCore)
New `SequenceBlocks14.swift` (frames from from/to, levels, `addBlock(round:word:)`, `keepBlocks`, PARAGON head/indent). `Sequence.swift`: `ItemKind.isSequence` now includes `.block` (so a block is not copied by the ordinary clip), new metrics `blockHead/blockFoot/blockPad/blockNest`, `SequenceLayout.blocks`, room made in the layout, `removeFromSequence` keeps blocks, count line, `sequenceText` and `ParagonExport.sequenceList` indent. No new stored field. Tests: `Sequence14Tests` (4 tests; Core total 513 green). Screen test: `UITests/Sequence14UITests` (built, not run).

## Does NOT do
No fill colour inside the frame; no "else" divider inside an `if` block (use two blocks); a block cannot be dragged or resized by hand (by design); a block is not copied by Duplicate (the copied messages are not inside it); blocks are not in the project task lines or sent tasks; blocks that only partly overlap are both drawn as they are.

## Not seen
I could not look at the drawing on a screen (no simulator allowed): the tab position, the margins and the overlap of two tabs at the same first message (outer one sits 20 points higher) should be looked at in the picture round. The menu items' identifiers inside a macOS menu are unproven in the screen test.

## Launch words
None added.
