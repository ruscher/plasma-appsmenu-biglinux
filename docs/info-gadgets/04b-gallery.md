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
