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

## Próximos (ordenados)

### P1 — Superfícies de exceção restantes
1. **`AllAppsPage.qml:220-224`** — após `contentStack.pop()`, guardar
   `currentItem` e a existência de `.view` antes de chamar
   `positionViewAtIndex`/`currentIndex`.
2. **`SearchResultsPage.qml:69-93`** — null-check consistente de `root.parent`
   nos `Connections`/`HoverHandler` (o segundo já guarda; o primeiro não).
3. **`AbstractKickoffItemDelegate.qml:97,100`** (legado vivo) — guardar
   `model.disabled`/`model.name` como no `AppDelegate`. Alternativa preferível:
   parar de usar a stack antiga (ver P4).
4. **`SectionView.qml:74`** — o loop em `Component.onCompleted` sobre
   `model.count`/`model.data(...)` roda cedo demais; validar `model` e adiar se
   necessário.

### P2 — Consistência funcional
5. **`kickoff.contentArea`** — padronizar o que cada página expõe para que
   `Header.qml` (Enter lança 1º resultado) funcione em Home e Search. Definir um
   contrato: `contentArea` sempre tem `currentItem` + `view`, ou o Header passa a
   consultar um método da página (`activateCurrent()`).

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
