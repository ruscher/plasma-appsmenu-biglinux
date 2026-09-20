# 08 — Info / Arquitetura de Gadgets

> **Status (Rodada 4): IMPLEMENTADO.** O `InfoPage` monolítico foi substituído
> pelo framework abaixo. A seção "Estado atual do Info" a seguir descreve o
> estado *anterior* e é mantida como histórico.

## Arquitetura implementada (`contents/ui/gadgets/`)

| Arquivo | Papel |
|---|---|
| `GadgetRegistry.qml` (singleton) | Catálogo: id, nome, ícone, categoria, tamanhos suportados, tamanho padrão, `online`, `multiple`; layout padrão. |
| `GadgetGrid.qml` | Motor de grade: colunas 2/3/4, empacotamento first-fit preservando a ordem, drag & drop com reordenação ao vivo, `ListModel` das instâncias, serialização. |
| `GadgetHost.qml` | O cartão: moldura (`Kirigami.ShadowedRectangle`, tinta de acento, hover lift), barra de título (alça de arraste), badges de edição (remover / tamanho / configurar), wiggle no modo edição, `Loader` assíncrono com **isolamento de falha** (estado de erro + "Try again" só no cartão), e a **API do host** (`cfg`, `setCfg`, `saveCfg`, `cacheGet/Set`, `sharedCacheGet/Set`, `active`, `compact/wide/tall`, `setError`, `openSettings`). |
| `GadgetGallery.qml` | "Adicionar gadget": filtro por categoria, cartões com Add/Added, "Restaurar layout padrão" com confirmação. |
| `GadgetSettingsDialog.qml` | Hospeda o `settingsComponent` de cada gadget. |
| `GadgetTitleBar.qml`, `RingGauge.qml`, `Sparkline.qml`, `RoundedImage.qml` | Peças reutilizáveis (título, gauge em anel via `QtQuick.Shapes`, gráfico de histórico via Canvas, imagem arredondada via `MultiEffect`). |
| `lib/GadgetNet.js` | Rede compartilhada: GET com timeout, JSON/XML, erros uniformes, helpers de cache com timestamp. |
| `lib/WeatherOpenMeteo.js` · `lib/SportsTheSportsDB.js` · `lib/RssParser.js` | Providers desacoplados (a UI só conhece o formato normalizado). |
| `items/*Gadget.qml` | 22 gadgets (lista abaixo). |

**Persistência:** `Plasmoid.configuration.gadgetLayout` (JSON `{v, items:[{uid,id,size,cfg}]}`),
`gadgetColumns`, `gadgetCache` (JSON com timestamps) — gravação com debounce
(700 ms / 1,5 s). Sobrevive a fechar o menu, reiniciar o plasmashell e logout.

**Lifecycle/pausa:** `host.active` = página Info ativa ∧ menu expandido ∧ cartão
no viewport ∧ não arrastando. Todos os timers/rede usam `running: host.active`.
Menu fechado → nada roda.

**Drag & drop:** segurar (0,45 s) em qualquer lugar entra no modo edição;
arrastar pela barra de título (normal) ou pelo cartão inteiro (edição). O grid
move o item para a célula sob o ponteiro e re-empacota os demais com animação
(preview ao vivo); solta → persiste. Auto-scroll perto das bordas.

**Tamanhos:** `1x1`, `2x1`, `1x2`, `2x2` (por gadget); célula = largura da
coluna, altura 0,94× — escala com DPI/fonte via `Kirigami.Units`.

### Gadgets (22)
Clock (analógico/digital), Calendar, Countdown, Notes, Weather (Open-Meteo,
sem chave; localização por IP aproximada ou cidade), CPU Meter (todos os
núcleos, temp, freq — KSystemStats), Memory, Battery (powermanagement; lida
com desktop sem bateria), Drive Info (volumes via árvore de sensores), Drive
Monitor, Network, System Info, Media Player (MPRIS), Clipboard (Klipper, com
mascaramento), Quick Links (ícones grandes, editor com `IconDialog`), News Feed
(RSS/Atom com imagens, múltiplos feeds editáveis), Currency (Frankfurter/BCE),
Live Scores (TheSportsDB: ao vivo/próximos/resultados, ligas configuráveis),
Quote of the Day (local + opcional ZenQuotes), Tips, Gallery (pasta local,
crossfade + zoom), 2048.

### Decisões de fornecedor
- **ESPN** (`site.api.espn.com`) responde **403** desta rede para qualquer
  User-Agent → substituído por **TheSportsDB** v1 (chave pública `3`,
  documentada). Ids de liga verificados por chamada real.
- Todos os providers sem chave de API; nada de tokens no repositório.
- Dados sensíveis (clipboard, notas) nunca saem da máquina.

### Armadilhas encontradas (e corrigidas) que valem registro
- `property var data` num `Item` **sombreia a default property `data`** →
  os filhos declarados viram valor da variável e o gadget fica vazio (Weather,
  Currency, Sports). Renomeadas para `wx`/`fx`/`sb`.
- Delegate de `Repeater` precisa ser `Item` (sensores embrulhados).
- `relayout()` em `onWidthChanged` lia `cellWidth` ainda não reavaliado →
  calcular a partir de `width` e também reagir a `onCellWidthChanged`.
- Nós intermediários da `SensorTreeModel` não têm `SensorId` e o nível folha é
  lazy (`fetchMore`) → descobrir volumes/núcleos pelas folhas.
- `ksystemstats` não expõe o modelo da CPU (`cpu/cpu0/name` = "Núcleo 1") →
  leitura única de `/proc/cpuinfo`.

## Estado anterior do Info (histórico)

`InfoPage.qml` é um dashboard **monolítico**: um `Flickable` com blocos fixos
(Hardware CPU/RAM/SWAP/DISK, Notícias Phoronix, Data & Hora, Clima, Detalhes do
Sistema, Links Rápidos). Todos os dados vêm de `DataSource(engine:"executable")`
(shell): `free`, `df`, `uname`, `grep /proc/cpuinfo`, `cat /sys/class/dmi`,
`lspci`, `uptime`, `curl wttr.in`, `curl phoronix.com`.

### Problemas frente aos requisitos da missão
1. **Não é modular** — tudo num único QML; não há add/remover/mover/redimensionar.
2. **Shell em tudo** — a missão pede preferir APIs Qt/KDE e isolar processos.
3. **Sem isolamento de falha** — um bloco com erro degrada a página inteira; um
   `curl` que falha some com o dado, sem estado de erro por-gadget.
4. **Sem persistência de layout** — não há posições/tamanhos configuráveis.
5. **Sem lazy/pause** — os `DataSource` só param porque a página é destruída ao
   trocar de aba (efeito colateral, não design).

### Correções já feitas (estabilização)
- `Qt.createQmlObject` de DataSource por clique → removido (vazamento).
- `connectSource` fire-and-forget agora desconecta (`execSource.run`).
- `kickoff.action("configure")` (Plasma 5) → `Plasmoid.internalAction` guardado.

## Arquitetura de gadgets proposta (trabalho futuro)

> Este é o maior item da missão e **não** foi implementado nesta rodada. Fica
> aqui o desenho para execução incremental.

### Componentes
```
Gadgets/
├── GadgetManager.qml      (singleton: registro, criação, remoção, layout, lifecycle)
├── GadgetHost.qml         (moldura: título, engrenagem, estado de erro/loading,
│                           isolamento via Loader + try/catch de sinais)
├── GadgetGrid.qml         (grid dinâmico com drag/drop, colisão, preview, snap)
├── GadgetGallery.qml      ("Adicionar gadget")
├── base/GadgetBase.qml    (contrato: id,name,icon,supportedSizes,defaultSize,
│                           requiresNetwork,refreshInterval,category; pause quando
│                           invisível; setError()/retry())
├── local/  Clock, Calendar, Notes, CpuMeter, Battery, Clipboard, Countdown,
│           DriveInfo, DriveMonitor, MediaControls
└── online/ Weather, Currency, RSS, Sports, Quotes, Tips  (via providers)
```

### Tamanhos (célula-base ~ conceitual)
- Quadrado 1×1 (~250), Horizontal 2×1 (~500×250), Vertical 1×2 (~250×500).
- Usar `Kirigami.Units.gridUnit` como unidade real (DPI/escala/acessibilidade),
  não pixels fixos.

### Grid dinâmico + colisões
- Modelo de ocupação (matriz de células). Arrastar → preview do alvo →
  reorganizar os demais → soltar → persistir. Animações suaves, sem sobreposição.
- Alternativa por teclado (mover ↑↓←→ via menu/modo de edição) para acessibilidade.

### Persistência
- `Plasmoid.configuration` (KConfig) com um JSON de layout
  (id, posição, tamanho, visível, config do gadget). Sobrevive a fechar menu,
  reiniciar plasmashell e logout.

### Isolamento de falhas (requisito forte)
- Cada gadget dentro de um `Loader` próprio; erro no gadget → `GadgetHost` mostra
  "Não foi possível carregar · Tentar novamente", **sem** derrubar a página Info
  nem o menu.

### Lazy loading + pause
- Não carregar Weather/RSS/Sports/Currency se o Info nunca foi aberto.
- Gadget fora da viewport ou menu fechado → pausar/reduzir refresh.

### Fontes de dados sem shell (preferir)
- CPU/RAM/carga/temperatura: **KSystemStats** (`org.kde.ksysguard`/systemstats).
- Bateria/energia: **Solid** / `org.kde.plasma.workspace.dbus` / UPower via DBus.
- Media: **MPRIS** (`org.kde.plasma.mpris` / DBus `org.mpris.MediaPlayer2`).
- Discos/montagens: **Solid** / `KFilePlacesModel`.
- Clipboard: **Klipper** via DBus (`org.kde.klipper`).
- Relógio/calendário: Qt puro (`Date`, `Qt.formatDateTime`).
- Rede (Weather/RSS/Currency/Sports): `XMLHttpRequest`/`Qt.XMLHttpRequest` com
  timeout, cache e providers desacoplados (sem API keys no repo).

### Providers (online)
Interface desacoplada (`WeatherProvider`, `CurrencyProvider`, `RSSProvider`,
`SportsProvider`, `QuotesProvider`): a UI não conhece a API. Cache por tipo
(Weather 10-30min, Currency 30-60min, RSS configurável, Sports curto ao vivo,
Quotes horas). Rate limiting: menu fechado → parar; Info fechada → parar; gadget
invisível → reduzir; jogo ao vivo → mais rápido.

## Recomendação de execução
Fazer por etapas (roadmap `12`): primeiro `GadgetManager`+`GadgetHost`+grid+
persistência com **2 gadgets locais** (Clock, DriveInfo) migrando dados para
APIs sem shell; depois demais locais; por último os online com providers.
