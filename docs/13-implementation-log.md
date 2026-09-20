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

## 2026-09-19 — Rodada 3 (varredura visual: "muitos apps não aparecem")

### Como foi verificado "com os próprios olhos"
- Menu aberto via DBus (`kglobalaccel invokeShortcut "activate application
  launcher"`) e capturado com `spectacle -b -n -f` → recorte com `magick`.
- Para ver cada aba sem input sintético (Wayland), a **cópia instalada** recebeu
  um tweak temporário (`navBar.currentIndex = N` ao abrir; busca pré-preenchida
  com "term") — nunca o repo. Restaurada ao final com `rsync --delete`.
- Referência do que *deveria* aparecer: `kbuildsycoca6 --menutest` → 165
  entradas / 147 apps únicos em 11 categorias.

### Diagnóstico
A aba Apps estava **vazia**: só o retângulo de highlight, nenhum ícone/rótulo.
Causa: `AppDelegate.qml` sombreava `model`/`index` (ver doc 02, item 12). Afetava
Apps (grid), categorias, e a lista de resultados da busca.

### Alterações de código
- `delegates/AppDelegate.qml`: `required property var model` / `required
  property int index`; `url`/`decoration`/`description` derivados de `model`.
- `AllAppsPage.qml`: sidebar só com categorias reais (`modelForRow(i) !== null`),
  inicia na primeira visível (sem flash favoritos→categoria), badge de contagem,
  `initialItem` coerente com a linha inicial.
- `SearchResultsPage.qml`: alias `currentItem` (Enter lança o 1º resultado);
  `emptyText: ""` (já tem placeholder próprio).
- `components/AccessibleGridView.qml` / `AccessibleListView.qml`: estado vazio
  (`PlaceholderMessage`) configurável por `emptyText`.
- `ConfigGeneral.qml`: reescrita funcional (`KCM.SimpleKCM` + `cfg_*`).
- `singletons/MenuSingleton.qml`: `compactListDelegateContentHeight` sem padding.
- `InfoPage.qml`: cores do tema no lugar de hex; CPU com carga real
  (`/proc/loadavg` + `nproc`, 5 s); cartão Data & Hora respeita `infoShowCalendar`.
- `HomePage.qml`: removido o badge ★ redundante dentro da seção Favoritos.

### Resultado (screenshots em scratchpad, todas as abas)
- Apps: categorias com contagem (15/1/11/13/21/20/15/25/32/9/3 = 165 ✓), grid
  renderiza todos os apps; busca "term" lista resultados com ícone+descrição;
  Places com cabeçalhos normais; Info com CPU 8%/load; Home sem estrelas
  redundantes. **0 warnings QML** em todas as abas; plasmashell vivo.
- "webOS Dev Manager" aparece 2× porque existem 2 `.desktop` reais (pacote do
  sistema + AppImage) — comportamento correto do menu KDE.

### Descoberta importante: warnings QML estavam silenciados no sistema
`/etc/environment` define `QT_LOGGING_RULES='*=false'` → o plasmashell não
registrava **nenhum** warning QML. Todas as checagens "0 warnings" anteriores
(Rodadas 1–2 e início da 3) eram cegas. Reabilitando só no serviço
(`systemctl --user set-environment ...`, ver doc 11) apareceram warnings reais,
todos corrigidos:
- `AppDelegate`: binding loop em `dragIconItem` (bound aos próprios aliases) e
  em `icon.height: icon.width` (o grupo `icon` re-emite a cada escrita);
  `hasActionList`/`isFavorite` retornavam `undefined` para modelos sem
  `favoriteId` (e `hasActionList` virava true sem `actionList`).
- `AccessibleListView/GridView`: highlight `pressed`/`active` com `undefined`
  (delegate da sidebar não tem `isPressed`; `searchField` nulo no início).
- `HomePage`: `itemIcon: string` recebendo `QIcon`; emissão manual inválida de
  `hoveredChanged(bool)`.
Resultado final: **0 warnings** em Home/Apps/Places/Info/Busca com logging
ligado; ambiente restaurado para `*=false` ao final.

### Commits
- `94ccdc1` fix: render apps again — delegate shadowed injected model; make
  config page save (push em `origin/feature/rafael-personal-menu`).
