# 10. Live Scores — a score that is actually in the middle

## Why the score drifted

Each row was `Team | score | Team` with both team columns as plain
`Layout.fillWidth` items. A `RowLayout` gives every filling item its implicit
width first and shares only the remainder, so two columns whose contents differ
in length end up different widths — and the pill between them is wherever
that leaves it, not in the middle.

Both columns now carry `Layout.preferredWidth: 0` (and `minimumWidth: 0`), so
they start from the same base, split the remainder evenly, and stay symmetric
whatever the names are.

Measured in the running gadget on a 444 px row, with deliberately lopsided
fixtures:

| row | before | after |
|---|---|---|
| `Sport Club Internacional de Porto Alegre` vs `Vasco` | **107 px off centre** | **0** |
| `Ajax` vs `Borussia Moenchengladbach Football Club` | **117 px off centre** | **0** |
| `Flamengo` vs `Palmeiras` | 1 px | **0** |

## Logos and names

Badges grow from 16 px to 22 px, and to 32 px on a wide card — moderate, as
asked. The logo occupies a **fixed slot** whether or not a badge exists, so
rows line up either way, and a missing or failed badge falls back to the team's
abbreviation in a circle instead of collapsing the row. Names elide to one line
and carry a tooltip with the full name, shown only when the label is actually
truncated. The match list scrolls vertically.

## Configuration

The league picker was a `Flow`, which left ragged rows and pushed the last
leagues out of view. It is a `GridLayout` whose column count comes from the
real width — verified by building the page at three widths and reading back
what it chose:

| width | columns |
|---|---|
| 34 grid units | **3** |
| 22 grid units | **2** |
| 12 grid units | **1** |

The dialog already scrolls vertically, so a long list stays reachable, and the
last league cannot be unticked — following nothing would only produce a blank
card.

Two settings were added:

* **Refresh live scores** — 30 s / 1 min / 2 min / 5 min, defaulting to a
  minute. 30 s is the floor offered, out of respect for a free API.
* **Notify me about live matches** — kick-off, goals and full time.

## Notifications, and their limit

State is compared between polls and a notification is sent only on a change,
so the same goal is never announced twice. When notifications are off the state
is still tracked, so switching them on does not immediately announce matches
that were already running.

The limitation is stated in the settings, in the user's own language: alerts
can only be noticed **while the Info page is open**. Nothing here runs in the
background, and adding a daemon purely for score alerts is not a trade this
project makes — which is exactly the choice the brief asked to document rather
than paper over.

## What the free API actually provides

Checked rather than assumed, because the brief forbids listing sports without
working data:

| endpoint | result |
|---|---|
| `livescore.php?s=Soccer` | 31 live matches |
| `…Basketball` | 3 |
| `…American Football` | 14 |
| `…Baseball` | 2 |
| `…Ice Hockey` | 11 |
| `…Motorsport` | **no live feed** (fixtures still work) |
| `eventsnextleague.php` | **one** upcoming fixture per league — a free-tier cap |
| API v2 `livescore` | HTTP 400, needs a paid key |

Every sport in the list has working data except Motorsport, which has fixtures
but no live feed, and the FIFA World Cup entry, which is empty outside a
tournament. No sports were added: the API's usable sports were already all
represented, and padding the list was explicitly ruled out.

**NOT TESTED:** the notifications were not observed firing against a real goal
— that needs a match to score while the page is open. The change-detection
logic was exercised, but the end-to-end alert is reported as untested rather
than claimed.

---

# 11. Gallery — more formats, verified rather than declared

## What was checked, and how

Adding extensions to a filter proves nothing, so the target system was asked
directly. `kimageformats 6.29.0` is installed and supplies `kimg_avif.so`,
`kimg_heif.so` and `kimg_jxl.so`; `libheif 1.23.3`, `libjxl 0.12.0`,
`libavif 1.4.2`, `libwebp 1.6.0` and `libtiff 4.7.2` are all present.
`QImageReader.supportedImageFormats()` on that system returns **102** formats,
including every one asked for.

That is still only a claim about the library, so each format was then decoded
**inside the running plasmashell**: real samples were generated with
`magick`, `avifenc`, `cjxl` and `heif-enc`, dropped in a folder, and loaded
through the gadget's own `Image` elements.

| format | `Image.status` | decoded size |
|---|---|---|
| png | Ready | 160 × 120 |
| jpg / jpeg | Ready | 160 × 120 |
| tif / tiff | Ready | 160 × 120 |
| webp | Ready | 160 × 120 |
| avif | Ready | 160 × 120 |
| heic | Ready | 160 × 120 |
| heif | Ready | 160 × 120 |
| jxl | Ready | 160 × 120 |
| `corrupt.png` (400 random bytes) | **Error** | — |

## A broken picture no longer costs a turn

`onStatusChanged: if (status === Image.Ready) shown = true` meant a picture
that failed simply never appeared: the slide came to the front at zero opacity
and the previous one stayed visible for a whole interval, and the slideshow
would return to it on every pass.

Failures are now remembered and skipped. `usableFrom(i, dir)` walks to the
first picture that has not already failed, in the direction the user is going,
and returns −1 when every picture in the folder is unreadable — so a folder of
broken files cannot spin. The skip is deferred by a tick, because advancing
straight out of `onStatusChanged` would reassign the source of the image still
reporting its status. Changing folder forgets the failures.

The diagnostic names the file and nothing else:

```
GalleryGadget: cannot decode corrupt.png — skipping it
```

Observed in the test: `brokenRemembered: 1`, and the slideshow had already
moved on to `index: 1`.

Also, `caseSensitive: false` replaces the hand-written `*.JPG` / `*.JPEG` /
`*.PNG` entries, which covered three extensions out of eleven. Loading was
already asynchronous with `sourceSize` capped at 1024 × 1024, so a large
photograph is never decoded at full resolution for a thumbnail-sized card.

## Packaging

`kimageformats` is an **optional** dependency — the gadget works without it,
just without AVIF, HEIC/HEIF and JPEG XL — and is now documented in
`pkgbuild/PKGBUILD` as such, together with `glib2` for the `gio` that Quick
Links uses to launch desktop entries.

---

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
