# 05 — Home (análise)

`HomePage.qml` é a página inicial. Consome, vindos de `main.qml`:
`favoritesModel`, `recentUsageModel` (apps), `recentDocsModel` (arquivos),
`recentFoldersModel` (pastas), `frequentUsageModel`.

## Estado atual
- Favoritos em `Flow`/grid a partir de `rootModel.favoritesModel` (modelo real
  do Plasma com suporte a Activities — bom).
- Seções de recentes (apps/arquivos/pastas) via `RecentUsageModel` do Kicker —
  usa a API do KDE (KActivitiesStats), **não** escaneia o filesystem. Correto.
- Delegates de Repeater leem `model.url/decoration/display/index` diretamente
  (dependem da validade do modelo durante rebuild).

## O que a missão pede vs. o que existe
| Requisito | Situação |
|---|---|
| Adicionar/remover/reordenar favoritos | Reorder via `components/DragDropArea`; add/remove via menu de contexto (`ActionMenuSingleton` + `tools.js`). OK. |
| Recentes = usados recentemente (não instalados) | OK — `RecentUsageModel`. |
| Arquivos recentes: abrir / abrir com / mostrar na pasta / remover | Abrir existe; ações "abrir com"/"mostrar na pasta"/"remover da lista" a validar. |
| Pastas recentes | OK via `recentFoldersModel`. |
| Evitar varrer filesystem | OK. |

## Pendências
- Confirmar ações de contexto completas para arquivos/pastas recentes.
- Garantir empty states ("Nenhum favorito ainda", etc.).
- Guardas de `model` nos delegates de Repeater durante rebuild.
