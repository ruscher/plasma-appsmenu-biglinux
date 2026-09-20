# 08 — Info / Arquitetura de Gadgets

## Estado atual do Info

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
