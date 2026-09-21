# Architecture

`org.biglinux.appsmenu` is a KDE Plasma 6 plasmoid implemented in Qt Quick/QML. `main.qml` owns the Kicker models and the Plasma instance state. `FullRepresentation.qml` provides the header, page stack, navigation sidebar, and first-run welcome overlay.

## Runtime flow

```text
main.qml
└── FullRepresentation.qml
    ├── Header.qml                 # one row: avatar/identity, search, session actions, Options (⋮)
    ├── VerticalStackView           # Home, Apps, Places, Info, Search
    ├── navigation sidebar
    └── components/OnboardingOverlay.qml
```

The pages use the following models from `main.qml`:

| Model | Used by |
| --- | --- |
| `RootModel` and its favorites model | Home, Apps, search, context actions |
| `RunnerModel` | Search results (see below) |
| `ComputerModel` | Places → Computer |
| `RecentUsageModel` for apps, documents, and folders | Home and Places |
| `RecentUsageModel` with popular ordering | Home and Places → Frequently Used |

The Apps page still uses the mature Kickoff grid-of-grids path for its all-apps view. Newer accessible views and delegates are used for the Home, category, list, favorites, and search paths. This split is intentional: the old view remains runtime code until an equivalent migration can be verified without changing app launch, drag-and-drop, or section navigation behavior.

## Search

The search field is KRunner, not a re-implementation. `main.qml` declares
`Kicker.RunnerModel` with `mergeResults: true` and no `runners` restriction,
which is byte-identical to upstream Kickoff 6.7.4. In that mode the model wraps
a single `RunnerMatchesModel`, which *inherits* `KRunner::ResultsModel` and
reads `krunnerrc [Plugins]` — so the enabled runners, their results, their
ordering and their actions are the desktop's own. `modelForRow(0)` is therefore
the merged model, not "the first runner".

Consequences worth knowing before changing anything here:

- Never add a calculator, unit converter, file or settings search. Those are
  the `calculator`, `unitconverter`, `baloosearch` and `krunner_systemsettings`
  runners and they already work.
- Never keep a local list of runners. Enabled/disabled state belongs to
  `krunnerrc`, and a `KConfigWatcher` already picks up changes live.
- Result ranking is KRunner's (categories ordered by favourite then relevance,
  with `krunner_services` favoured by default). No relevance value is exposed
  to QML, so any re-ordering here would be arbitrary. Discoverability is
  handled by category headings instead, which come from the model's `group`
  role via `AccessibleListView`'s section delegate.

`components/SoftwareSearch.qml` adds BigLinux-specific suggestions for software
that is not installed, rendered in a separate block *below* the results so it
can never outrank them. It shells out to `pamac search --repos --quiet` and
opens `pamac-manager --details=`; it installs nothing itself and disables
itself when Pamac is absent. Note that Plasma5Support's `executable` engine
runs through a **shell**, so the query is allowlist-validated and quoted before
it is used — see `docs/02-pamac-integration.md`.

## Navigation

`FullRepresentation.activateTab(index)` is the single entry point for "the user
asked for this tab". It cancels `pendingSearch`/`pendingTabIndex`, clears the
query, sets the index and switches the page, and is what every tab button
calls. Assigning `navBar.currentIndex` directly is not enough: clicking the
already-selected tab emits no change signal, and `onCurrentIndexChanged`
refuses to switch pages while a query is active. The `contentItemStackView.busy`
deferral must be preserved — it is what prevents the `StackView.replace()`
use-after-free.

## Info dashboard

`InfoPage.qml` persists an ordered gadget layout and a shared cache in `Plasmoid.configuration`. `GadgetGrid` packs the cards, `GadgetHost` isolates loader errors per card, and `GadgetRegistry` is the single catalogue of available gadgets. Online providers are optional and cached; the dashboard pauses gadget activity while the menu is inactive.

## Compatibility constraints

- Keep the plasmoid ID `org.biglinux.appsmenu` and the Plasma 6 package layout.
- Preserve existing `main.xml` configuration keys and their meanings.
- Do not replace the Kicker models or Plasma power actions with shell commands.
- StackView replacement must remain guarded while transitions are busy; this avoids the re-entrant lifecycle crash previously observed in plasmashell.
- New visible strings must go through `i18n()`/`i18nc()`/`i18np()`.

## Local checks

```bash
qmllint -I usr/share/plasma/plasmoids/org.biglinux.appsmenu/contents/ui \
  $(rg --files usr/share/plasma/plasmoids/org.biglinux.appsmenu | rg '\.qml$' | rg -v '/Header\.qml$')
kpackagetool6 --appstream-metainfo usr/share/plasma/plasmoids/org.biglinux.appsmenu
plasmoidviewer -a "$PWD/usr/share/plasma/plasmoids/org.biglinux.appsmenu"
```

The local `qmllint` may not parse the legacy Plasma-specific syntax in
`Header.qml` or `contents/ui/code/tools.js`; runtime validation remains required
for those files.
