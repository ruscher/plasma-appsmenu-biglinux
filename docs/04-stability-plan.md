# 04 — Plano de Estabilização

Objetivo: eliminar crashes, exceções silenciosas, vazamentos e race conditions.
Ordem = risco. Itens marcados ✅ foram feitos nesta rodada.

## Feito nesta rodada

- ✅ **Crash do StackView (causa raiz).** Removida a navegação por hover;
  `replace()` nunca ocorre durante transição (`pendingTabIndex`/`pendingSearch`
  aplicados em `onBusyChanged`). — `FullRepresentation.qml`. Detalhe em `03`.
- ✅ **Delegate vivo com `model.disabled` sem guarda.** — `delegates/AppDelegate.qml:102`.
- ✅ **API Plasma 5 `kickoff.action("configure")`.** → `Plasmoid.internalAction`
  guardado. — `InfoPage.qml`.
- ✅ **Vazamento de `DataSource` por clique** e **`connectSource` sem
  desconectar.** — `InfoPage.qml` (`execSource.run()` + `onNewData: disconnect`).

## Feito na Rodada 2

- ✅ **Segunda instância do crash hover→replace** — no `contentStack` interno do
  `AllAppsPage` (hover em categoria muda `sideBar.currentIndex` → `replace()`).
  Centralizado em `contentStack.switchView()` (ignora troca redundante, adia em
  `busy`, aplica pendente em `onBusyChanged`).
- ✅ **`AllAppsPage.qml` pós-`pop()`** — `onHideSectionViewRequested` agora guarda
  `currentItem`/`.view` antes de desreferenciar.
- ✅ **`SearchResultsPage.qml:84`** — deref de `root.parent.blockingHoverFocus`
  agora guardado no corpo do handler.
- ✅ **`AbstractKickoffItemDelegate.qml:97,100`** — `model.disabled`/`model.name`
  guardados como no `AppDelegate`.
- ✅ **`SectionView.qml`** — `Component.onCompleted` retorna cedo se `model` nulo.

## Próximos (ordenados)

### P2 — Consistência funcional
5. ✅ **`kickoff.contentArea`** (R3) — `SearchResultsPage` expõe `currentItem`;
   Enter lança o 1º resultado. Home/Info seguem sem `currentItem` (Enter é no-op
   ali, por design).

### P3 — Polling / recursos
6. Pausar/retomar os `DataSource` do `InfoPage` conforme visibilidade
   (`Plasmoid.expanded` && aba Info ativa). Reduz processos externos quando
   ocioso.
7. Consolidar os singletons duplicados (`KickoffSingleton`↔`MenuSingleton`,
   `ActionMenu`↔`ActionMenuSingleton`) para não instanciar DataSource/FrameSvg em
   dobro.

### P4 — Reduzir a costura antigo/novo
8. Migrar `AllAppsPage` para usar exclusivamente `components/AccessibleGridView`
   + `delegates/AppDelegate`, aposentando `ListOfGridsView`, `SectionView`,
   `KickoffListView/GridView`, delegates antigos e `KickoffSingleton`/`ActionMenu`.
9. Remover código morto (lista em `02-code-audit.md`) em commit isolado.

## Critérios de aceite de estabilidade

- Varrer o mouse pela sidebar e alternar abas rapidamente por vários minutos sem
  crash do `plasmashell` (o padrão que derrubava antes).
- Abrir/fechar o menu ~100×, alternar Home↔Apps↔Places↔Info ~100× sem crescimento
  contínuo de RAM nem processos órfãos.
- Sem `TypeError`/`ReferenceError` no `journalctl -f | grep appsmenu` durante uso
  normal (busca, favoritos, abrir app, gadgets do Info).
