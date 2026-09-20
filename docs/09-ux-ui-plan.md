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

## Aplicado na Rodada 3 (verificado por screenshot)
- Sidebar de Apps: só categorias reais, inicia na primeira visível, **contagem
  de apps** por categoria (secundária, com `Accessible.name` incluindo o número).
- Estados vazios em grid/lista ("No applications here yet").
- Cabeçalhos de seção em tamanho normal (Places/busca).
- Info: cores via `Kirigami.Theme` (positive/highlight/neutral/negative);
  CPU com valor real; Data & Hora respeita a configuração.
- Home: sem ★ redundante dentro de Favoritos.
- Página de configuração funcional e organizada por seções
  (Aparência · Aplicativos · Home · Info).
- Enter na busca lança o 1º resultado.

## Pendências priorizadas
1. Revisar tab order Header → conteúdo → sidebar de abas.
2. Avaliar `showAllApplications=true` por padrão.
3. Substituir shell no Info por APIs (parte do framework de gadgets, doc 08).
