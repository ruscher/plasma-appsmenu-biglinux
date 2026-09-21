# 05 · Final report

Development notes. Nothing here is needed at runtime.

# Summary

The search field was already KRunner — that was the single most important
finding, and it changed the shape of the work. `main.qml`'s `Kicker.RunnerModel`
declaration is byte-identical to upstream Kickoff 6.7.4, and with
`mergeResults: true` the model it exposes *inherits* `KRunner::ResultsModel`
and reads `krunnerrc`. The calculator, unit converter, file search, settings
search and every other enabled runner already worked; what was missing was
proof, presentation, and the surrounding UX.

So nothing was re-implemented. Instead: the navigation bug was fixed, the header
was rebuilt around an expanding search field, "Leave" became a kebab "Options"
moved to the end of the row, and a Pamac-backed suggestion for software that is
not installed was added as a clearly separated block below the results.

# Architecture changes

- `components/SoftwareSearch.qml` — new, self-contained, optional.
- The shared `softwareSearch` instance lives in `main.qml`, so its Pamac probe
  runs once per plasmoid and its cache survives the results page being rebuilt.
- `FullRepresentation.activateTab(index)` — new single entry point for tab
  activation.
- `Header.qml` — two rows collapsed into one with a state-driven expansion.
- `docs/architecture.md` gained **Search** and **Navigation** sections.

# Files changed

| File | Change |
| --- | --- |
| `contents/ui/main.qml` | +8 — shared `SoftwareSearch` instance |
| `contents/ui/Header.qml` | rewritten — single row, expanding search, Escape handling |
| `contents/ui/FullRepresentation.qml` | +55 — `activateTab()`, tabs routed through it, dead property dropped |
| `contents/ui/SearchResultsPage.qml` | reworked — software section, installed-app gate, keyboard/a11y |
| `contents/ui/components/PowerMenu.qml` | Options kebab, moved after the quick buttons |
| `contents/ui/components/SoftwareSearch.qml` | new |
| `contents/ui/components/qmldir` | registers the new component |
| `docs/00`–`docs/05`, `docs/architecture.md` | documentation |

# KRunner integration

Verified against the v6.7.4 / v6.29.0 sources and on the running system:

- `mergeResults: true` ⇒ one child model; upstream asserts `m_models.length() == 1`,
  so `modelForRow(0)` is the merged model.
- `RunnerMatchesModel : public KRunner::ResultsModel`, constructed from
  `krunnerrc [Plugins]`.
- `runners` unset ⇒ `setAllowedRunners({})` ⇒ no restriction ⇒ whatever
  `krunnerrc` enables, with a `KConfigWatcher` for live changes.

Full plugin matrix in [01-krunner-integration.md](01-krunner-integration.md).

# Enabled runner behavior

Proven, not assumed:

```
calculatorEnabled=true   → "10*25" → Calculadora: 250
calculatorEnabled=false  → calculator gone
calculatorEnabled=true   → Calculadora: 250
```

Also found: `webshortcutsEnabled=false` in this user's krunnerrc is a **stale
Plasma 5 key** — the id is `krunner_webshortcuts`. It affects the KRunner
window identically, so it is a config-hygiene note rather than a parity gap.
krunnerrc was restored byte-identical.

# Calculator tests

`2+2`→4, `10*25`→250, `100/4`→25, `sqrt(144)`→12, `2^10`→1024, `(15+5)*3`→60.
All from `calculator.so`. No `eval()` anywhere in the project.

# Unit conversion tests

`1 l em ml`→1.000 ml · `2 litros em ml`→2.000 ml · `5 m em cm`→500 cm ·
`100 km em mi`→62,1373 mi · `30 C em F`→86 °F · `1 GB em MB`→1.000 MB ·
`10 kg em g`→10.000 g.

`1 l in ml` correctly returns nothing: the converter's keywords are translated
and pt_BR uses `em;para;como`, not `in;to;as`. Confirmed in
`plasma_runner_converterrunner.mo`. The KRunner window behaves the same way.

# Search result actions

Unchanged and still working: actions arrive via `ActionListRole` and render
through the existing `AppDelegate`/`ActionMenu` path; Enter launches the current
item through `Header.onAccepted`.

# Pamac integration

`pamac search --repos --quiet` (~205 ms, relevance-sorted) for discovery;
`pamac-manager --details=<pkg>` to open the package. `--repos` keeps AUR and
Flatpak out of the keystroke path. `pamac info` was rejected at **1756 ms**,
which is why suggestions show no description.

The pamac D-Bus daemon was inspected and offers only privileged transaction
members — no read-only search — so the CLI is the right mechanism.

Suggestions are suppressed when an installed application already matches,
detected via the untranslated `applications:` favouriteId. Verified live:
`inkscape` (installed as a Flatpak) shows no suggestion; `scribus` does.

Nothing is ever installed by the menu.

# Security

Plasma5Support's `executable` engine **runs through a shell** — demonstrated,
not assumed (`echo A; touch /tmp/x` created the file). The user's query is
therefore treated as untrusted:

1. allowlist `^[A-Za-z0-9À-ɏ ._+-]{3,64}$` plus "must contain a letter";
2. single-quoting with `'\''` escaping as a second line of defence;
3. package names re-validated before reaching `--details=`.

12 injection payloads were tried; all blocked, no file ever created.

A latent trap was found while testing: **Qt's V4 engine does not implement
`\p{L}`/`\p{N}` Unicode property escapes** and silently evaluates them to
`false`, which had disabled the whole feature (fail-closed, so never unsafe).
The pattern now uses explicit ranges.

# Performance

Debounce 350 ms · minimum 3 characters and at least one letter · generation
counter drops stale replies · 40-entry cache · at most 3 suggestions · one
availability probe per plasmoid. `DataSource` is asynchronous, so nothing
blocks the GUI thread. Arithmetic and unit queries never trigger a package
lookup at all.

# Navigation fix

Two independent faults, both fixed:

- `onClicked: navBar.currentIndex = n` emits nothing when the value is
  unchanged, so clicking the already-selected tab did nothing;
- `onCurrentIndexChanged` only switched pages when `searchText.length === 0`,
  and the query was never cleared by navigation.

`activateTab(index)` now cancels `pendingSearch`/`pendingTabIndex`, sets the
index, clears the query and switches the page, in that order. All four tabs
pass the same-tab test, and a rapid-fire burst correctly engaged the
`StackView.busy` deferral and settled clean.

# Header UX

One row: avatar · identity · search · session actions · Options. The identity
block collapses while searching, driven by
`searchActive = text.length > 0 || (activeFocus && focusReason !== Qt.OtherFocusReason)`
— the `focusReason` test is what lets the menu focus the field on open (so
typing works immediately) without the header starting in its expanded state.
Animations use Kirigami durations, which already honour "reduce animations".

Placeholder is adaptive: `Search…` at rest, `Search apps, files, settings,
calculations…` while searching.

# Power/Options UX

"Leave" → **"Options"**, icon `view-more-symbolic` (verified to be the vertical
kebab, not the horizontal variant, and present in Breeze, Breeze Dark and the
BigLinux theme), moved to **after** the quick buttons. `Kicker.SystemModel` and
`systemFavorites` untouched; no shell commands introduced.

# Accessibility

Search field has a short `Accessible.name` plus a descriptive
`Accessible.description`; Options is `Accessible.ButtonMenu` and says it opens
a menu; collapsed controls are `enabled: false` / `activeFocusOnTab: false` so
they leave the focus order; software suggestions are buttons announcing
"Install <package> with Pamac" and explaining that Pamac opens for review.
Escape clears the query, then falls through to close the menu.

# Wayland tests

Everything above was executed on Wayland (Plasma 6.7.4, 4-monitor desktop,
plasmashell under `systemd --user`).

# X11 tests

**NOT TESTED.** The machine runs Wayland and switching the user's live session
was too disruptive. Nothing added here touches `DISPLAY` or `XAUTHORITY`; the
new code paths are configuration reads, QML layout and `Plasma5Support.DataSource`,
all session-agnostic.

# Regression tests

Home, Apps, Places, Info/gadgets, session actions, last-tab persistence and
repeated open/close cycles all verified — see
[04-test-matrix.md](04-test-matrix.md) §F. `qmllint` reports no syntax errors
across the tree, and the plasmashell journal shows **zero** warnings from this
plasmoid across roughly ten restarts, no binding loops, no TypeErrors and no
crashes.

# Known limitations

- Relevance is not exposed to QML, so the menu cannot sort by it. `2+2` still
  shows weak application matches above the answer, exactly as the KRunner
  window does. Category headings make the answer findable; the user can change
  the favoured category in KRunner's settings and both will follow.
- Software suggestions show no description, because the only way to get one
  costs 1.7 s per package.
- Only official repositories are searched for suggestions.
- Synthetic input is impossible under Wayland, so clicks and key presses were
  exercised through the functions the handlers call rather than through the
  input stack.
- One pre-existing warning remains and was left alone as out of scope:
  `OnboardingOverlay: Detected anchors on an item that is managed by a layout`.

# Remaining recommendations

1. Fix the `OnboardingOverlay` anchors-in-a-layout warning (pre-existing).
2. Consider tidying the stale Plasma 5 keys in `krunnerrc`
   (`webshortcutsEnabled`, `appstreamEnabled`) — they mislead anyone comparing
   KRunner with this menu.
3. If descriptions for suggestions are ever wanted, they need a cheaper source
   than `pamac info` — an AppStream lookup would be the place to start.
4. Verify on X11 and on a machine without Pamac when one is available.
