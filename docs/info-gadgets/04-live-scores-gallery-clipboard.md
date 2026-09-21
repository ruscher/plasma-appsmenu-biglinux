# 12. Clipboard — the real Klipper / SUPER+V history

## Reported

The gadget shows something like `8 items` in its header, but the list is
empty.

## Root cause — an id shadowed by a built-in property

Not a `required property` failure, and not the wrong model. The journal (with
`QT_LOGGING_RULES` re-enabled — this VM silences QML warnings session-wide)
showed the same two lines repeating for every row:

```
ClipboardGadget.qml:61: TypeError: Property 'preview' of object false is not a function
ClipboardGadget.qml:74: TypeError: Property 'preview' of object false is not a function
```

`object false` is the clue. The root item was declared `Item { id: clip }`,
and **every `Item` already has a `clip : bool` property**. Inside a delegate —
itself an `Item` — `clip` resolves to the delegate's own boolean, not to the
root id, so `clip.preview(…)` is `false.preview(…)` and throws. The label
binding failed on every row, so every row drew empty while the header, bound
outside any delegate, still counted the entries correctly: exactly "N items
and an empty list".

The same shadowing silently broke the Show/Hide button: `clip.masked` read
`false.masked`, which is `undefined` rather than an error, so the button never
reflected the real setting.

## What the model actually provides

Verified against `klipperplugin.qmltypes` and Plasma's own delegates on the
running system, not assumed:

| role | type | notes |
|---|---|---|
| `display` | string | text, or Klipper's own label for an image |
| `decoration` | variant | usable **directly** as an `Image.source` |
| `imageSize` | size | original pixel size of an image entry |
| `uuid` | string | identity for `moveToTop()` / `remove()` |
| `type` | int | `2` text, `4` image, `8` URL |

The type numbers are Plasma's own, read from the `DelegateChoice` blocks in
`ClipboardMenu.qml`. `HistoryModel` is a `QSortFilterProxyModel` over the one
history object in this plasmashell process, so this **is** the SUPER+V
history — there is no second clipboard.

## Fix

* `id: clip` → `id: clipboard`, which is what actually repaired the list.
* Hover now shows the whole entry, as asked: a tooltip with the full text,
  wrapped and bounded (20 grid units wide, 2000 characters), so a long paste
  cannot produce an endless tooltip.
* Image entries get a real thumbnail in the row and a bounded preview in the
  tooltip (at most 16 × 12 grid units), plus a localised `Image · 120 × 80`
  label built from `imageSize` instead of Klipper's untranslatable `▨ 120x80`.
* Masking now wins everywhere, including the tooltip and the thumbnail —
  revealing on hover what the user asked to hide would defeat the setting.
* The list scrolls vertically. It used to hide every row past a fixed count
  with `visible: index < maxRows`, silently dropping the rest of the history;
  now the entries beyond the fold are reachable, and only vertically
  (`flickableDirection: Flickable.VerticalFlick`), with rows eliding instead
  of scrolling sideways.

Privacy is unchanged and deliberate: nothing reaches the network, and no
content is written to the log — the tests below measure only lengths, types
and dimensions.

## Tests (Plasma 6.7.4, Wayland, lab VM)

Seeded with **our own** entries (`wl-copy`), never the user's data:

| Check | Result |
|---|---|
| rows render | `listCount 15`, `contentHeight 584`, first delegate instantiated — **PASS** |
| text previews | lengths 60 / 33 / 43 / 6 / 91 — real content, and 91 confirms the 90-character elision — **PASS** |
| masking | every preview exactly 12 characters (`••••••••••••`) with `masked: true` — **PASS** |
| image entry | `type 4`, `imageSize 120 × 80` — **PASS** |
| thumbnail loads | `Image.status == 1` (Ready), decoded `120 × 80` from the `decoration` role — **PASS** |
| image label | 16 characters = `Image · 120 × 80` — **PASS** |
| journal | no ClipboardGadget errors or warnings — **PASS** |

One finding worth recording: **Klipper ignores images by default** on this
installation. With stock settings no image ever enters the history, so the
image path is dead code for most users until they enable it in Klipper. The
test enabled `IgnoreImages=false` temporarily and removed `~/.config/klipperrc`
afterwards (the file did not exist before).

**NOT TESTED:** hovering and clicking were not exercised by pointer — Wayland
blocks synthetic input and `spectacle` core-dumps on this VM — so the tooltip
was verified by construction and by the absence of binding errors, not
visually.
