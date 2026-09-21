# Recent Files & Locations — 06 · Final validation

Final state of the test VM after the work, and the evidence behind each
acceptance criterion.

## Final state

```
$ recent-activity diagnose
== recent files & locations ==
  tracking=on
  reason=ok
  documents=on
  enabled=true
  activity=82dd571b-19a5-41da-b9fa-e65d403c625b
  off-the-record=
  what-to-remember=0
  blocked-by-default=false
  use-recent=true

== services ==
  kactivitymanagerd: active

== history size (not required for the switch, shown for support) ==
  ResourceEvent rows: 36
  recently-used.xbel entries: 16
```

Compare with the state as found: `off-the-record` held the only activity and
`ResourceEvent` had **0** rows.

## Acceptance criteria

| # | Criterion | Result |
| --- | --- | --- |
| 1 | Correctly detects when Recent Files is disabled | PASS — all five broken states detected with the right reason (05 §A) |
| 2 | "Turn on" really enables everything needed | PASS — repairs each broken state; daemon verified RECORDING afterwards |
| 3 | The button does not disappear prematurely | PASS — with `enabled=true`, `what-to-remember=0` and the activity off-the-record, the box is now shown (screenshot); previously hidden |
| 4 | Recent Apps works | PASS — model count 2, visible in the menu |
| 5 | Recent Files works | PASS — model count 3, visible in the menu |
| 6 | Recent Folders works | PASS — model count 2, visible in the menu |
| 7 | Places > History works | PASS — screenshot with History selected and items listed |
| 8 | Places > Frequently Used works | PASS — screenshot, sectioned apps/folders/files |
| 9 | Dolphin Recent Files works | PASS — window titled "Recent Files" listing the test files |
| 10 | Dolphin Recent Locations works | PASS — `recentlyused:/locations` returns the test folder and home |
| 11 | Both projects show the same state | PASS — seven transitions, always in agreement (05 §G), confirmed in both GUIs |
| 12 | Disabling works | PASS — daemon BLOCKED afterwards |
| 13 | Re-enabling works | PASS |
| 14 | Re-enabling does not destroy data | PASS — 15 → 15 `ResourceEvent` rows, 16 → 16 xbel bookmarks |
| 15 | Settings survive a service restart | PASS |
| 16 | Settings survive a Plasma restart | PASS |
| 17 | No new relevant QML errors | PASS — no TypeError/ReferenceError/binding loops; one pre-existing unrelated warning already on `main` |
| 18 | No important regressions | PASS — favourites, search, Apps, Places, Computer, keyboard navigation and menu startup all exercised while taking the screenshots |
| 19 | Shell scripts pass `bash -n` | PASS — and `shellcheck -S style` clean |
| 20 | Root cause documented and proven | PASS — [02](recent-files-02-root-cause.md), with a controlled experiment and upstream source |

## Explicitly not verified

- **Reboot / logout–login.** `systemctl reboot` over SSH is refused by polkit
  (interactive authentication required), and privileged operations were not
  available in this environment. Service and Plasma restarts were tested and
  pass; the settings are ordinary files under `~/.config`.
- **X11 session.** The VM runs Wayland. No `DISPLAY`/`XAUTHORITY` dependency
  exists in the new code, but X11 was not exercised.
- **Physical click on the button.** Wayland blocks synthetic input; the
  `enable()` path behind the click was driven directly through the real QML
  component instead, against the genuinely broken state.
- **`shellcheck` on the VM itself.** Installing packages there required
  privileges that were not available; the checks were run against an official
  static `shellcheck` 0.10.0 binary on the development machine.

## Observation for later, not a defect

Places > History is bound to `kickoff.recentUsageModel`, which `main.qml`
configures with `shownItems = 1` (applications only) because the Home page's
"Recent Apps" section shares it. So Places > History lists recently used
*applications*, while Frequently Used lists apps, folders and files. Both are
populated and working; whether "History" should instead show everything is a
design decision, not part of this fix.

## Restored after testing

- `off-the-record-activities` cleared, feature on (the VM's working state).
- Baloo re-enabled (it was enabled originally).
- `QT_LOGGING_RULES` set back to the image default `*=false`.
- `plasma-org.kde.plasma.desktop-appletsrc` restored from backup after the
  temporary `lastTab` change used for screenshots.
- The temporary `categorySidebar.currentIndex` timer injected into the
  *deployed* `FullRepresentation.qml` for screenshots was reverted; it was never
  in the repository.
- Config backups left in `~/recent-files-backup-20260921-093903/`.
