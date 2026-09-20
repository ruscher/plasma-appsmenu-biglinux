# 09 — Plano UX/UI

Princípios (da missão): rápido, coerente, simples, previsível, responsivo,
acessível. Efeitos visuais **nunca** acima de estabilidade.

## Decisões já aplicadas
- **Navegação previsível:** trocar de aba só por clique (hover não navega mais).
  Além de corrigir o crash, atende ao pedido de transições "claras e previsíveis".

## Diretrizes
- Cores/fontes via `Kirigami.Theme` e `Kirigami.Units` (evitar hardcode).
  - ⚠️ Hoje há cores hardcoded em `InfoPage` (ex.: `#43A047`, `#1E88E5`) e
    `Qt.rgba(1,1,1,...)` que não respeitam tema claro/escuro. Substituir por
    tokens do tema. (pendente)
- Ícones por nome do tema (`Kirigami.Icon`), `asynchronous: true` onde couber.
- Animações curtas respeitando `Kirigami.Units` (velocidade do Plasma); nunca
  bloquear interação nem consumir CPU constante.
- Empty states em todas as áreas (favoritos, recentes, busca sem resultado,
  Info sem gadget, offline).

## Acessibilidade
- Já há `Accessible.role`/`name`/`description` nas abas e no `AppDelegate`
  (role `MenuItem`). Manter em todo interativo.
- Navegação 100% por teclado (Tab/Shift+Tab, setas, Enter, Escape); foco visível.
- Alternativa de reordenação por teclado (modo edição) para drag-and-drop.
- Contraste WCAG AA; cor nunca como único indicador.

## Pendências priorizadas
1. Corrigir Enter-para-lançar na busca (contrato `contentArea`).
2. Trocar cores hardcoded do Info por `Kirigami.Theme`.
3. Revisar tab order Header → conteúdo → sidebar de abas.
