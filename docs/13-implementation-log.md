# 13 — Log de Implementação

## 2026-09-19 — Rodada 1

### Git
- Branch `feature/rafael-personal-menu` criada a partir de `main` (commit
  `5f34ab2`). `main` intacta. Working tree pré-existente **preservado** (refactor
  em andamento + PLANNING.md + backups não commitados).

### Investigação
- Detectado ambiente: Plasma 6.7.4 / Qt 6.11.2 / KF6 / Wayland.
- `coredumpctl`/journal: SIGSEGV do `plasmashell` em `libQt6Quick.so`
  (`segfault at 18b`), coredump não persistido (`Storage: none`).
- Mapa completo do codebase (agente Explore): arquitetura nova ativa; costura com
  stack antiga do Kickoff; código morto; singletons duplicados.

### Alterações de código
`contents/ui/FullRepresentation.qml`
- Removida navegação por hover nas 4 abas (`onHoveredChanged` deletado).
- Adicionadas `pendingTabIndex`/`pendingSearch`; `switchToTab()` e o caminho de
  busca não chamam `replace()` durante `busy`; `onBusyChanged` aplica o pendente.

`contents/ui/delegates/AppDelegate.qml`
- `enabled: !isSeparator && !(model && model.disabled === true)` (guarda de null).

`contents/ui/InfoPage.qml`
- `execSource` agora tem `run(cmd)` + `onNewData: disconnectSource` (sem acúmulo).
- Copiar data reutiliza `execSource` (removido `Qt.createQmlObject` que vazava).
- `ConfigGear` usa `Plasmoid.internalAction("configure")` guardado (era
  `kickoff.action(...)`, API Plasma 5).

### Validação
- `qmllint --bare` em todos os `.qml`: sem erros de sintaxe.
- `plasmoidviewer -a`: carrega sem erros de QML; permanece vivo (sem crash na
  inicialização).
- ⚠️ Não executado: teste de stress na sessão real (evitei reiniciar o
  `plasmashell` do usuário sem confirmação). Checklist em `11`.

### Docs
- Criados `docs/00`–`docs/14`.
