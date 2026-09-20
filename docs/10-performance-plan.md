# 10 — Plano de Performance

## Baseline capturado (Rodada 2, sessão ao vivo)

Medição qualitativa de recursos com o código novo já instalado e o plasmashell
recarregado (Plasma 6.7.4 / Wayland):

| Métrica | Valor observado |
|---|---|
| plasmashell RSS ocioso (todo o shell) | ~639–650 MB, **plano** (sem crescimento em ~50s) |
| plasmashell CPU% após settle | decai de ~9% → ~6% e estabiliza |
| Crash/segfault/coredump após deploy+restart | **nenhum** |
| Erros QML do appsmenu no journal | **nenhum** |
| `qmllint` (todo o projeto) | sem erros |

> RSS aqui é do processo inteiro do plasmashell (papel de parede, todos os
> widgets), não só do appsmenu. Serve como baseline de estabilidade/ausência de
> leak, não como medida isolada do plasmoid.

Ainda **falta** o baseline instrumentado de latência (abertura/first-paint/
busca) — exige `console.time` temporário em `Component.onCompleted`/`onActivated`
ou `gammaray`. Fica para a Rodada 3 (ver roadmap). Métodos:

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
