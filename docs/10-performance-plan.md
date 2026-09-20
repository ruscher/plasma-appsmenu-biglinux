# 10 — Plano de Performance

## Como medir (baseline honesto)
Ainda **não** há baseline numérico capturado nesta rodada (foco foi corrigir o
crash). Métodos recomendados nesta máquina:

- **Tempo de abertura/primeiro paint:** `console.time`/`Date.now()` em
  `FullRepresentation.Component.onCompleted` e no `onActivated` de cada página.
- **RAM/CPU:** `ps -o rss,pcpu -p $(pgrep -x plasmashell)` antes/depois; comparar
  ocioso vs. Info aberto.
- **Objetos QML / leaks:** `QSG_RENDER_TIMING=1`, `QML_DISABLE_DISK_CACHE=0`; para
  contagem de itens, `gammaray` se disponível.
- **FPS de scroll:** overlay do Qt (`QSG_RENDER_TIMING`) ou observação.

## Pontos de atenção identificados (estáticos)
- **Dois singletons + DataSources em dobro** (Kickoff vs. novo) — desperdício de
  memória/CPU constante enquanto ambos vivem. Consolidar (P3/P4 em `04`).
- **`InfoPage` polling por shell** — cada `interval` gera um processo externo
  (fork/exec) periódico. Preferir APIs sem shell (ver `08`) e pausar quando
  invisível.
- **`AppDelegate` scale Behavior + hover forceActiveFocus** — ok, leve.
- **`rootModel.refresh()` no onCompleted** — recarrega apps a cada criação do
  fullRepresentation; se o popup é recriado a cada abertura, é custo repetido.
  Avaliar manter o modelo vivo.
- **Repeater com model = array JS** (`InfoPage` RSS) — recria delegates a cada
  refresh. Migrar para modelo real reduz churn.

## Metas (da missão, a validar depois)
Abertura < 150ms; busca < 100ms; scroll ≥ 55fps; RAM ociosa razoável e estável.

> Regra: medir antes/depois de cada otimização e registrar aqui. "Parece rápido"
> não conta.
