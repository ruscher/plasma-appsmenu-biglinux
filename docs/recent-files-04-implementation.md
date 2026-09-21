# Recent Files & Locations — 04 · Implementation

## plasma-appsmenu-biglinux

### `contents/tools/recent-activity` — new

The canonical helper described in [03](recent-files-03-fix-plan.md). Self
contained, `bash -n` clean, `shellcheck -S style` clean. Its header documents
which keys matter on Plasma 6 and which are inert, so the next person does not
have to re-derive it.

### `contents/ui/components/RecentActivityTracking.qml` — rewritten

| Before | After |
| --- | --- |
| Built `kreadconfig6` command lines inline in QML | Runs the shared helper, parses `key=value` |
| `tracking = enabled && whatToRemember !== 2` | `trackingState` from the helper: `on` / `limited` / `off` / `unknown` |
| Never looked at `off-the-record-activities` | The helper does, against the **current** activity |
| `enable()` wrote the two keys it also checked, so the button always vanished | `enable()` delegates, and trusts only the helper's verified exit code |
| Assumed success whenever the command finished | Non-zero exit → `trackingState = "error"`, button stays |
| Restarted `plasma-kactivitymanagerd.service`, with a `kquitapp6` fallback | Nothing is restarted; `kwriteconfig6 --notify` is enough |
| Fixed 1.5 s settle timer before re-reading | No timer; the helper has already verified before it exits |

The property is `trackingState`, not `state`: `Item` already has a built-in
`state` property and shadowing it is a trap.

The warning about `IsFeatureOperational` is kept in the file header — it was
correct, and is now backed by a reproduction.

### `contents/ui/HomePage.qml`

- New `recentHistoryCount`, the sum of the four recent/frequent model counts.
- The call-to-action box became a five-state box (`boxState`): `disabled`,
  `enabling`, `error`, `empty`, `hidden`. Previously it was a single "off"
  message that either appeared or did not.
- Added a `PC3.BusyIndicator` for `enabling`, an error border and
  `dialog-error` icon for `error`.
- The two buttons are hidden unless the box is actionable, and get
  `activeFocusOnTab` so they are reachable by keyboard.
- `Accessible.description` added on the box; the title/body text now change
  with the state, so assistive technology reads the real situation.

### `contents/ui/FullRepresentation.qml`

Places > History and Frequently Used render the same activity data, so they get
the same explanation instead of an unexplained blank list: a
`RecentActivityTracking` instance drives `emptyText`, which distinguishes
"turned off" from "nothing here yet", with separate wording for History and
Frequently Used.

### `contents/ui/components/AccessibleListView.qml`

Added `emptyIconName` (default `edit-none`) so a page can match the placeholder
icon to what is missing; Places uses `document-open-recent`.

## biglinux-settings

### `usability/recentActivity.sh` — new

Byte-identical copy of the plasmoid's helper:

```
$ cmp plasma-appsmenu-biglinux/…/contents/tools/recent-activity \
      biglinux-settings/…/usability/recentActivity.sh   # no output
```

### `usability/recentFiles.sh` — rewritten

- The three `local` declarations outside any function are gone; they were
  fatal-looking errors on every single `check`.
- `$PWD/usability/recentFilesRun.sh` replaced with a path derived from
  `${BASH_SOURCE[0]}`, so the app works from any working directory.
- The KDE branch of `check` now calls `recentActivity.sh check`, so it agrees
  with the menu by construction.
- `FilesEnabled` is no longer consulted (no consumer in KF 6), and `UseRecent`
  unset is correctly read as enabled rather than disabled.
- GNOME / XFCE / Cinnamon branches kept, with quoting fixed and
  `XDG_CURRENT_DESKTOP` guarded against being unset.

### `usability/recentFilesRun.sh` — rewritten

Everything destructive is gone:

| Removed | Why |
| --- | --- |
| `balooctl6 suspend` / `disable` / `enable` / `resume` | Baloo is not in this code path |
| `killall baloo_file dolphin kactivitymanagerd kioworker kiod6` | Nothing needs restarting |
| `systemctl --user stop/start/restart plasma-kactivitymanagerd` ×3 | `kwriteconfig6 --notify` is picked up live |
| `rm -rf ~/.local/share/kactivitymanagerd/resources` | Destroyed the history on every enable |
| Rewriting `recently-used.xbel` from a here-doc | Destroyed the XDG recent list |
| `kwriteconfig6 … kioslaverc recentlyused …` | Keys nothing reads |
| zenity progress dialog | The operation is now instant |
| "You need to close and reopen Dolphin" notice | No longer true |

What remains: call the helper, and on failure print the reason and show one
error dialog. The exit code is the helper's verified result, which is what
`base_page.toggle_script_state()` uses to decide whether the switch moved.

### `usability_page.py`

Unchanged. It already called `check` / `toggle` correctly; the scripts behind
them were the problem.
