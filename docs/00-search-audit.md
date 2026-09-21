# 00 · Search audit

Development notes. Nothing here is needed at runtime.

Environment: BigLinux (Manjaro), Plasma **6.7.4**, KDE Frameworks **6.29**,
Wayland, locale **pt_BR.UTF-8**, pamac/libpamac **11.7.4**.

## Headline finding

**The search is already KRunner.** No new search engine is needed, and building
a calculator, unit converter or file search would be duplicating work the
runners already do.

`contents/ui/main.qml` declares:

```qml
readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
    query: kickoff.searchField ? kickoff.searchField.text : ""
    onRequestUpdateQuery: query => { … }
    appletInterface: kickoff
    mergeResults: true
    favoritesModel: rootModel.favoritesModel
}
```

That block is **byte-identical** to upstream Kickoff 6.7.4
(`plasma-desktop/applets/kickoff/main.qml`, lines 84–94), modulo the
`rootModel` prefix.

The chain, confirmed in the upstream sources for the installed versions:

```
Kicker.RunnerModel  (plasma-workspace/applets/kicker/runnermodel.cpp)
   └─ mergeResults: true  ⇒ exactly ONE child model
        └─ RunnerMatchesModel : public KRunner::ResultsModel     ← inherits!
              (runnermatchesmodel.cpp:28, constructed from krunnerrc [Plugins])
                 └─ SortProxyModel → CategoryDistributionProxyModel
                    → KDescendantsProxyModel → HideRootLevelProxyModel
```

`RunnerMatchesModel` **inherits `KRunner::ResultsModel`** — the same class the
KRunner window uses. Same runners, same sorting, same actions. Parity is
therefore structural, not something to be re-implemented.

`modelForRow(0)` in `SearchResultsPage.qml` is correct *because* of
`mergeResults: true`: upstream asserts `m_models.length() == 1` in that mode
(`runnermodel.cpp:212`), so row 0 is the single merged model, not "the first
runner".

## Are the user's KRunner plugin choices respected?

Yes — proven, not assumed.

`RunnerModel::updateEnabledRunners()` leaves the allowed-runner list empty when
the QML `runners` property is unset (our case), which means "no restriction";
`RunnerManager` then loads whatever `krunnerrc [Plugins]` enables. A
`KConfigWatcher` on `krunnerrc` picks up changes live.

Verified on this machine with an offscreen `RunnerModel` harness:

| krunnerrc | query `10*25` result |
| --- | --- |
| `calculatorEnabled=true` (baseline) | `Calculadora` → **250** |
| `calculatorEnabled=false` | calculator gone, only a web-search fallback |
| `calculatorEnabled=true` (restored) | `Calculadora` → **250** |

### Stale keys in this user's krunnerrc (not our bug)

`webshortcutsEnabled=false` has no effect — the real plugin id is
`krunner_webshortcuts`. Setting `krunner_webshortcutsEnabled=false` does
disable it (verified). The file also carries both `appstreamEnabled` and
`krunner_appstreamEnabled`, i.e. leftovers from the Plasma 5 → 6 id migration.
This affects the KRunner window exactly as much as it affects this menu, so it
is a config-hygiene note, not a parity gap. krunnerrc was restored byte-identical
after testing.

## What the runners actually return here

Offscreen `Kicker.RunnerModel` harness, real queries:

| Query | Result |
| --- | --- |
| `firefox` | `Navegador Firefox` — Web Browser |
| `10*25` | **250** (`Calculadora`) |
| `sqrt(144)` | **12** |
| `2^10` | **1024** |
| `(15+5)*3` | **60** |
| `1 l em ml` | **1.000 mililitros (ml)** (`Conversor de unidades`) |
| `2 litros em ml` | **2.000 mililitros (ml)** |
| `5 m em cm` | **500 centímetros (cm)** |
| `100 km em mi` | **62,1373 milhas (mi)** (+ nmi, mm, mil) |
| `30 C em F` | **86 graus Fahrenheit (°F)** |
| `1 GB em MB` | **1.000 megabytes (MB)** |
| `10 kg em g` | **10.000 gramas (g)** |
| `display` | 20 rows: settings modules, apps, "Configurações da tela" |
| `network` | 58 rows across several runners |
| `Downloads` | folders, places, bookmarks |

### Unit conversion is not broken — it is localised

`1 l in ml` returns only a web-search fallback on this machine, and that is
correct behaviour. The converter runner's keyword list is translated; in
pt_BR (`plasma_runner_converterrunner.mo`):

```
msgctxt "list of words that can used as amount of 'unit1' [in|to|as] 'unit2'"
msgid  "in;to;as"
msgstr "em;para;como"
```

So `em`, `para` and `como` work; `in` does not. The mission's English examples
simply do not apply to a pt_BR session. This must not be "fixed" by adding a
parallel converter — doing so would break the moment KDE changes the syntax.

## Ranking: understood, and deliberately left alone

`2+2` puts the calculator's `4` at index 3, below three weak application
matches (`GstarCAD 2026`, `IRPF 2026`, …, which match the digit `2` in "2026").

This is **upstream KRunner behaviour**, not a defect here:

```cpp
// runnermodel.cpp:34-38 — default favourite category
m_favoritePluginIds = krunnerrc.group("Plugins").group("Favorites")
        .readEntry("plugins", QStringList(QStringLiteral("krunner_services")));
```

```cpp
// resultsmodel.cpp SortProxyModel::lessThan — categories first by favourite
const int favoriteA = sourceA.data(ResultsModel::FavoriteIndexRole).toInt();
if (favoriteA != favoriteB) return favoriteA > favoriteB;
const int typeA = sourceA.data(ResultsModel::CategoryRelevanceRole).toInt();
```

Applications are a favourite category by default, so they outrank the
calculator regardless of relevance. The KRunner window does the same thing.

Moreover `RunnerMatchesModel::data()` exposes only Display, Decoration,
`GroupRole`, `DescriptionRole`, `FavoriteIdRole`, `UrlRole`,
`HasActionListRole`, `IsMultilineTextRole` and `ActionListRole` — **no
relevance role reaches QML**. Any re-ordering we invented would therefore be
arbitrary, which the brief explicitly rules out.

**Decision:** keep KRunner's order exactly (parity), and solve discoverability
through presentation instead — category headings, which the model already
supports via `GroupRole`. `components/AccessibleListView.qml` already sets
`section.property: "group"`, and `SearchResultsPage.qml` does not override it,
so headings come for free.

## The real defect: tabs are dead during a search

`FullRepresentation.qml`:

```qml
onClicked: navBar.currentIndex = 0        // …and 1, 2, 3
```

```qml
onCurrentIndexChanged: {
    Plasmoid.configuration.lastTab = currentIndex
    if (root.header && root.header.searchText.length === 0) {
        switchToTab(currentIndex)          // ← blocked while searching
    }
}
```

Two independent failures, which together kill every tab click during a search:

1. **Same tab** — `currentIndex = 0` when it is already `0` emits no change
   signal, so nothing runs at all.
2. **Different tab** — the index changes, but the `searchText.length === 0`
   guard suppresses `switchToTab()`. The query is never cleared, so the guard
   never opens.

The search text is never cleared by navigation, and `pendingSearch` can also
pull the view back to the results page afterwards.

Fix: one central `activateTab(index)` that clears the query, cancels
`pendingSearch`/`pendingTabIndex`, sets the index and switches the page — while
keeping the `contentItemStackView.busy` deferral that exists to avoid the
`StackView.replace()` use-after-free crash documented in `architecture.md`.

## Header today

`Header.qml` is a `ColumnLayout` of two rows:

1. a full-width `PlasmaExtras.SearchField`;
2. avatar (3 gridUnits) + user name/host + `Components.PowerMenu`.

The brief wants one row — avatar · search · actions · Options — with the search
expanding over the avatar while it is in use.

## PowerMenu today

`components/PowerMenu.qml` is a `RowLayout`:

1. a "Leave" `ToolButton` (`system-log-out-symbolic`) opening the full session
   menu;
2. a `Repeater` of the configured `systemFavorites` quick buttons.

Wanted: renamed to "Options", a kebab (⋮) icon, and moved **after** the quick
buttons. The underlying `Kicker.SystemModel` / `systemFavorites` wiring stays —
session actions must keep going through Plasma's own model, never shell
commands.

## Installable-software suggestions

`krunner_appstream.so` exists and would surface installable software, but it is
**disabled** in this user's krunnerrc, and it targets Discover rather than
Pamac. Since the brief asks specifically for Pamac, and since forcing a runner
the user disabled would violate the "respect the configuration" rule, the
suggestion feature is built as its own BigLinux-side addition rather than by
enabling a runner behind the user's back.

`pamac-manager` is present (11.7.4); its CLI surface is examined in
[02-pamac-integration.md](02-pamac-integration.md).

## Plan

1. Fix tab navigation during search (central `activateTab`), preserving the
   StackView busy guard.
2. Rework the header into one row with an expanding search field.
3. Rename Leave → Options, kebab icon, move after the quick buttons.
4. Add Pamac suggestions for software that is not installed, debounced,
   argv-safe, and degrading silently when Pamac is absent.
5. Category headings + result presentation polish; keep KRunner's ranking.
6. Document and test.
