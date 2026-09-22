# 07 — Drag auto-scroll

## Before

Dragging a card towards the top or bottom of the viewport scrolled the page
when the pointer came within `1.6 · gridUnit` (~29 px) of the edge. Nothing
showed where that zone was; the speed jumped from 0 to 125 px/s on entry and
ran linearly to 750 px/s.

## After

* The zone is `2.6 · gridUnit` (~47 px) at each edge.
* It is drawn while a card is dragged, and only towards an edge that can
  still scroll: a soft highlight gradient over the viewport with an arrow,
  at 55 % opacity as an invitation and 100 % while the pointer is inside. It
  is drawn over the viewport, not inside the content, so it never scrolls
  away, and it takes no input — the drag itself is what enters it.
* Speed is `min + (max − min) · depth²`, from ~90 px/s at the boundary to
  ~660 px/s at the very edge: gentle on entry, brisk when the user pushes,
  continuous throughout.
* Everything the grid already did to stay sane is unchanged: the card stays
  under the pointer (`scrollBy` compensates), reordering waits for the dwell
  timer and never happens while auto-scrolling.

## Verified

Driven through the grid's own drag API on the VM, from the bottom of the
board with the pointer 8 px into the top zone: `inTopZone: true`, zone opacity
1 while armed, 755 px of scroll in 1.5 s, `autoScrolling` held true for the
duration, and the zone fading out after the drop.

**Not tested:** a real pointer. Wayland blocks synthetic input on this VM.
