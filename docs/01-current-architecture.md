# 01 — Arquitetura Atual

## Fluxo de entrada

```
main.qml (PlasmoidItem "kickoff")
├── compactRepresentation: MouseArea inline (ícone + label + drag-to-open)
└── fullRepresentation: FullRepresentation.qml
        ├── Header.qml            (busca, avatar, power)
        ├── VerticalStackView     (área central — troca páginas via replace())
        │     ├── HomePage.qml         (initialItem)
        │     ├── AllAppsPage.qml
        │     ├── placesPage           (EmptyPage inline dentro de FullRepresentation)
        │     ├── InfoPage.qml
        │     └── SearchResultsPage.qml (quando há texto de busca)
        └── navSideBar            (4 abas: Home/Apps/Places/Info → switchToTab)
```

`main.qml` cria **todos os modelos** e os expõe no root `kickoff`; as páginas os
consomem por referência.

## Modelos (todos em `main.qml`)

| Propriedade | Tipo Kicker | Uso |
|---|---|---|
| `rootModel` | `RootModel` (`autoPopulate:false`, `flat:true`) | apps + `favoritesModel` |
| `runnerModel` | `RunnerModel` | busca (KRunner) |
| `computerModel` | `ComputerModel` | aba Places → "Computer" |
| `recentUsageModel` | `RecentUsageModel` (apps) | recentes |
| `frequentUsageModel` | `RecentUsageModel` (ordering=1) | frequentes |
| `recentDocsModel` | `RecentUsageModel` (docs) | arquivos recentes |
| `recentFoldersModel` | `RecentUsageModel` (folders) | pastas recentes |
| `ProcessRunner` | — | "Edit Applications…" |
| `SystemModel` (em `PowerMenu.qml`) | — | ações de sessão/power |

Observações:
- `rootModel.refresh()` é chamado em `FullRepresentation.Component.onCompleted`.
- `favoritesModel.initForClient("...kickoff.favorites.instance-<id>")` em
  `main.qml`, com porte único de favoritos legados para KActivitiesStats.
- **Não** usa `KFilePlacesModel`; "Places" é montado a partir de
  `ComputerModel` + `RecentUsageModel` (oportunidade futura — ver `07`).

## Navegação entre páginas

- `navBar.currentIndex` (0..3) → `onCurrentIndexChanged` → `switchToTab()` →
  `contentItemStackView.replace(component)`.
- Busca: `Header` emite `searchTextChanged`; `Connections` troca para
  `SearchResultsPage` quando há texto e volta para a aba atual quando vazio.
- Reset para Home em `kickoff.onExpandedChanged` (ao abrir o menu).

> A troca por **hover** foi removida (era a causa raiz do crash — ver `03`).
> Agora todas as trocas de `replace()` são protegidas contra reentrância durante
> a transição (`pendingTabIndex` / `pendingSearch` aplicados em `onBusyChanged`).

## Camadas de componentes

- **Novos (ativos):** `components/AccessibleListView`, `AccessibleGridView`,
  `DragDropArea`, `PowerMenu`; `delegates/AppDelegate`; `singletons/MenuSingleton`,
  `ActionMenuSingleton`.
- **Antigos ainda vivos (via `AllAppsPage`):** `ListOfGridsView`,
  `ListOfGridsViewDelegate`, `SectionView`, `KickoffListView`, `KickoffGridView`,
  `KickoffListDelegate`, `KickoffGridDelegate`, `AbstractKickoffItemDelegate`,
  `ActionMenu`, `KickoffSingleton`.
- **Base comum:** `EmptyPage` (base de páginas e views), `VerticalStackView`.

## Singletons duplicados (dívida técnica)

| Antigo (vivo via stack Kickoff) | Novo (vivo via arquitetura nova) |
|---|---|
| `KickoffSingleton` (métricas via delegates ocultos) | `singletons/MenuSingleton` (métricas aritméticas) |
| `ActionMenu` (menu de contexto) | `singletons/ActionMenuSingleton` |

Ambos instanciam `DataSource(powermanagement)`, `FrameSvgItem`, etc. Consolidar
para um só reduz recursos e superfície de bugs (ver `12-implementation-roadmap.md`).

## APIs / imports

- Estilo Plasma 6 correto: root `PlasmoidItem`, atributo `Plasmoid`,
  `org.kde.plasma.plasma5support` para `DataSource`.
- `org.kde.plasma.core` é importado só para `PlasmaCore.Types`/`PlasmaCore.Action`
  (válido no Plasma 6 — não é o `DataSource` depreciado).
- **Exceção corrigida:** `InfoPage` usava `kickoff.action("configure")` (API do
  Plasma 5) — trocado por `Plasmoid.internalAction("configure")` guardado.
