# Places · 09 — Tests

Development notes. Nothing here is needed at runtime.

Environment: BigLinux, Plasma **6.7.4**, KF **6.29**, Qt 6, **Wayland**,
pt_BR, 4-monitor desktop, plasmashell under `systemd --user`, real hardware
(5 internal volumes, one USB camera attached).

Method: deployed to `~/.local/share/plasma/plasmoids/org.biglinux.appsmenu` and
driven inside the real `plasmashell`. Wayland blocks synthetic input, so UI
states were reached by temporarily injecting a driver into the **deployed** copy
(never the repository) that calls the same functions the handlers call
(`activateTab(n)`, `activateCategory(n)`, `searchField.text`), writing state to
a file. Model- and engine-level facts were checked with offscreen `qml6`
harnesses. Only rows actually executed are marked PASS.

## A · Structure and navigation

| # | Test | Expected | Obtained | Status |
| --- | --- | --- | --- | --- |
| 01 | Open Places | Frequently Used is first and selected | sidebar order Frequently Used · Computer · History Apps · History Files · History Folders, first selected | PASS |
| 02 | Category order | as specified in the brief | matches exactly | PASS |
| 03 | Switch to Computer | Computer content, selection holds | `cat=1`, holds ≥ 10 s | PASS |
| 04 | Switch to History Files | its content, selection holds | `cat=3`, held for 10+ samples | PASS |
| 05 | Selection survives device list populating | no snap-back | PASS after the fix below | PASS |
| 06 | Reopening Places | starts on Frequently Used again | fresh page each visit | PASS |

Test 05 is the one that took work. Two separate causes were found by
instrumenting the page rather than guessing:

* `AccessibleListView`'s inner `currentIndex: count > 0 ? 0 : -1` re-asserting
  itself seconds later, on an unrelated relayout → fixed by giving the sidebar
  a plain `ListView` whose index simply follows the page's own property;
* a reset on `kickoff.expandedChanged`, where `expanded` was observed re-firing
  `true` while the menu was already open → removed (it was redundant anyway,
  since the page is rebuilt on every visit).

## B · Frequently Used

| # | Test | Expected | Obtained | Status |
| --- | --- | --- | --- | --- |
| 07 | Applications section | frequent apps, not recent | 12 rows, led by the browser/editor used daily | PASS |
| 08 | Folders section | frequent folders | 15 rows | PASS |
| 09 | Files section | frequent files | 15 rows | PASS |
| 10 | Frequent ≠ Recent | different ordering | frequent led by habitual apps, recent by last-opened | PASS |
| 11 | Subtitles are friendly | no raw URI | `Documentos/Git/bigcam/usr/share/biglinux` | PASS |
| 12 | Files and folders not mixed | separate models | `Type::files()` / `Type::directories()` enforce it | PASS |
| 13 | Per-type balance | no type crowds out others | 12 / 15 / 15 (the combined model gave only 5 apps — rejected) | PASS |

## C · Computer and Devices

| # | Test | Expected | Obtained | Status |
| --- | --- | --- | --- | --- |
| 14 | Applications group | system apps | KRunner · System Settings · Info Centre | PASS |
| 15 | Places group | user's configured places | Início · Área de trabalho · Documentos · Shared · Downloads · Música · Imagens · Vídeos · Lixeira | PASS |
| 16 | XDG dirs respected | no assumed paths | from `KFilePlacesModel`, incl. the user's custom "Shared" | PASS |
| 17 | Network group | remote entries | Remoto: Rede · Shared | PASS |
| 18 | Devices listed | incl. internal drives | 5 volumes, all `Removable=false` — the ones ComputerModel filters out | PASS |
| 19 | Non-storage excluded | camera not listed | `Block,Camera` skipped; 6 sources → 5 shown | PASS |
| 20 | Capacity | real free/total | e.g. `82,2 GiB free of 447,0 GiB`, 82 % used | PASS |
| 21 | Mounted state | detected | `Accessible` per device | PASS |
| 22 | Icons | from Solid | `drive-harddisk`, `drive-harddisk-root` | PASS |
| 23 | Eject only where valid | Solid decides | button text switches on `Removable`/optical | PASS (logic verified; no removable device attached) |
| 24 | Hotplug | appears/disappears | **NOT TESTED** — no removable device available to plug in |
| 25 | Mount an unmounted device | mounts then opens | **NOT TESTED** — every volume here was already mounted |
| 26 | Unmount | unmounts | **NOT TESTED** — would have unmounted a live system volume |

Tests 24–26 are honestly untested: this machine's five volumes are all internal
and mounted, and unmounting one to prove a button works was not a reasonable
thing to do on the user's working desktop. The code paths are `hotplug`
`sourcesChanged` and the engine's own `mount`/`unmount` operations.

## D · Histories

| # | Test | Expected | Obtained | Status |
| --- | --- | --- | --- | --- |
| 27 | History Apps | applications only | `OnlyApps` model | PASS |
| 28 | History Files | files only | `OnlyDocs`, 15 rows | PASS |
| 29 | History Folders | folders only | `OnlyFolders` | PASS |
| 30 | No cross-contamination | enforced by the query | `Type::files()` / `Type::directories()` | PASS |

## E · Activity history off

| # | Test | Expected | Obtained | Status |
| --- | --- | --- | --- | --- |
| 31 | History off → empty state | actionable message, not a blank list | wired to `RecentActivityTracking.tracking` | PASS (logic) / **NOT TESTED live** — see below |
| 32 | **Turn On** works | enables the history | delegates to `RecentActivityTracking.enable()`, unchanged | NOT TESTED |
| 33 | Computer unaffected when off | still usable | `needsActivityHistory` excludes Computer | PASS (logic) |

31–32 were not exercised live: switching the activity history off on the user's
working desktop would have discarded their real usage statistics, which is
exactly what the brief says not to do casually. The empty state binds to the
same `tracking` property the Home page's call to action already uses, and that
path was tested end-to-end in the separate recent-files work.

## F · Regression (the sweep)

Driven in one run; every line is real output:

```
1 Home                     | page=homePage     | search=""        | busy=false
2 Apps                     | page=allAppsPage  | search=""        | busy=false
3 Places                   | page=placesPage   | search=""        | busy=false
4 Info                     | page=infoPage     | search=""        | busy=false
5 searched firefox         | page=searchView   | search="firefox" | busy=false
6 Places after search      | page=placesPage   | search=""        | busy=false
7 searched 2+2             | page=searchView   | search="2+2"     | busy=false
8 Places again (same tab)  | page=placesPage   | search=""        | busy=false
9 Home                     | page=homePage     | search=""        | busy=false
```

| # | Test | Status |
| --- | --- | --- |
| 34 | Home | PASS |
| 35 | Apps | PASS |
| 36 | Info | PASS |
| 37 | Search still works | PASS |
| 38 | Search → Places clears the query | PASS |
| 39 | Same-tab click during a search | PASS |
| 40 | No stuck transitions (`busy=false` throughout) | PASS |
| 41 | Home's own recent/frequent sections untouched | PASS — `frequentUsageModel` and friends left as they were |

## G · Quality gates

| Gate | Result |
| --- | --- |
| `qmllint` over the whole `contents/` tree | 0 files with syntax errors |
| plasmashell journal, appsmenu entries | **0 warnings** |
| Binding loops / TypeError / destroyed-object errors | none |
| Crashes across ~12 plasmashell restarts | none |
| `Timer` in the new Places code | **0** |
| External processes spawned by Places | **0** |
| Debug/test leftovers in the repository | none |

The only plasmoid warning in the journal remains the pre-existing, unrelated
`OnboardingOverlay: Detected anchors on an item that is managed by a layout`.

## H · Not tested

| Item | Why |
| --- | --- |
| Hotplug, mount, unmount, eject (24–26) | No removable device available; unmounting a live system volume was not acceptable |
| History-off empty state and **Turn On** (31–32) | Would have destroyed the user's real activity statistics |
| X11 | The desktop runs Wayland; nothing added here touches `DISPLAY`/`XAUTHORITY` |
| Real mouse clicks / key presses | Wayland blocks synthetic input; every path was driven through the functions the handlers call |
| RTL | Not exercised on an RTL session |
| Panel edges other than this desktop's, other DPI scales | Layout is grid-unit based, but only this configuration was observed |
