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

### Deploy + validação ao vivo (autorizada pelo usuário)
- Sincronizado repo → `~/.local/.../org.biglinux.appsmenu` (rsync, com backup).
- `plasmashell` reiniciado via `systemctl --user restart plasma-plasmashell`
  (o `kstart6` avulso não subiu; a via correta no Plasma 6 é o serviço systemd).
- Estável: mesmo PID por >50s, RSS plano (~650 MB), CPU assentando, **0** crash,
  **0** coredump, **0** erro QML no journal.
- Nota: a "tempestade de hover" interativa não é automatizável de forma confiável
  no Wayland (só `xdotool`/X11 disponível). O gatilho, porém, foi removido da
  fonte. Teste interativo final fica para o usuário (checklist doc 11).
- Push: `git push -u origin feature/rafael-personal-menu` (só a branch; main intacta).

## 2026-09-19 — Rodada 2 (estabilização P1 + baseline)

### Alterações de código
`AllAppsPage.qml`
- Novo helper `contentStack.switchView(component, objectName)`: ignora troca
  redundante, adia `replace()` durante `busy`, aplica pendente em `onBusyChanged`.
  Corrige a **segunda instância** do crash hover→replace (sidebar de categorias).
- `onPreferred*Changed` e `Connections onCurrentIndexChanged` usam `switchView`.
- `onHideSectionViewRequested`: guarda `currentItem`/`.view` pós-`pop()`.

`SearchResultsPage.qml`
- Guarda de `root.parent` no corpo do handler (l.84).

`AbstractKickoffItemDelegate.qml` (legado vivo)
- `enabled`/`text` guardam `model` nulo.

`SectionView.qml`
- `Component.onCompleted` retorna cedo se `model` nulo.

### Validação
- `qmllint`: OK em todos os alterados.
- Deploy + restart do plasmashell: estável, sem crash/erro/coredump (baseline no
  doc 10).
