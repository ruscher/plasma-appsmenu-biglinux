# 02 — Games at 1x1

## What was there

The first Games gadget put a selector strip above the board and, because
the strip ate a quarter of a 1x1 card, took `1x1` out of the size list and
showed *"needs a bigger card"* when the space was short. The `puzzle → games`
migration grew every 1x1 board to 1x2. That is the state this stage
replaces: 1x1 is offered again, every game has a layout made for it, and
the migration keeps the card's size.

Nothing is scaled. `scale: 0.6` would have kept the same pixels of
information in fewer pixels of glass; instead each game decides what a
small card should *drop* and what it must keep.

## The container

`GamesGadget.qml` no longer has a `minRows` gate. It reads
`host.compact` (1x1) and:

- hides the selector strip and moves the switcher into the title bar as a
  `view-more-symbolic` action opening a `QQC2.Menu` with checkable items;
- merges the current game's `titleActions` into `host.titleActions`, so New
  game / Undo / Pencil marks live in the title bar and cost the board no
  height. Larger cards keep the strip.

Games are loaded with `Loader.setSource(source, { host })`: a game that
declares `required property var host` cannot have it set after creation.

## What each game keeps and drops at 1x1

| game | keeps | drops / moves | measured on the VM (content 210×166) |
|---|---|---|---|
| 2048 | the 4×4 board, swipe and arrow keys | header score row → subtitle `"%1 · best %2"`; on-screen d-pad hidden | board fills the card; `dpadVisible=false`, 3 title actions |
| Minesweeper | 8×8 board with tap / long-press flag | header → subtitle "%1 mines left"; New game → title action | cells 20 px |
| Sudoku | the full 9×9 grid | number row → a 3×3 + ⌫ popover beside the selected cell (closes after a digit unless pencil mode is on); Pencil marks + New → title actions | cells 18.4 px, popover visible on selection |
| Flow Connect | 5×5 board, drag or tap to extend | header → subtitle "%1 of %2 joined"; Clear + New → title actions | board fills the card |
| Block Puzzle | 8×8 board **and all three pieces** | New → title action | board 147 px (18.4 px cells), tray 59 px |

Solved / game-over states are overlays on the board rather than extra rows.

## Block Puzzle in particular

The tray sits **beside** the board when the content is wider than tall
(`width >= height * 0.95`: 1x1, 2x1, 2x2) and **under** it on a 1x2 card.
The board is the largest square the remaining space allows; the tray takes
28 % of the width (24 % of the height when under), or whatever the square
board leaves over when that is more, capped at 5 grid units. Pieces in the
tray are drawn at up to three quarters of a board cell, so at 1x1 a piece
cell is ~14 px next to 18 px board cells — large enough to tell shapes
apart and to grab. Whatever the pair does not use is split evenly around
it, so a 2x1 card does not leave everything hugging the left edge.

Placement got a preview: while a piece is selected, hovering a board cell
shows the shape in the accent colour where it fits and tinted negative
where it does not (`coveredBy(shapeIndex, anchor, target)`), which matters
more on a small board where a miss is easy.

Two defects surfaced only when it ran on the VM:

- `Grid { id: tray }` shadowed the game's `tray` property and produced
  *"left-hand side of assignment operator is not an lvalue"* at
  `BlockPuzzle.qml:88`; the grid is `trayGrid` now.
- Setting both `columns` and `rows` on the tray `Grid` made them change one
  after the other when `sideTray` flipped, and the Grid logged *"contains
  more visible items (3) than rows*columns (1)"*. Only `columns` is set.

## Every size

Rendered offscreen (`qml6`, `QT_QPA_PLATFORM=offscreen`, software backend)
with a mock host at the four card sizes and inspected as PNGs — the kit's
`h/render.sh`. All five games are usable at 1x1; at 2x2 Sudoku's cells are
~35 px, Block Puzzle's 43 px with a 90 px tray, 2048's tiles 70 px.

Pictures: `img/harness-blocks-1x1.png`, `img/harness-blocks-2x2.png`,
`img/harness-sudoku-1x1.png`; and, from the real session on the VM,
Block Puzzle on a 1x1 card in `img/info-page.png` (top row, light theme).

On the VM the deployed gadget was cycled through the five games at 1x1 by a
temporary probe: all loaded (`compact=true`, strip hidden, host actions =
switcher + the game's own), with **zero** QML messages from that
plasmashell pid.

## Migration

`InfoPage.migrate()` still turns a `puzzle` item into `games` with
`cfg.game = "2048"` and the `best` score untouched, but keeps `it.size`
(defaulting to 1x1). A board that the earlier build already grew to 1x2
stays 1x2, which is harmless and avoids moving cards the user may have
arranged since.

## Registry

`games`: `sizes: ["1x1", "1x2", "2x1", "2x2"]`, `defaultSize: "1x1"`.
