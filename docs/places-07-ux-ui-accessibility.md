# Places · 07 — UX, UI and accessibility

Development notes. Nothing here is needed at runtime.

## Layout

```
┌────────────────────┬──────────────────────────────────────────────┐
│ ★ Frequently Used  │  ▪ Applications  12                          │
│ ▭ Computer         │    [icon] Google Chrome                      │
│ ⠿ History Apps     │           Acessar a internet                 │
│ ◷ History Files    │    …                                         │
│ ▤ History Folders  │  ▪ Folders  15                               │
│                    │    [icon] bigcam                             │
│                    │           Documentos/Git/bigcam/usr/share/…  │
└────────────────────┴──────────────────────────────────────────────┘
```

Category order is fixed and meaningful: what you use most, then where things
are, then what you used lately — narrowing from habit to history.

## Density

One line per item: `icon | name | secondary context`. No cards, no tiles, no
large delegates. Section headings are small, dimmed, and carry a discreet
count; they are labels, not buttons, so nothing invites a click that does
nothing.

Device rows are slightly taller because they carry a capacity bar, which is the
only place on this page where a second visual element earns its space.

## States

| State | Shown |
| --- | --- |
| History off | "Recent activity is turned off" + **Turn On** + **Activity History Settings** |
| History on, nothing recorded | "Nothing here yet" + what will appear |
| History Apps/Files/Folders empty | per-category message with a matching icon |
| Normal | the sections |
| Device unmounted | dimmed icon, no capacity, no action button |
| Device mounted | full icon, capacity bar, Unmount/Eject on hover |

The history-off state is shown for every category except Computer, which does
not depend on the activity manager and stays useful regardless.

## Icons

Every name was verified to exist in both Breeze and the BigLinux default theme
(`bigicons-papient-dark`) before use, rather than assumed:

| Use | Icon |
| --- | --- |
| Frequently Used | `starred-symbolic` |
| Computer | `computer` / `computer-laptop` when a lid is present |
| History Apps | `applications-all` |
| History Files | `document-open-recent` |
| History Folders | `folder-open-recent` |
| Devices heading | `drive-harddisk` |
| Folders / Files sections | `folder` / `document-multiple` |
| Eject / Unmount | `media-eject` / `media-playback-stop` |
| History-off state | `view-history` |

Device row icons come from Solid itself (`drive-harddisk`,
`drive-harddisk-root`, …), so they match what Dolphin shows.

No colour or size is hard-coded: everything uses `Kirigami.Units`,
`Kirigami.Theme` and icon names. The capacity bar is `Kirigami.Theme.highlightColor`,
switching to `negativeTextColor` above 90 % used.

## Keyboard

| Key | Behaviour |
| --- | --- |
| ↑ / ↓ in the sidebar | previous / next category |
| → or Enter in the sidebar | move into the content |
| ↑ / ↓ in the content | move through rows, hopping between sections at the edges and skipping empty ones |
| ← | back to the sidebar |
| Enter / Space | activate the row |
| Tab / Shift+Tab | the menu's normal header ↔ content cycle |
| Esc | handled by the header as everywhere else |

Section hopping is explicit because Frequently Used is three lists in one
Flickable rather than one list: each `ActivitySection` raises
`focusPreviousRequested` / `focusNextRequested` at its edges and the page
decides where to go, skipping sections with no rows. Focus never lands in an
empty or invisible list.

## Accessibility

* The page is `Accessible.Pane` named "Places"; the sidebar is
  `Accessible.PageTabList`.
* Each section is an `Accessible.Grouping` carrying its title, with the heading
  label marked `Accessible.Heading` and the list `Accessible.List`.
* Device rows announce their state rather than relying on the dimmed icon:
  *"Mounted. 82,2 GiB free of 447,0 GiB"* or *"Not mounted. Activating will
  mount and open it."*
* The Unmount/Eject button carries its own `Accessible.name`, which changes
  with which operation actually applies.
* The **Turn On** button has a description explaining what enabling the history
  does, so it is not just a bare verb to a screen reader.
* Item rows keep `AppDelegate`'s existing `Accessible.MenuItem` role and
  description handling — nothing regressed by reusing it.

## Responsiveness and RTL

Widths come from `Layout.fillWidth` and grid units; the sidebar follows the
same `preferredSideBarWidth` the Apps page uses, so the three pages line up.
Nothing uses fixed pixel sizes. Lists elide rather than wrap, and secondary
paths elide from the right.

Mirroring is inherited: the delegates are the project's existing ones, which
already respect `LayoutMirroring`. RTL was not tested on a live RTL session.

## Visual restraint

The brief warned against turning the menu into a dashboard. Concretely avoided:
no cards, no per-item thumbnails, no animated transitions between categories,
no badges beyond the small per-section counts, and no capacity numbers on
devices that are not mounted. The page should read as a list you scan, not a
panel you admire.
