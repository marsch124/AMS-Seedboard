# Expert panel before 0.2 (18 Nov 2026)

Five experts (product designer, mind-map user, flowchart user, Apple platform expert, data-safety reviewer) looked at 0.1 from the pictures in `Docs/pictures/0.2-before` and the code. 50 findings, merged here. Line numbers are from commit c11b60d.

## Fixed in any case (bugs and data safety, no pick needed)
- S1 Typing on one device wipes what another just brought: skipped news is marked seen and never offered again (AppModel:79, BoardStore:106, 435-438, 479-490). Offer again when typing ends; keep the replaced version when it is not the one the board grew from.
- S2 A removal beats a newer edit: the `.gone` mark is empty, no time (BoardStore:385-388, 433; AppModel:91-99). Mark carries the removal time; later edit wins.
- S3 iCloud's set-aside versions are deleted unread; `<id> 2.seedboard` skipped for ever (BoardStore:316-330, 369, 380).
- S4 Older app loses what a newer wrote: unknown kind opens as a box and is saved back (Board:88-89, 179, 231). Unknown → read-only; carry unknown fields; guard test.
- S5 Saving waits behind iCloud and fails silently (BoardStore:431-455). Device copy at once; background time; "not in iCloud yet" dot; warning.
- S6 Send: looks for PARAGON's folder only at launch, may pick an unused folder (ParagonGate:65-80; AppModel:249); picture left behind when the note fails (ParagonGate:39, 152-166); tasks can double; no test ties the Inbox line to PARAGON's reader.
- S7 Link back from PARAGON fails on a cold start (AppModel:237-245).
- B1 iPad keyboard shortcuts never switched on: Board menu is Mac-only (SeedboardApp:31-34, 40); board loses the keys after a button (CanvasView:119-122).
- B2 View jumps back to "whole board" after a finger slide (CanvasView:371; BoardSession:28, 519, 526, 553).
- B3 Send sheet cut off on iPhone, half empty on iPad (SendSheet:110-111).
- B4 Branches jump across the middle while adding (MindMap:88-94, 261-264).
- B5 A torn-off branch cannot be hung back; detaches by accident on touch (CanvasView:322-327, 385-389; MindMap:159, 179-186).
- B6 Shift+Return starts the next idea although the guide promises a new line (Guide:200; BoardSession:178-182); Shift+Tab same as Tab (CanvasView:174, 509).
- B7 Changing a shape's kind throws away its size (BoardSession:431-432); diamond grows only taller (CanvasDraw:137-138).
- B8 A growing map runs over what is beside it (MindMap:205-268).

## The pick list (numbers as shown to Martin)
New kinds of board
1. Timeline board — own kind of board; across = days, down = rows; bar has start + end day; drag middle = move, ends = stretch; dates pinned on top, names left; zoom days → weeks → months; red Today line; "comes after" arrows end → start, moving a bar pushes the later ones; diamond = milestone, frame = phase; to PARAGON as a project with start and due days. Format 2. L.
2. Pencil drawing — own strokes, NOT PencilKit: a "drawing" thing holding strokes (palette colour, thickness, thinned points with pressure); wet-ink layer that listens only to the Pencil; Pencil on empty board draws, on a thing moves it, finger slides; a "Draw" tool for finger/mouse with 3 thicknesses and a rubber for whole strokes. Format 2. Needs 24. L.
3. Sequence diagram ("Who does what") — name boxes in a row with a dashed line down; a message = an arrow that carries a place in the order, spaced and numbered by the app; dashed = answer; drag to reorder; to PARAGON as a numbered list. Format 2. L.
Safety
4. Bring back removed boards and earlier versions — Settings › Your boards: Removed (days left, Bring back under the same identity), Earlier versions per board (14 daily copies + set-aside versions, "Open as a copy"); a clash loser shows in the list as "Title (version from iPhone, date)"; tidy set-aside copies after 30 days. M.
5. Export all boards as one file to Files. S.
Look
6. Calmer colours — Send button PARAGON purple #6B4EA8; chosen row soft tint; starters come coloured; shapes faint shadow; night notes bright paper (#D9BC55, #D98AA8); ring on the chosen colour dot. S.
7. Selection bar beside the chosen thing; one row on iPhone (icons for Copy/Words/More/Remove); one tint per bar. Plus-handles as small dots, not on a side that has an arrow; frame follows the shape; knobs on four corners. M.
8. Home page — starter cards with a small drawing, board cards with picture + "changed 2 days ago", search over the list (BoardPicture:13 already draws). L.
9. Tool pill lifted (white, shadow), a word under each tile on Mac/iPad, drag a tool out to drop there, hold Box for Round/Oval. M.
10. Finger-size press areas on iPhone/iPad (44 pt; chips 36 visible; dots 30; catch area in screen points); iPhone opens at 75–100 % centred on the main idea. S–M.
Drawing
11. Snap + guide lines + dot grid (6 pt catch on middles, edges, equal gaps; pink guide; dots every 24). L.
12. Better arrows — rounded corners r8, spread 14 on one side, detour round shapes, drag an end to another side/shape, ends one way / both / none, dashed, word beside the line. M–L.
13. Tab = next shape in the flow's direction (⌘+arrow = that way); after a diamond a Box; first two arrows out of a diamond say Yes / No. S.
14. Line up, Even gaps, Same size for several chosen. S–M.
15. More shapes — person, document, slanted box, store; Box tool opens a plate. M.
16. Lanes in frames (2–5 named rows or columns; belongs when its middle is inside; frame lights up). M.
17. Copy, cut, paste between boards (also words + picture for other apps); dropped text becomes a note, a list a mind map; Option-drag copies; choosing box on iPad. M.
18. Right-click / press-and-hold menu on a thing and on empty board; pointer feedback. M.
Mind maps
19. Reorder sister ideas (⌘↑/⌘↓, Move up/down in the bar, drag between sisters). M.
20. Keyboard bar on iPhone/iPad: Idea under, Next idea, Out one level, Done; Shift+Tab = out one level. S.
21. "As a project": when any idea is ticked, only ticked ideas become tasks; "Send this branch". M.
22. Find in a board (⌘F), "Only this branch", fit down to 20 %; fold by pressing the dot, dot counts all hidden; arrow keys go on past a sister group; ⌘C copies a branch as a list. M.
23. A note on an idea (travels with it; under its line in PARAGON); curved thin "See also" links between ideas. M.
Apple
24. Proper touch layer (UIKit recognisers under the drawing, iPhone/iPad only): two fingers slide + zoom together, trackpad scroll and pinch, a shove taken back when the second finger lands, pointer Shift-click and choosing box. Base for 2. L.
25. Fuller Mac menu bar — File ▸ New Board ⌘N, Rename, Send ⌘↩; Insert menu with the tools; zoom under View; Space + drag slides. S.
26. Reopen the last board at its zoom and place (S); Shortcuts action "New board / note from text" for Raycast, Siri, Share; Spotlight (M).
27. Fast on big boards — skip what is off screen, no shadows while moving, re-measure only what changed; a 300-thing sample board. M.

## Not judged by anyone (needs real devices)
Pinch, slide and Pencil feel; palm rejection and latency; trackpad on iPad; keys reaching the board after a touch; 120 Hz frame rate; iCloud behaviour between three real devices (.icloud placeholders, " 2" files, set-aside versions); the first real Send into the real notes.
