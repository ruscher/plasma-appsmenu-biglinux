# Test matrix

Everything below was run on the lab VM — Plasma 6.7.4, KDE Frameworks 6.29,
Qt 6.11.2 — against the deployed package, not against the source tree.

## How these were driven

Wayland blocks synthetic input and `spectacle` core-dumps on this machine, so
nothing here was clicked. Two techniques replace that, and both are honest
about what they do and do not prove:

1. **Through the plasmoid's own configuration.** Stop plasmashell, rewrite the
   gadget's `cfg` inside `gadgetLayout`, set `lastTab=3` so the menu opens on
   the Info page (which is what instantiates gadgets), start, open the menu by
   D-Bus, stop, read the config back.
2. **A temporary probe in the deployed copy** that XHR-PUTs a JSON snapshot of
   live state to `/tmp`. Probes call the same functions the buttons call, so
   the logic is genuinely exercised; what is *not* exercised is the pointer
   reaching the button.

Every probe was removed and the VM returned to its original state afterwards.
`qmllint` was run on every file touched — and is recorded here as insufficient:
it accepted a file with two `id` declarations in one object, which only the
real engine rejected.

## Weather

| case | result |
|---|---|
| automatic location | PASS — `auto\|c`, Brasília, 31 °C, `requestId 1` |
| manual São Paulo (no saved coordinates) | PASS — geocode then forecast, `scopeKey city:são paulo\|c`, 28 °C |
| manual Lisboa | PASS — `busy false`, `loading false`, subtitle `Lisboa, Distrito de Lisboa · PT` |
| manual Porto Alegre | PASS — coordinates persisted, 21 °C |
| invalid city | PASS — `City not found…`, spinner cleared, previous reading kept |
| Celsius → Fahrenheit | PASS — refetched, 82 °F, cached Celsius not reused |
| Fahrenheit → Celsius | PASS — refetched |
| back to automatic | PASS — `auto\|c` |
| offline (provider unreachable) | PASS — `busy false`, `loading false`, `offline true`, `Could not load the weather (offline).` |
| cache honoured | PASS — fresh matching cache ⇒ 0 requests |
| rapid configuration change | PASS — `requestId 1` per change despite `cfgChanged` firing twice |

## Calendar

| case | result |
|---|---|
| navigate back three months | PASS — 2026-09 → 2026-06 |
| Today returns | PASS — back to 2026-09, `backToCurrent true` |
| action published generically | PASS — 1 title action, text `Today`, icon `go-jump-today` |

## GPU Meter

| case | result |
|---|---|
| order CPU → GPU → Memory | PASS — default layout reordered |
| icon exists | PASS — `gpu` exists in no installed theme; now `cpu`, which does |
| all cards shown | PASS — `slice(0, 2)` removed, list scrolls |

## Quick Links

| case | result |
|---|---|
| all ten resolve | PASS — 11 ids resolved, 10 tiles |
| icons | PASS — every icon read from the entry, including `big-store` (was the broken `bigstore`) |
| missing application | PASS — KCalc absent ⇒ `org.gnome.Calculator` used instead, no gap |
| launch | PASS — `launch org.kde.kate.desktop` started `/usr/bin/kate -b` |
| not installed | PASS — exit 3 |
| injection (`../../../etc/passwd`, `a;id.desktop`, `$(id).desktop`, `../x.desktop`) | PASS — all rejected |

## News / RSS

| case | result |
|---|---|
| eight sources configured | PASS — `stripModelCount 8` (previously 3 would have existed) |
| overflow | PASS — `stripOverflowing true`, scrollbar appears |
| stale sources forgotten | PASS — three seeded caches swept |
| RSS 2.0, RDF, Atom | PASS — 10 items each from live captures |
| special characters, long titles, no image, truncated, empty, HTML | PASS — no throw in any case |

## Drive Info

| case | result |
|---|---|
| count matches the list | PASS — `2 volumes` / 2 rendered (was `3 volumes` / 2) |
| hotplug attach | PASS — Solid sources 2 → 3 the moment a disk was attached |
| mount | PASS — 3 volumes, `127,7 MiB free of 127,7 MiB` |
| unmount | PASS — back to 2 |
| detach | PASS — sources back to 2 |
| removable vs system | PASS — badged separately, system sorted first |

## Quote of the Day

| case | result |
|---|---|
| local only | PASS — 40 messages, `isLocalMessage true` |
| online reachable | PASS — fetched from ZenQuotes |
| online unreachable | PASS — `offline true`, **local message still on screen** |

## Countdown

| case | result |
|---|---|
| Add event | PASS — events 0 → 1 |
| close with an empty form | PASS — closes immediately |
| close with an unsaved event | PASS — **close refused**, question shown |
| Add from the question | PASS — event saved, then closes |
| Discard from the question | PASS — closes, events did **not** grow |
| after adding | PASS — closes without asking |

## Currency

| case | result |
|---|---|
| 1 currency | PASS — 1 rate, 1 request |
| 4 currencies | PASS — 4 rates, 1 request |
| all 29 | PASS — 29 rates, **1 request**, `scrolls true` (522 px of content in 159 px) |
| base never duplicated | PASS — `baseAmongShown false` |
| cache covers the selection | PASS — was serving 5 rates for 29 selections; now refetches |

## Live Scores

| case | result |
|---|---|
| score centred, long names | PASS — 107 px and 117 px off centre before, **0** after |
| balanced names | PASS — 1 px before, 0 after |
| settings grid | PASS — 3 / 2 / 1 columns at 34 / 22 / 12 grid units |
| leagues all reachable | PASS — switcher no longer sliced |
| provider capability | CHECKED — live scores for 5 sports; motorsport has none; free tier returns one fixture per league |
| refresh interval, notifications | NOT TESTED end to end — the setting and the change detection work; no goal was scored during the window |

## Gallery

| format | result |
|---|---|
| png, jpg, jpeg, tif, tiff, webp, avif, heic, heif, jxl | PASS — all reach `Image.Ready` at 160 × 120 |
| corrupt file | PASS — `Image.Error`, remembered, skipped, slideshow moved to index 1 |
| diagnostic | PASS — `GalleryGadget: cannot decode corrupt.png — skipping it` |

## Clipboard

| case | result |
|---|---|
| list renders | PASS — 15 entries, 15 rendered, `contentHeight 584` (was empty) |
| text | PASS — preview lengths 60 / 33 / 43 / 6 / 91, eliding at 90 |
| image | PASS — `type 4`, `imageSize 120 × 80`, thumbnail `Image.Ready` |
| masking | PASS — every preview exactly 12 characters |
| shared with SUPER+V | PASS — same `HistoryModel` proxy over the one history in this plasmashell |
| select / delete / clear | NOT TESTED — these need a pointer; the handlers call `moveToTop`, `remove` and `clearHistory` directly |
| URL entry | NOT REPRODUCED — Klipper classifies a typed `https://…` as text; `type 8` comes from file copies |

## Games

| case | result |
|---|---|
| 2048 | PASS — loads, 2 tiles at reset, moves accepted, previous best read |
| Minesweeper | PASS — first click never loses, 10 mines laid, flags toggle, 54/54 safe cells wins |
| Sudoku | PASS — 42 clues, 0 conflicts in a fresh puzzle, solve detected |
| Flow Connect | PASS — 5 pairs, path drawn dot to dot, pair reported connected |
| Block Puzzle | PASS — 3 pieces placed, score grows, a full row clears |
| migration from "puzzle" | PASS — `{"id":"puzzle","size":"1x1"}` became `games`, `1x2`, `{"game":"2048"}` |
| too small a card | PASS — Sudoku says so instead of drawing an unreadable grid |
| losing a game | NOT TESTED — Minesweeper's mine branch was not driven |

## Whole-menu regression

| case | result |
|---|---|
| all four pages | PASS — Home, Apps, Places, Info instantiated, three full cycles |
| open/close 40 times | PASS — same plasmashell pid, 0 segfaults in the journal |
| add / resize / configure / remove a gadget, 12 rounds over 6 gadget types | PASS — count returns to 22 every round, no QML error |
| QML messages with logging on | PASS — **none at all** from `org.biglinux.appsmenu` |

## X11

| check | Wayland | X11 |
|---|---|---|
| Drive Info | 2 volumes, `38,0 GiB free of 50,0 GiB` | 2 volumes, `38,1 GiB free of 50,0 GiB` |
| Clipboard | 15 entries, all rendered | identical |
| Quick Links | 11 resolved, 10 tiles | identical |

Session type confirmed from the plasmashell process (`XDG_SESSION_TYPE=x11`,
`DISPLAY=:0`, `Xorg` + `kwin_x11`), never from the SSH shell.

## Not tested

Stated plainly rather than assumed:

* **Pointer and touch input anywhere.** Wayland blocks synthetic input.
* **Drag and drop**, which upstream Kickoff gates on
  `mouse.source === Qt.MouseEventNotSynthesized` and is therefore untestable by
  any injection tool.
* **Fractional / HiDPI scaling**, and resolutions other than the VM's.
* **A real USB stick** — this kernel ships no `usb-storage`, so the virtio path
  was used instead; it exercises the same Solid code.
* **Live score notifications firing on a real goal.**
* **Losing at Minesweeper**, and the clipboard's select/delete/clear buttons.
