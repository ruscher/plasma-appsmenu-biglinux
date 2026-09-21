# 03 · Issues and root causes

Development notes. Nothing here is needed at runtime.

Three defects were found and fixed. Each was reproduced on the VM, traced to a
cause in the code, fixed, and re-tested — none was worked around by silencing a
warning or adding a delay.

---

## #1 — P1 — The header opened in its "searching" state

**Symptom.** Every time the menu opened, the avatar and the user name were
missing and the search field showed its long placeholder, as if the user were
already searching.

```
Expected:  [avatar] Ruscher            [ Search… ]        [⏻][⟳][⏻][⋮]
            ruscher@ruscher-standardpc

Observed:  [ Search apps, files, settings, calculations… ] [⏻][⟳][⏻][⋮]
```

**File.** `contents/ui/Header.qml`

**Cause.** `searchActive` inferred the user's intent from the focus reason:

```qml
readonly property bool searchActive: searchField.text.length > 0
    || (searchField.activeFocus && searchField.focusReason !== Qt.OtherFocusReason)
```

The field is focused deliberately when the menu opens, so the user can type
straight away, using `forceActiveFocus(Qt.OtherFocusReason)`. The assumption was
that this focus would be distinguishable from a click or a Tab.

It is not. The field ends up focused through the popup's own focus chain, and
the reason Qt reports for that is not the one passed to `forceActiveFocus`.
Measured by instrumenting the running plasmoid on the X11 session:

```
expanded=true activeFocus=true focusReason=3 (BacktabFocusReason) text="" searchActive=true
```

`BacktabFocusReason`, not `OtherFocusReason` — so the test was true at rest.

This is precisely the class of bug this audit exists to find: the behaviour
depended on how the popup's focus chain happened to resolve, which is not
something to rely on being identical across backends or timings.

**Fix.** Track intent explicitly instead of inferring it. `searchEngaged` is set
by a real tap on the field (a `TapHandler` with `DragThreshold` policy, so it
never steals the grab from text selection) or by tabbing in from the avatar,
and is reset every time the menu opens. Typing expands it anyway, because the
text itself is the intent.

No focus-reason logic remains, so there is nothing left that could behave
differently on X11 and Wayland.

**Verified.** Resting header shows the avatar and `Search…`; clicking the field
collapses the avatar and shows the long placeholder. Confirmed on both backends
(see 01 and 02).

---

## #2 — P1 — "Recent activity is turned off" covered live content in Places

**Symptom.** In Places, the call to action sat on top of Frequently Used and the
three history categories — with real rows visible underneath it — even though
the activity history was running.

**File.** `contents/ui/PlacesPage.qml`

**Cause.** An API mismatch that only exists once the feature branches are
integrated. `components/RecentActivityTracking.qml` used to expose a boolean
`tracking`; the recent-files work replaced it with a state string
`trackingState` (`on` / `limited` / `off` / `error` / `unknown`).
`HomePage.qml` was updated; `PlacesPage.qml`, written on a branch that still had
the old API, was not:

```qml
active: root.needsActivityHistory && !recentActivity.tracking
```

`recentActivity.tracking` is now `undefined`, `!undefined` is `true`, so the
overlay was unconditional.

Each branch was self-consistent on its own, which is why this only appeared
after the merge — and why auditing the integrated tree rather than one branch
was the right call.

**Fix.** Places derives `historyOff` from `trackingState` using the same rule
`HomePage` uses, including treating `unknown` as working so the call to action
never flashes while the first probe is still in flight.

**Verified.** Overlay gone; Computer, Frequently Used and the histories render
normally, and the overlay still appears correctly when the history really is
off (it was genuinely off on this VM at first boot — see #4 below).

---

## #3 — P2 — Package suggestions for arithmetic and unit conversions

**Symptom.** Searching `1 l em ml` returned the correct conversion and then
offered to install `perl`, `docbook5-xml` and `python-elementpath`.

**File.** `contents/ui/components/SoftwareSearch.qml`

**Cause.** The allowlist decided whether a query was *safe to pass to a shell*,
not whether it plausibly *named software*. `1 l em ml` is harmless, so it was
handed to `pamac search --repos --quiet`, which matched the loose words against
package descriptions.

**Fix.** Two additional rules, both cheap:

* a query whose first word is a bare number is arithmetic or a unit conversion,
  never a package name;
* at least one word must be three characters or more and contain a letter, so
  `l em ml` is rejected while `obs studio` is kept.

Verified against a table of queries: `1 l em ml`, `100 km em mi`,
`10 liters in ml`, `30 C em F` and `2+2` are now skipped; `obs studio`,
`firefox`, `gimp`, `inkscape`, `visual studio code`, `área de trabalho` and
`system settings` still look software up; the injection payloads
(`obs; touch …`, `$(x)`, …) remain rejected — the security rules were not
touched and were re-tested.

Side benefit: one fewer process spawned per conversion.

**Verified.** `1 l em ml` now shows only the conversion.

---

## #4 — not a defect — the VM proved the recent-files fix end to end

Worth recording because it is the strongest evidence in this audit.

This VM booted with the activity history off in the *worst* configuration —
all three blockers set at once:

```
what-to-remember=2
enabled=false
off-the-record-activities=82dd571b-…   ← the current activity
```

One click on **Turn on recent files** in the menu produced:

```
tracking=on  reason=ok  documents=on  enabled=true
off-the-record=          what-to-remember=0
```

and the activity manager then actually recorded:

```
ResourceEvent: 0 -> 1  (RECORDING)
```

with Home showing the file under **Recent Files** immediately afterwards. The
recent-files work had never been exercisable on a genuinely broken system
before; this VM was one.

---

## Investigated and explained, not defects

### Drag and drop cannot be driven by automation

`xdotool` starts no drag, and the reason is in the code — upstream Kickoff's:

```qml
// Only enable drag and drop with a mouse.
// We don't have a good way to handle it and drag scrolling with touch.
mouseArea.dragEnabled = mouse.source === Qt.MouseEventNotSynthesized
```

`xdotool` injects through XTEST, so Qt reports the press as synthesized and the
drag is deliberately never armed. The same guard applies to any uinput-based
tool on Wayland. So DnD is reported as NOT TESTED rather than FAIL — the code
path is intact and uses Qt's backend-agnostic `Drag.Automatic` API.

### The context menu is not stuck

It briefly looked like the context menu would not close. It is a separate
plasmashell popup window (`323x200+791+213`); `Escape` sent while focus was on
the launcher never reached it. A click outside dismisses it normally.
Test-harness error, not a product bug.

## Static result worth stating plainly

There is **no backend-specific code in the plasmoid**. A search for
`DISPLAY`, `XAUTHORITY`, `X11`, `Xlib`, `wayland`, `xdotool`, `xrandr`,
`xprop`, `Qt.platform`, `platformName`, `isWayland`, `isX11` across every
`.qml` and `.js` file returns only the explanatory comments added by fix #1.
Drag and drop uses Qt's abstract `Drag` API, applications are launched through
Kicker models, and there is no direct window, coordinate or compositor access —
which is why the same build behaves the same on both backends.
