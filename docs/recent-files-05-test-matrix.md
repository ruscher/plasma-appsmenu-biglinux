# Recent Files & Locations — 05 · Test matrix

Run on the BigLinux test VM, Plasma 6.7.4, **Wayland**. Only rows actually
executed are marked PASS.

`daemon` below means: inject a resource event through the same D-Bus method
applications use, then check whether a row appeared in
`ResourceEvent`. It is the only test that proves recording, as opposed to
proving a file was written.

## A · Configuration states

Each condition broken on its own, then repaired, with the daemon's real
behaviour checked each time.

| State | `tracking` | `reason` | `check` | daemon | Result |
| --- | --- | --- | --- | --- | --- |
| all on | `on` | `ok` | true | RECORDING | PASS |
| `what-to-remember=2` | `off` | `do-not-remember` | false | BLOCKED | PASS |
| → after `enable` | `on` | `ok` | true | RECORDING | PASS |
| current activity off-the-record | `off` | `off-the-record` | false | BLOCKED | PASS |
| → after `enable` | `on` | `ok` | true | RECORDING | PASS |
| OTR list `other,current,other` | `off` | `off-the-record` | false | — | PASS |
| → after `enable`, list = `aaaa-1111,bbbb-2222` | `on` | `ok` | true | — | PASS (other activities preserved) |
| `UseRecent=false` | `on` | `ok` | **false** | RECORDING | PASS (tracking on, documents off) |
| → after `enable` | `on` | `ok` | true | — | PASS |
| `enabled=false` | `off` | `plugin-disabled` | false | **RECORDING** | PASS (key is a no-op; reported for UI agreement) |
| → after `enable` | `on` | `ok` | true | — | PASS |
| `what-to-remember=1` | `limited` | `specific-applications` | true | — | PASS |
| → after `enable`, value still `1` | — | — | — | — | PASS (user's choice preserved) |
| after `disable` | `off` | `plugin-disabled` | false | BLOCKED | PASS |
| after re-`enable` | `on` | `ok` | true | RECORDING | PASS |

## B · Data preservation

| Check | Before | After disable → enable | Result |
| --- | --- | --- | --- |
| `ResourceEvent` rows | 15 | 15 | PASS — history kept |
| `recently-used.xbel` bookmarks | 16 | 16 | PASS — XDG list kept |

The old implementation deleted both on every enable.

## C · End-to-end recording, real applications

| Action | Recorded as | Result |
| --- | --- | --- |
| `kwrite ~/Documents/biglinux-recent-test-01.txt` | `org.kde.kwrite` → that file | PASS |
| `kwrite ~/Downloads/biglinux-recent-test-03.txt` | `org.kde.kwrite` → that file | PASS |
| `dolphin ~/biglinux-recent-testdir` | `org.kde.dolphin` → that folder | PASS |
| app launched from the menu | `applications:<id>` via Kicker's `ResourceInstance::notifyAccessed` | PASS |

Note: **Recent Apps only fills when applications are launched from a Kicker
based launcher** (this menu, Kickoff). `libkickerplugin.so` is what calls
`notifyAccessed("applications:…")`; starting a program from a terminal or
`kstart` is not recorded. Verified: `kstart org.kde.okular` produced no
`applications:` row. This is upstream behaviour, not a BigLinux defect.

## D · The models the menu actually renders

Via an offscreen harness instantiating `Kicker.RecentUsageModel` exactly as
`main.qml` does:

| Model | `shownItems` / ordering | Count | Result |
| --- | --- | --- | --- |
| Recent Apps | `shownItems=1` | 2 (Dolphin, KWrite) | PASS |
| Recent Files | `shownItems=2` | 3 test files | PASS |
| Recent Folders | `shownItems=3` | 1 test folder | PASS |
| Frequently Used | `ordering=1` | 6 | PASS |
| default | — | 6 | PASS |

## E · User interface

| Case | Evidence | Result |
| --- | --- | --- |
| Home with history | Screenshot: Recent Apps (2), Recent Files (3), Recent Folders (2), no call to action | PASS |
| Home, feature off | Screenshot: "Recent files and locations are turned off" + **Turn on recent files** + **Open settings…**, in the exact state that used to hide the button | PASS |
| Places > History | Screenshot: History selected, recorded items listed | PASS |
| Places > Frequently Used | Screenshot: Aplicativos / Pastas / Arquivos sections populated | PASS |
| `enable()` driven through the real QML component | `off`/`off-the-record` → `busy` → `on`/`ok`, then daemon RECORDING | PASS |
| Clicking the button with a real pointer | NOT TESTED — Wayland blocks synthetic input. The click handler is a one-line call to the `enable()` path proven above. |

## F · Dolphin

| Case | Evidence | Result |
| --- | --- | --- |
| Recent Files | Dolphin window titled "Recent Files" listing all three test files with paths and access times | PASS |
| Recent Locations | `recentlyused:/locations` returns `biglinux-recent-testdir` and the home folder | PASS |
| Places sidebar "Recent" group | Visible in the screenshot, with **Recent Files** entry | PASS |

## G · Cross-project consistency

`menu` = `recent-activity check`; `settings` = `recentFiles.sh check`.

| Transition | menu | settings | daemon | Result |
| --- | --- | --- | --- | --- |
| baseline | true | true | RECORDING | PASS |
| settings switch OFF | false | false | BLOCKED | PASS |
| settings switch ON | true | true | RECORDING | PASS |
| broken via off-the-record | false | false | BLOCKED | PASS |
| menu "Turn on" repairs it | true | true | RECORDING | PASS |
| broken via `what-to-remember=2` | false | false | BLOCKED | PASS |
| settings switch ON repairs it | true | true | RECORDING | PASS |

In the real GUI: the **Recent Files & Locations** switch shows ON in the
working state and OFF when the activity is set off-the-record — matching the
menu in both cases. PASS.

## H · Persistence

| Case | Result |
| --- | --- |
| `systemctl --user restart plasma-kactivitymanagerd.service` | PASS — `check=true`, still RECORDING |
| `systemctl --user restart plasma-plasmashell.service` | PASS — `check=true`, models still populated |
| Reboot / logout–login | **NOT TESTED** — `systemctl reboot` over SSH is refused by polkit ("requires interactive authentication") and privileged package/power operations were unavailable in this environment. The settings are plain files in `~/.config`, and the daemon restart test above exercises the same "read configuration at startup" path a boot would. |

## I · Baloo independence

| Case | Result |
| --- | --- |
| `balooctl6 disable` → check, daemon, all four models | PASS — everything still works with Baloo off |
| Baloo restored to its original enabled state | PASS |

## J · Script quality

| Script | `bash -n` | `shellcheck -S style` |
| --- | --- | --- |
| `recent-activity` / `recentActivity.sh` | PASS | PASS (clean) |
| `recentFiles.sh` | PASS | PASS (clean) |
| `recentFilesRun.sh` | PASS | PASS (clean) |

Also verified: `recentFiles.sh check` run from `/` produces the correct answer
and **no** output on stderr — the old version printed three
`local: can only be used in a function` errors and depended on `$PWD`.

## K · QML

With `QT_LOGGING_RULES` set to surface warnings (the image ships `*=false`,
which hides everything), opening Home and Places produced:

- No `TypeError`, `ReferenceError`, binding loop, or `Cannot assign` — PASS.
- One pre-existing warning, unrelated to this work and present on `main`:
  `FullRepresentation.qml: QML OnboardingOverlay: Detected anchors on an item
  that is managed by a layout`. Left alone; fixing it is out of scope here.

`qmllint` reports no syntax errors on the four changed QML files.

## L · Session type

Tested on **Wayland** only — that is what the VM runs. The implementation
reads configuration files and talks to the session bus; it never touches
`DISPLAY` or `XAUTHORITY`, so it is X11-compatible by construction. X11 was
NOT TESTED.
