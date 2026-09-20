# 02 — Auditoria de Código

Baseado no mapeamento completo do `contents/ui/`. Locais com `arquivo:linha`.

## Classificação dos arquivos

### Ativos — arquitetura nova
`main.qml`, `FullRepresentation.qml`, `Header.qml`, `HomePage.qml`,
`AllAppsPage.qml`, `InfoPage.qml`, `SearchResultsPage.qml`, `EmptyPage.qml`,
`VerticalStackView.qml`, `components/AccessibleListView.qml`,
`components/AccessibleGridView.qml`, `components/DragDropArea.qml`,
`components/PowerMenu.qml`, `delegates/AppDelegate.qml`,
`singletons/MenuSingleton.qml`, `singletons/ActionMenuSingleton.qml`,
`code/tools.js`.

### Antigos ainda vivos (puxados por `AllAppsPage`)
`ListOfGridsView.qml`, `ListOfGridsViewDelegate.qml`, `SectionView.qml`,
`KickoffListView.qml`, `KickoffGridView.qml`, `KickoffListDelegate.qml`,
`KickoffGridDelegate.qml`, `AbstractKickoffItemDelegate.qml`, `ActionMenu.qml`,
`KickoffSingleton.qml`.

### Código morto (não referenciado por nada vivo)
`NormalPage.qml`, `ApplicationsPage.qml`, `PlacesPage.qml`, `BasePage.qml`,
`Footer.qml`, `LeaveButtons.qml`, `HorizontalStackView.qml`,
`KickoffDropArea.qml`, `DropAreaGridView.qml`, `DropAreaListView.qml`,
`components/SmartSection.qml`, `components/SectionCard.qml`,
`components/SectionCollapser.qml`, `components/OnboardingOverlay.qml`,
`components/FavoriteIndicator.qml`, `components/AnimatedStackView.qml`,
`delegates/SectionHeaderDelegate.qml`.

> Recomendação: remover código morto **em um commit próprio** depois da
> estabilização, para não misturar com correções (facilita revisão/rollback).
> `BasePage.qml` (morto) ainda referencia `kickoff.footer.tabBar`,
> `kickoff.header.configureButton` etc. que não existem mais — inofensivo
> enquanto morto, mas confirma que é legado.

## Achados por severidade

### 🔴 Crash / erro em runtime
1. **hover → `replace()` reentrante** — `FullRepresentation.qml` (abas).
   Causa raiz do SIGSEGV. **CORRIGIDO** (ver `03`).
2. **`model.disabled` sem guarda** — `delegates/AppDelegate.qml:102`.
   `model` pode ser null em reset/reuse → exceção no delegate vivo.
   **CORRIGIDO** (`!(model && model.disabled === true)`).
3. **`kickoff.action("configure")`** — `InfoPage.qml` (API Plasma 5).
   `TypeError` a cada clique na engrenagem. **CORRIGIDO** →
   `Plasmoid.internalAction("configure")` guardado.
4. **`AbstractKickoffItemDelegate.qml`** (antigo, vivo) — `model.disabled`
   (l.97), `model.name` (l.100) desreferenciados direto; superfície clássica de
   crash do Kickoff em reset. **PENDENTE** (arquivo legado; ver `04`).
5. **pós-`pop()` sem guarda** — `AllAppsPage.qml:220-224`
   (`contentStack.pop()` seguido de `contentStack.currentItem.view...`).
   **PENDENTE**.
6. **`root.parent` em transição** — `SearchResultsPage.qml:69-93`
   (`Connections`/`HoverHandler` sobre `root.parent`, que pode ser null durante
   `replace`). **PENDENTE**.

### 🟠 Vazamento / desperdício
7. **`Qt.createQmlObject` de `DataSource` por clique** — `InfoPage.qml` (copiar
   data). Objeto nunca destruído. **CORRIGIDO** (reutiliza `execSource.run()`).
8. **`connectSource` sem `disconnectSource`** — `InfoPage.qml` (fire-and-forget).
   **CORRIGIDO** (`execSource` desconecta em `onNewData`).
9. **Singletons duplicados** — `KickoffSingleton`+`MenuSingleton` e
   `ActionMenu`+`ActionMenuSingleton` ativos ao mesmo tempo (dobram DataSource/
   FrameSvgItem). **PENDENTE** (consolidar — ver `12`).

### 🟡 Processos externos (shell) — contra as diretrizes da missão
10. **`InfoPage.qml`** usa `DataSource(engine:"executable")` para tudo:
    `hostname`, `uname`, `$SHELL --version`, `grep /proc/cpuinfo`,
    `cat /sys/class/dmi`, `free -b`, `df`, `lspci`, `uptime`, `curl wttr.in`,
    `curl phoronix.com | grep -oP`. A missão pede preferir APIs Qt/KDE e
    isolar/modularizar gadgets. **PENDENTE** (grande refactor — Info/Gadgets,
    ver `08`).

### 🔵 Bug funcional (não-crash)
11. **`contentArea` com formatos inconsistentes** — HomePage/InfoPage/Search
    setam `kickoff.contentArea = root` (a página), enquanto AllAppsPage seta uma
    *view*. `Header.qml:100-107` espera `contentArea.currentItem`/`.view`. Efeito:
    Enter na busca não lança o primeiro resultado (no-op silencioso). **PENDENTE**.

## Timers / polling
- Nenhum `Timer { repeat: true }` perigoso: os `Timer`s são one-shot (debounce de
  teclado/scroll em `AccessibleListView/GridView`, `KickoffListView`, e
  `expandOnDragTimer` em `main.qml`).
- Polling real vem dos `interval` dos `DataSource` do `InfoPage` (mem 3s, disk
  30s, uptime 60s, weather 30min, rss 1h). Como o `InfoPage` é destruído ao
  trocar de aba e o `currentIndex` é resetado para Home ao abrir, o polling só
  ocorre enquanto o Info está aberto. Melhoria futura: pausar quando invisível.

## Segurança
- `execSource.run(btnCmd)` roda comandos **fixos** (systemsettings, dolphin…);
  sem injeção de entrada não confiável.
- A cópia de data usa `printf '%s' '<data formatada>'` — data controlada, sem
  concatenação de entrada do usuário. OK.
- `curl` para `wttr.in`/`phoronix` envia requisição de rede sem enviar dados
  sensíveis; mas sem timeout explícito nem isolamento de erro (ver `08`).
