# 01 · KRunner integration

Development notes. Nothing here is needed at runtime.

## Conclusion first

**Nothing needed reimplementing.** The menu's search field is already driven by
KRunner's own model, and the audit showed the wiring matches upstream Kickoff
exactly. The work in this area was therefore verification, presentation and
documentation — not a new engine.

Concretely, a calculator, a unit converter, a file searcher or a settings
searcher were **not** written, because `calculator`, `unitconverter`,
`baloosearch` and `krunner_systemsettings` already provide them and the menu
already loads them.

## What was studied

| Source | Version | Used for |
| --- | --- | --- |
| `plasma-desktop/applets/kickoff/main.qml` | v6.7.4 | comparing the `RunnerModel` declaration |
| `plasma-workspace/applets/kicker/runnermodel.cpp` | v6.7.4 | how runners are discovered and filtered |
| `plasma-workspace/applets/kicker/runnermatchesmodel.cpp` | v6.7.4 | which roles reach QML |
| `frameworks/krunner/src/model/resultsmodel.cpp` | v6.29.0 | sorting and category order |
| the installed binaries | 6.7.4 / 6.29 | plugin ids, icon availability |

## How runners are discovered

`Kicker.RunnerModel` with `mergeResults: true` creates **one** child model:

```cpp
auto model = new RunnerMatchesModel(QString(), i18n("Search results"), this);
model->runnerManager()->setAllowedRunners(m_enabledRunners);
```

and `RunnerMatchesModel` is declared as

```cpp
RunnerMatchesModel::RunnerMatchesModel(…)
    : KRunner::ResultsModel(KSharedConfig::openConfig("krunnerrc")->group("Plugins"), …)
```

so it *is* a `KRunner::ResultsModel` reading `krunnerrc`. Because the QML
`runners` property is left unset, `updateEnabledRunners()` passes an empty
list, `setAllowedRunners({})` applies no restriction, and `RunnerManager`
loads exactly the plugins `krunnerrc [Plugins]` enables. A `KConfigWatcher` on
`krunnerrc` means a change in KRunner's settings is picked up without
restarting anything.

**Kickoff's RunnerModel has no intentional differences from KRunner here.** The
only deliberate difference is `mergeResults`, which flattens every category
into a single list instead of one model per runner — that is a presentation
choice, not a capability one.

## Plugin parity matrix

Measured with an offscreen harness instantiating `Kicker.RunnerModel` exactly
as `main.qml` does, against this machine's `krunnerrc`. "AppsMenu" is what the
harness returned; "KRunner" is what the same `KRunner::ResultsModel` yields by
construction, since it is literally the same class reading the same config.

| Plugin (krunnerrc id) | Enabled here | KRunner | AppsMenu | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| `services` (applications) | yes | ✔ | ✔ | PASS | `firefox` → Navegador Firefox |
| `calculator` | yes | ✔ | ✔ | PASS | `10*25` → 250, `sqrt(144)` → 12, `2^10` → 1024, `(15+5)*3` → 60 |
| `unitconverter` | yes | ✔ | ✔ | PASS | pt_BR keyword is `em`, not `in` — see below |
| `baloosearch` (files) | yes | ✔ | ✔ | PASS | `Downloads` returns files/folders |
| `krunner_systemsettings` | yes | ✔ | ✔ | PASS | `display` → Configurações da tela |
| `bookmarks` | yes | ✔ | ✔ | PASS | browser bookmarks appear for `Downloads` |
| `shell` | yes | ✔ | ✔ | PASS | `kill firefox` → "Executar kill firefox" (Linha de comando) |
| `desktopsessions` | yes | ✔ | ✔ | PASS | |
| `org.kde.datetime` | yes | ✔ | ✔ | PASS | |
| `org.kde.activities` | yes | ✔ | ✔ | PASS | |
| `Kill Runner` | yes | ✔ | ✔ | PASS | |
| `windows` | yes | ✔ | ✔ | PASS | |
| `krunner_webshortcuts` | **yes (effectively)** | ✔ | ✔ | PASS | see stale-key note |
| `krunner_appstream` | no | ✖ | ✖ | PASS | correctly absent; disabled by the user |
| `recentdocuments` | no | ✖ | ✖ | PASS | correctly absent |
| `placesrunner`, `locations` | no | ✖ | ✖ | PASS | correctly absent |
| `krunner_dictionary`, `CharacterRunner`, `Spell Checker`, `PowerDevil`, `kwin`, `plasma-desktop`, `katesessions`, `konsoleprofiles`, `helprunner`, `PIM Contacts` | no | ✖ | ✖ | PASS | correctly absent |

### Disabled plugins really are respected — proven

```
krunnerrc calculatorEnabled=true   → "10*25" → Calculadora: 250
krunnerrc calculatorEnabled=false  → calculator gone, only the web fallback
krunnerrc calculatorEnabled=true   → Calculadora: 250 again
```

The menu never keeps its own list of runners, so there is nothing that could
drift from the user's configuration.

### Stale keys in this user's krunnerrc

`webshortcutsEnabled=false` does nothing: the plugin id is
`krunner_webshortcuts`. Verified by setting `krunner_webshortcutsEnabled=false`,
which *did* remove the DuckDuckGo fallback. The same file carries both
`appstreamEnabled` and `krunner_appstreamEnabled`, i.e. Plasma 5 leftovers.

This is a user-config issue that affects the KRunner window identically, so it
is not a parity gap — but it is worth knowing when comparing the two by eye.
krunnerrc was restored byte-identical after these tests.

## Calculator

Works through `calculator.so`; nothing was written for it, and `eval()` is not
used anywhere in the project.

| Query | Result |
| --- | --- |
| `2+2` | 4 |
| `10*25` | 250 |
| `100/4` | 25 |
| `sqrt(144)` | 12 |
| `2^10` | 1024 |
| `(15+5)*3` | 60 |

Decimal separators follow the locale (pt_BR shows `62,1373`). The runner also
publishes a "copy result" action, which reaches the delegate through
`ActionListRole` like any other runner action.

## Unit conversion

Works through `unitconverter.so` — but its keywords are **translated**. From
`plasma_runner_converterrunner.mo` (pt_BR):

```
msgctxt "list of words that can used as amount of 'unit1' [in|to|as] 'unit2'"
msgid  "in;to;as"
msgstr "em;para;como"
```

So on this pt_BR system:

| Query | Result |
| --- | --- |
| `1 l em ml` | 1.000 mililitros (ml) |
| `2 litros em ml` | 2.000 mililitros (ml) |
| `5 m em cm` | 500 centímetros (cm) |
| `100 km em mi` | 62,1373 milhas (mi) (plus nmi, mm, mil) |
| `30 C em F` | 86 graus Fahrenheit (°F) |
| `1 GB em MB` | 1.000 megabytes (MB) |
| `10 kg em g` | 10.000 gramas (g) |
| `1 l in ml` | **no conversion** — only the web-search fallback |

The last row is correct behaviour, not a bug: `in` is the English keyword. The
KRunner window behaves identically. Adding a parallel converter to "fix" it
would duplicate KDE's work and break the moment the syntax changes.

## Ranking — kept as KRunner's, deliberately

For `2+2` the calculator's `4` appears *below* three weak application matches
(`GstarCAD 2026`, `IRPF 2026`, …, all matching the `2` in "2026"). That is
upstream behaviour:

```cpp
// runnermodel.cpp — applications are a favourite category by default
m_favoritePluginIds = krunnerrc.group("Plugins").group("Favorites")
        .readEntry("plugins", QStringList(QStringLiteral("krunner_services")));
```
```cpp
// resultsmodel.cpp SortProxyModel::lessThan — favourites beat relevance
if (favoriteA != favoriteB) return favoriteA > favoriteB;
```

Two reasons it was left alone:

1. It is what KRunner does. Re-ordering here would make the menu disagree with
   the rest of the desktop.
2. `RunnerMatchesModel::data()` exposes only Display, Decoration, `GroupRole`,
   `DescriptionRole`, `FavoriteIdRole`, `UrlRole`, `HasActionListRole`,
   `IsMultilineTextRole` and `ActionListRole`. **No relevance value reaches
   QML**, so any re-ordering we invented would be arbitrary — exactly what the
   brief forbids.

The user can change which category is favoured in KRunner's own settings, and
the menu will follow, because both read the same key.

What *was* improved is discoverability: results are grouped under their runner's
category heading ("Aplicativos", "Calculadora", "Conversor de unidades"), so an
answer that is not first is still immediately visible. The headings come from
the model's `group` role via `AccessibleListView`'s section delegate and needed
no new code.

## Result actions

Runner actions arrive through `ActionListRole` and are rendered by the existing
`AppDelegate`/`ActionMenu` path, unchanged. Enter launches the current item via
`Header.onAccepted` → `contentArea.currentItem.action.trigger()`.

## Known limitations

- Relevance scores are not available to QML, so the menu cannot show or sort by
  them. Reported upstream behaviour, not worked around.
- `mergeResults` gives one flat list; per-runner sub-models would be possible
  (`mergeResults: false`) but would lose KRunner's cross-category ordering, so
  it was not done.
- Runners that need a UI of their own (for example the window switcher's
  previews) render as plain rows here, as they do in any Kicker-based launcher.
