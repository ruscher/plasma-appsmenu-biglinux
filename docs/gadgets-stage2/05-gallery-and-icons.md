# 05 — Gallery navigation and gadget icons

## Gallery

The Previous/Next buttons were there, and the user was right that they were
not: `opacity: 0` until the card was hovered, and even then bare tool-button
glyphs painted straight onto the photograph. Discoverability zero at rest;
contrast luck on hover.

Now each button is an `AbstractButton` on a translucent dark disc with a light
rim, which reads on any picture. At rest it sits at 35 % — visibly there — and
comes to 95 % on card hover, keyboard focus or its own hover. Tooltips and
`Accessible.name` are set. With the gadget focused (it takes focus on click,
and `activeFocusOnTab`), Left and Right step through the pictures; other keys
are not touched, so the menu's own navigation is unaffected. Measured on the
VM: rest opacity 0.35, 40 px discs.

## Icons

Rule applied: a symbolic glyph wherever one exists, checked on disk, with a
fallback per entry. The registry gained `iconFallback`; `GadgetTitleBar` and
the Add dialog pass it to `Kirigami.Icon.fallback`.

Facts that decided the names:

* `bigicons-papient` declares `Inherits=hicolor` only, but KIconLoader adds
  Breeze as an implicit fallback — the edit badges have rendered
  `configure-symbolic`, a Breeze-only name, all along. So a Breeze-only
  symbolic is safe on BigLinux, and the fallback covers a theme with neither.
* `Kirigami.Icon.valid` is **not** a presence test; it returned `true` for
  invented names. Presence was checked with `find` in both theme trees.

| gadget | icon | fallback |
|---|---|---|
| Games | `applications-games-symbolic` (both themes) | `applications-games` |
| Gallery | `folder-pictures-symbolic` (both) | `folder-pictures` |
| Calendar | `office-calendar-symbolic` (BigLinux) | `view-calendar-symbolic` (Breeze) |
| Sensor | `temperature-normal-symbolic` (Breeze) | `temperature-normal` |
| Fans | own SVG, `gadgets/icons/fan-symbolic.svg` | `temperature-normal` |
| the rest | their symbolic variant | their coloured name |

No fan glyph exists in Breeze or the BigLinux theme, so the Fans gadget ships
an original 16 px symbolic SVG (three blades and a hub, `currentColor`).
Icons loaded from a file are not recoloured by the theme machinery, so a
`-symbolic` file source is rendered as a mask; that is handled in the title
bar, the gallery and the gadget itself.
