# 06 — Apps (análise)

`AllAppsPage.qml`: sidebar de categorias (`components/AccessibleListView` sobre
`kickoff.rootModel`) + área de conteúdo (grid/lista).

## Pontos fortes
- Usa os **modelos do Kicker** (`RootModel`/`AppsModel`), que internamente usam
  `KService`/`KSycoca` — ou seja, respeita `NoDisplay`, `OnlyShowIn`,
  `Categories`, etc. **Não** faz `find /usr/share/applications` + parsing manual.
  Isso já atende à diretriz da missão de preferir APIs do KDE.
- Categorias vêm do `RootModel` (`flat: true`, `showSeparators: true`).
- Virtualização por `ListView`/`GridView` (delegate reuse) — bom para muitos apps.

## Dívida técnica (costura antigo/novo)
`AllAppsPage` ainda instancia a stack **antiga** do Kickoff: `ListOfGridsView`,
`SectionView`, que puxam `KickoffListView/GridView`, `KickoffListDelegate/
GridDelegate`, `AbstractKickoffItemDelegate`, `KickoffSingleton`, `ActionMenu`.
Isso mantém dois delegates e dois singletons vivos ao mesmo tempo.

**Meta (P4 em `04`)**: usar só `AccessibleGridView` + `delegates/AppDelegate`,
aposentando a stack antiga.

## Riscos (ver `02`)
- `AllAppsPage.qml:220-224` — deref pós-`pop()` sem guarda.
- `AllAppsPage.qml:256-270` + `Connections onCurrentIndexChanged` — múltiplos
  caminhos de `replace()` podem gerar replaces redundantes ao trocar config/índice.
- `AbstractKickoffItemDelegate` — deref de `model.*` sem guarda no reset.

## Busca
Ver `SearchResultsPage.qml` + `runnerModel` (KRunner). Debounce/ranking a revisar;
Enter-para-lançar hoje é no-op na página de busca por causa do contrato
inconsistente de `contentArea` (item 11 em `02`).
