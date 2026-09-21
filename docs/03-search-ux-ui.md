# 03 · Search UX / UI

Development notes. Nothing here is needed at runtime.

## Header: before and after

Before — two rows, the search field owning the whole first one:

```
┌──────────────────────────────────────────────────────────────┐
│ [ Search applications, settings, and files…                ] │
│ (avatar) Ruscher            [Leave ▾] [⏻][⟳][⟲]            │
└──────────────────────────────────────────────────────────────┘
```

After — one row, search between identity and actions:

```
┌──────────────────────────────────────────────────────────────┐
│ (avatar) Ruscher   [ Search…            ]  [⏻][⟳][⟲] [⋮]    │
│          user@host                                           │
└──────────────────────────────────────────────────────────────┘
```

and while searching, the identity block yields its space:

```
┌──────────────────────────────────────────────────────────────┐
│ [ Search apps, files, settings, calculations…  ] [⏻][⟳][⟲][⋮]│
└──────────────────────────────────────────────────────────────┘
```

## When does it expand?

`Header.searchActive` drives everything:

```qml
readonly property bool searchActive: searchField.text.length > 0
    || (searchField.activeFocus && searchField.focusReason !== Qt.OtherFocusReason)
```

The `focusReason` test is the interesting part. The menu focuses the search
field as soon as it opens, so the user can type immediately — but that focus is
given with `Qt.OtherFocusReason`, and is excluded here. The result:

| Situation | Expanded? |
| --- | --- |
| Menu just opened (field focused, ready to type) | no — avatar visible |
| User clicks the field (`MouseFocusReason`) | yes |
| User tabs into the field (`TabFocusReason`) | yes |
| User types anything | yes |
| Query cleared and focus left | back to no |

This resolves the tension between "let me type straight away" and "show me my
avatar when I am not searching" without a mode switch or an extra click.

## Animation

Avatar width/opacity and the identity block's `maximumWidth`/opacity animate
with `Kirigami.Units.shortDuration` and `Easing.OutCubic`. Kirigami's durations
are already scaled by the desktop's animation-speed setting and go to zero when
animations are switched off, so "reduce animations" is honoured simply by using
them — no separate code path.

Collapsed controls get `visible: false` and `enabled: false` once their width
reaches zero, so nothing invisible can be clicked or tabbed into.

Two binding loops were avoided deliberately, and the reasons are in the code:

- the identity block's collapse is driven by `Layout.maximumWidth` only —
  deriving a `preferredWidth` from its own `implicitWidth` feeds back through
  the layout;
- `shouldCollapseButtons` is a plain width threshold, because anything derived
  from the buttons' own `implicitWidth` would loop through their `visible`.

## Placeholder

Adaptive, since the field has two very different widths:

| State | Text |
| --- | --- |
| resting | `Search…` |
| searching | `Search apps, files, settings, calculations…` |

The short form keeps the resting row calm; the long form only appears once
there is room for it. Both go through `i18n()`.

## Results presentation

Results are grouped under their runner's category heading — "Aplicativos",
"Calculadora", "Conversor de unidades", "Configurações do sistema",
"Palavras-chave de pesquisa na Web" — which comes from the model's `group` role
through the section delegate already present in
`components/AccessibleListView.qml`. No grouping was invented; the headings are
exactly the categories KRunner reports.

This is what makes KRunner's ranking acceptable without changing it: for `2+2`
the answer sits under a visible **Calculadora** heading even though three weak
application matches precede it (see
[01-krunner-integration.md](01-krunner-integration.md)).

Software suggestions render in their own block below the list, separated by a
`Kirigami.Separator` and a "Software" heading, so they read as an aside rather
than as a search result.

## Options (was "Leave")

| | Before | After |
| --- | --- | --- |
| Label | "Leave" | **"Options"** (`i18nc("@action:button open session and power options", "Options")`) |
| Icon | `system-log-out-symbolic` | **`view-more-symbolic`** (kebab ⋮) |
| Display | text beside icon | icon only, with tooltip and `Accessible.name` |
| Position | **first**, before the quick buttons | **last**, after them |

Icon choice was verified rather than guessed. `view-more-symbolic` exists in
Breeze, Breeze Dark *and* the BigLinux default theme
(`bigicons-papient-dark`), and its geometry is three circles at the same `x`
with different `y`:

```
M 9,12.5 A 1.5,1.5 0 0 1 7.5,14 …   ← y = 12.5
M 9,8.5  A 1.5,1.5 0 0 1 7.5,10 …   ← y =  8.5
M 9,4.5  A 1.5,1.5 0 0 1 7.5,6  …   ← y =  4.5
```

i.e. a vertical kebab, not the horizontal "meatballs" variant — which ships
separately as `view-more-horizontal-symbolic` and is deliberately not used.

Ordering now reads `[logout] [restart] [shutdown] [⋮]`. The quick buttons
remain whatever `systemFavorites` says, so a user who customised them keeps
their choice; Options is simply always last. In a narrow popup
(`shouldCollapseButtons`) the quick buttons collapse into the menu and Options
is the single remaining control.

All actions still go through `Kicker.SystemModel`. No shell commands were
introduced.

## Keyboard

| Key | Behaviour |
| --- | --- |
| type on open | goes to the search field (focused on open) |
| ↑ / ↓ | move through results — `Keys.forwardTo` sends them to the list |
| Enter | launches the current result |
| Tab | search → session buttons → Options → content → software suggestions |
| Shift+Tab | reverse; skips the avatar while it is collapsed |
| Esc | clears the query; pressing it again with an empty field falls through and closes the menu |

`Keys.onEscapePressed` accepts the event only when there was text to clear, so
the second press reaches the popup and closes it, which is the Plasma
convention.

## Accessibility

- The search field has both `Accessible.name` ("Search") and a longer
  `Accessible.description` naming what it can do, so the short placeholder does
  not hide the capability from a screen reader.
- Options is `Accessible.ButtonMenu` with a description saying it opens a menu.
- Collapsed avatar/identity are `enabled: false` and `activeFocusOnTab: false`,
  keeping them out of the focus order rather than leaving invisible stops.
- Software suggestions are buttons with
  `Accessible.name: "Install <package> with Pamac"` and a description making it
  explicit that Pamac opens for review rather than installing immediately.
- The Software block is an `Accessible.Grouping` with a heading label.

## Responsiveness

The row uses `Layout.fillWidth` on the search field and intrinsic widths
elsewhere, so it adapts to the popup rather than to fixed pixel sizes. The
identity block is additionally capped at one third of the header width so a
long name cannot squeeze the search field. `shouldCollapseButtons` folds the
quick buttons into the menu below 26 grid units.
