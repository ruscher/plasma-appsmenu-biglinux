# 07 — Places (análise)

Hoje o "Places" é um `EmptyPage` **inline** dentro de `FullRepresentation.qml`
(componente `placesPageComponent`, ~l.99-160), com sidebar de 3 categorias:

| Categoria | Modelo | Origem |
|---|---|---|
| Computer | `kickoff.computerModel` | `Kicker.ComputerModel` |
| History | `kickoff.recentUsageModel` | `Kicker.RecentUsageModel` |
| Frequently Used | `kickoff.frequentUsageModel` | `Kicker.RecentUsageModel` (ordering=1) |

Detecta laptop (troca ícone para `computer-laptop` via `PowerDevil "Is Lid
Present"`).

## Observações
- Usa modelos do KDE (bom). **Não** usa `KFilePlacesModel`.
- O `PlacesPage.qml` antigo é **código morto** (foi substituído por este inline).

## Oportunidades (missão)
- **`KFilePlacesModel`** (KIO) para "Computer/Devices/Network/Remote" reflete
  automaticamente montagens, dispositivos removíveis e locais de rede, com
  eventos (sem polling). Seria a base correta para "Computer" e "Devices".
- Separar o Places inline num arquivo próprio (`PlacesPage` novo) melhora
  manutenção e lifecycle.
- Marcar itens que também são favoritos (⭐), timestamps legíveis no History.
- Evitar duplicação com a Home (Home = resumo; Places = detalhado).

Status: **análise**; implementação com KFilePlacesModel é trabalho futuro
(roadmap `12`).
