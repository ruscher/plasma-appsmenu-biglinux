# Recent Files & Locations — 03 · Fix plan

## Goal

One definition of "enabled", shared by both projects, that matches what
kactivitymanagerd actually does — and a "Turn on" button that verifies its own
work instead of assuming it.

## Chosen approach

**One canonical helper script, copied verbatim into both repositories.**

```
plasma-appsmenu-biglinux   contents/tools/recent-activity
biglinux-settings          usability/recentActivity.sh
```

with the contract:

| Command | Output | Exit code |
| --- | --- | --- |
| `status` | `key=value` lines: `tracking`, `reason`, `documents`, `enabled`, `activity`, … | 0 |
| `check` | `true` / `false` | 0 |
| `enable` | the verified resulting `status` | 0 only if it really is on |
| `disable` | the verified resulting `status` | 0 only if it really is off |
| `diagnose` | human-readable report for bug reports | 0 |

`tracking` is `on` / `limited` / `off` / `unknown`, and `reason` says which
condition failed (`off-the-record`, `do-not-remember`, `plugin-disabled`,
`specific-applications`, `daemon-unreachable`). The UI needs the reason to
distinguish its states; a bare boolean cannot express "recording, but nothing
recorded yet".

### Why a script and not QML-only logic

The settings app is Python + shell and the menu is QML; a shell helper is the
only artefact both can execute unchanged. Keeping the copies byte-identical is
checkable in one command (`cmp`), which is the property that actually prevents
the two tools from drifting apart again.

### Why not a shared package

A cross-package dependency between the menu and the settings app would make
either one uninstallable without the other, for ~200 lines of shell. The
duplicated-but-identical file is the cheaper trade, and each repository stays
self-contained.

## Turning it on, minimally

The old implementation restarted `plasma-kactivitymanagerd.service`, and before
that killed half the desktop. None of it is needed: `StatsPlugin` holds a
`KConfigWatcher` on its own configuration file —

```cpp
m_configWatcher = KConfigWatcher::create(
    KSharedConfig::openConfig(QStringLiteral("kactivitymanagerd-pluginsrc")));
connect(m_configWatcher.get(), &KConfigWatcher::configChanged,
        this, &StatsPlugin::loadConfiguration);
```

— so writing with `kwriteconfig6 --notify` is picked up immediately. Verified,
with the daemon's PID unchanged throughout:

```
daemon pid = 1245317
set OTR   with --notify → events 10 -> 10   (blocked immediately)
clear OTR with --notify → events 10 -> 11   (recording immediately)
daemon pid after = 1245317   (never restarted)
```

So `enable` writes keys with `--notify` and does nothing else. No service
restart, no `killall`, no logout.

## What `enable` must do

1. Remove **only the current activity** from `off-the-record-activities`,
   preserving the user's choice for any other activity.
2. Set `what-to-remember=0` only when it is `2`; a value of `1` is a deliberate
   "only these applications" choice and is kept.
3. Write `enabled=true` (legacy, for agreement with System Settings).
4. Write `kdeglobals RecentDocuments/UseRecent=true`.
5. Un-hide the Places "Recent" group **only if** it is actually hidden.
6. Re-read everything and exit non-zero if the result is not what was asked
   for.

## What `disable` must NOT do

The old script deleted `~/.local/share/kactivitymanagerd/resources`, truncated
`recently-used.xbel`, killed Dolphin and disabled Baloo. All of it is removed:
flipping a switch must not destroy the history the user is trying to get back.
Clearing history stays a separate, explicit action in System Settings.

`disable` writes `what-to-remember=2` (the switch the daemon honours),
`enabled=false` and `UseRecent=false`. Nothing else.

## UI states

`RecentActivityTracking.qml` exposes `trackingState`, and `HomePage.qml` maps it
plus the model counts onto five states:

| State | Shown |
| --- | --- |
| `disabled` | "Recent files and locations are turned off" + **Turn on** + **Open settings…** |
| `enabling` | busy indicator, "Turning on recent files…" |
| `error` | "Could not turn on recent files" + **Try again** + **Open settings…** |
| `empty` | "No recent files yet" — on, but nothing recorded so far |
| `hidden` | on, with history: the box does not appear at all |

`unknown` (first probe not yet answered, or the helper missing) deliberately
shows nothing, so the call to action never flashes on a working system.

## Alternatives rejected

- **`balooctl6 enable`** — Baloo is not in this code path at all (proven in
  [02](recent-files-02-root-cause.md) §7).
- **Querying `IsFeatureOperational` over D-Bus** — makes the daemon exit, and
  returns `false` even when recording works (§8).
- **Restarting `plasma-kactivitymanagerd.service` on enable** — unnecessary
  given the `KConfigWatcher`, and it briefly drops the activity D-Bus service
  other applets talk to.
- **Writing `kioslaverc [recentlyused]` keys** — no consumer exists in KF 6
  (§5). Kept out of the new code entirely.
