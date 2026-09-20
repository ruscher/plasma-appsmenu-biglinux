# Architecture

`org.biglinux.appsmenu` is a KDE Plasma 6 plasmoid implemented in Qt Quick/QML. `main.qml` owns the Kicker models and the Plasma instance state. `FullRepresentation.qml` provides the header, page stack, navigation sidebar, and first-run welcome overlay.

## Runtime flow

```text
main.qml
└── FullRepresentation.qml
    ├── Header.qml                 # search, avatar, power/session actions
    ├── VerticalStackView           # Home, Apps, Places, Info, Search
    ├── navigation sidebar
    └── components/OnboardingOverlay.qml
```

The pages use the following models from `main.qml`:

| Model | Used by |
| --- | --- |
| `RootModel` and its favorites model | Home, Apps, search, context actions |
| `RunnerModel` | Search results |
| `ComputerModel` | Places → Computer |
| `RecentUsageModel` for apps, documents, and folders | Home and Places |
| `RecentUsageModel` with popular ordering | Home and Places → Frequently Used |

The Apps page still uses the mature Kickoff grid-of-grids path for its all-apps view. Newer accessible views and delegates are used for the Home, category, list, favorites, and search paths. This split is intentional: the old view remains runtime code until an equivalent migration can be verified without changing app launch, drag-and-drop, or section navigation behavior.

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
