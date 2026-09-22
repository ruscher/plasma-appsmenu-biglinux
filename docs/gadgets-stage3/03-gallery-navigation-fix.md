# 03 — Gallery: arrows that were never removed

## The report

> The navigation arrows appear at first and then disappear. Putting the
> mouse over the image does not bring them back.

## The cause

Not opacity, not hover, not a loader. The arrows were there the whole
time — underneath the photograph.

The gadget crossfades between two `Slide` items that swap their stacking
on every transition:

```qml
Slide { id: back;     z: gallery.front ? 0 : 1 }
Slide { id: frontImg; z: gallery.front ? 1 : 0 }
```

One of the two therefore always sits at `z: 1`, and the navigation
buttons were left at the default `z: 0`. Before the first picture
finishes decoding both slides are fully transparent and the arrows show;
the moment one paints, it paints over them. Hover only changes opacity,
which cannot lift an item drawn underneath something else — which is
exactly why hovering "did not bring them back".

The fix is one line per element: the buttons are `z: 10` and the
click-through area that opens the picture is `z: 5`, so the order is
explicit rather than accidental.

## Behaviour

At rest the arrows sit at 0.45 opacity on a translucent dark disc with a
light border, which reads on a bright picture and on a dark one; hovering
the card, hovering a button, or giving the gadget keyboard focus brings
them to 0.95. With a single picture they are hidden entirely, since there
is nowhere to go.

The target is the disc, not the glyph: a medium icon plus spacing on each
side, about 1.8 grid units square. Each carries a tooltip and an
accessible name (*Previous picture* / *Next picture*), and Left and Right
step through the folder when the gadget has focus, which it takes on
click.

## What was checked

| case | result |
|---|---|
| 212 pictures, the developer's own folder | arrows visible at rest and on hover |
| after many automatic transitions | still visible — the z fix is not state-dependent |
| one picture | arrows hidden, as intended |
| no pictures | empty state with *Choose folder* |
| a picture that cannot be decoded | skipped, remembered, and the slideshow moves on (unchanged from stage 1) |

The slideshow timer still pauses while the card is hovered, so reading
the arrows does not make the picture change under the pointer.

![the card with its arrows](img/gallery-arrows.png)

## Status

| | |
|---|---|
| arrows never permanently invisible | **TESTED ON REAL HARDWARE** |
| hover works after many changes | **TESTED ON REAL HARDWARE** |
| manual navigation | **TESTED ON REAL HARDWARE** (through the gadget's own API) |
| keyboard Left/Right | **NOT TESTED** — synthetic input does not reach this compositor's popup |
| corrupt pictures ignored | **TESTED ON VM** in stage 1, unchanged here |
