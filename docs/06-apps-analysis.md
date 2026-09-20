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
Ver `SearchResultsPage.qml` + `runnerModel` (KRunner). Debounce/ranking a revisar.
Enter-para-lançar corrigido na R3 (`currentItem` exposto).

## Varredura "apps não aparecem" (R3)
- Causa real: o delegate novo sombreava `model`/`index` → tudo em branco
  (doc 02, item 12). Corrigido; verificado por screenshot em todas as categorias.
- Cobertura: contagens da sidebar (165) = `kbuildsycoca6 --menutest` (165). Não
  há apps do menu KDE fora das categorias nesta máquina. Apps com
  `NoDisplay=true`/`Hidden=true` (236 dos 390 `.desktop`) são ocultos por
  especificação FreeDesktop — correto.
- "All Applications" continua opcional (`showAllApplications`, agora exposto e
  funcional na configuração). Recomendação de UX: considerar ligar por padrão,
  pois é a forma canônica de achar um app cuja categoria o usuário desconhece.
- Duplicatas legítimas (dois `.desktop` para o mesmo app, ex.: pacote +
  AppImage) aparecem duas vezes, como no Kickoff. Deduplicar por `Exec`/nome
  seria heurística arriscada; não aplicado.
