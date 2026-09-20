# PLANNING.md — BigLinux New Start Menu (Reconstrução Total)

> **Meta**: Criar o melhor menu iniciar para desktop Linux do mundo — pronto para competições internacionais de usabilidade, design e acessibilidade.

---

## Índice

1. [Visão do Produto](#1-visão-do-produto)
2. [Análise da Arquitetura Legada](#2-análise-da-arquitetura-legada)
3. [Princípios de Design](#3-princípios-de-design)
4. [Arquitetura do Novo Menu](#4-arquitetura-do-novo-menu)
5. [Roadmap de Implementação — Fases](#5-roadmap-de-implementação--fases)
6. [Fase 1 — Fundação e Infraestrutura](#6-fase-1--fundação-e-infraestrutura)
7. [Fase 2 — UI Core: Header, Footer, Sidebar](#7-fase-2--ui-core-header-footer-sidebar)
8. [Fase 3 — Páginas de Conteúdo](#8-fase-3--páginas-de-conteúdo)
9. [Fase 4 — Sistema de Busca Avançado](#9-fase-4--sistema-de-busca-avançado)
10. [Fase 5 — Drag & Drop, Favoritos e Personalização](#10-fase-5--drag--drop-favoritos-e-personalização)
11. [Fase 6 — Acessibilidade Total (Orca / ATK)](#11-fase-6--acessibilidade-total-orca--atk)
12. [Fase 7 — Inteligência e Contexto](#12-fase-7--inteligência-e-contexto)
13. [Fase 8 — Configuração e First-Run Experience](#13-fase-8--configuração-e-first-run-experience)
14. [Fase 9 — Performance e Polish](#14-fase-9--performance-e-polish)
15. [Fase 10 — Testes e Validação](#15-fase-10--testes-e-validação)
16. [Especificação de Acessibilidade Completa](#16-especificação-de-acessibilidade-completa)
17. [Especificação de UX / Psicologia Humana](#17-especificação-de-ux--psicologia-humana)
18. [Mapa de Arquivos (Novo vs. Legado)](#18-mapa-de-arquivos-novo-vs-legado)

---

## 1. Visão do Produto

### O que é
Um menu iniciar para KDE Plasma 6 (BigLinux) que define um novo padrão mundial para:
- **Acessibilidade**: 100% navegável por Orca Screen Reader e teclado
- **Usabilidade**: Acesso a qualquer app em ≤ 3 interações (clique/tecla)
- **Personalização**: O usuário controla tudo — sem itens impostos
- **Design**: Visual limpo, hierarquia clara, WCAG AA mínimo
- **Performance**: Abertura < 150ms, busca < 100ms, scroll 60fps

### Audiência
- Usuários iniciantes migrando de Windows/macOS
- Usuários avançados/power users que vivem do teclado
- Usuários com deficiência visual usando Orca
- Usuários de tablets/touch screens

### Diferenciadores únicos
1. **Smart Sections**: Seção inteligente que sugere apps por hora/dia/contexto
2. **Busca Universal**: Apps + configurações + arquivos + cálculos + comandos
3. **Zero Duplicatas**: Item nunca aparece repetido — marcação visual se está presente em favoritos
4. **Onboarding Integrado**: Primeira abertura guia o usuário sem bloquear
5. **Acessibilidade Perfeita**: Cada widget anunciável pelo Orca, foco lógico, contraste WCAG AAA

---

## 2. Análise da Arquitetura Legada

### Pontos fortes a preservar (conceitos, não código)
| Conceito | Arquivo legado | Valor |
|---|---|---|
| Modelo de favoritos com suporte a Activities | `main.qml` (`RootModel.favoritesModel`) | Favoritos por atividade KDE |
| Busca via RunnerModel | `main.qml` (`RunnerModel`) | Integração com todos os Runners do KDE |
| Grid + List como opção de exibição | `ApplicationsPage.qml` | Flexibilidade visual |
| Drag & drop para reordenar favoritos | `KickoffDropArea.qml` | Personalização direta |
| Menu de contexto com ações de favoritos | `ActionMenu.qml` + `tools.js` | Gerenciamento intuitivo |
| Dual-pane com sidebar + conteúdo | `BasePage.qml` | Navegação por categorias |
| Stack views animados | `HorizontalStackView.qml`, `VerticalStackView.qml` | Transições suaves |
| Singleton para métricas | `KickoffSingleton.qml` | Performance e consistência |

### Problemas críticos a eliminar
| Problema | Arquivo legado | Impacto |
|---|---|---|
| Busca desaparece ao hover no avatar | `Header.qml` L102-104 | UX quebrado |
| Footer (TabBar + LeaveButtons) invisível (`visible: false`) | `Footer.qml` L16 | Funcionalidade oculta e inacessível |
| PlacesPage (Recentes, Frequentes, Computador) inacessível | `NormalPage.qml` + `Footer.qml` | Conteúdo valioso escondido |
| Nenhum `Accessible.name` em widgets interativos | Todos os delegates, botões | Orca não consegue anunciar |
| `Accessible.role: Accessible.Cell` num grid delegate | `KickoffGridDelegate.qml` | Role incorreto — deve ser `Accessible.Button` ou `Accessible.MenuItem` |
| Foco vai para footer invisível na navegação Tab | `BasePage.qml` | Foco "desaparece" |
| Arquivo `ConfigManager.qml` vazio | `ConfigManager.qml` | Dead code |
| Itens duplicados entre categorias e favoritos | Modelos Kicker | Confusão do usuário |
| Ícones sem fallback acessível | `KickoffGridDelegate.qml` | Ícone quebrado = sem info |
| Mouse-only para drag-and-drop | `AbstractKickoffItemDelegate.qml` L151 | Usuários de teclado/touch excluídos |

---

## 3. Princípios de Design

### 3.1 Acessibilidade é um Requisito, Não um Recurso
- Todo widget interativo TEM `Accessible.name` descritivo
- Todo widget interativo TEM `Accessible.description` quando `name` sozinho é ambíguo
- `Accessible.role` correto (MenuItem para itens de menu, Button para ações)
- `focusPolicy: Qt.TabFocus | Qt.ClickFocus` em todo interativo
- Contraste WCAG AA mínimo (4.5:1 texto, 3:1 UI grande)
- Cor nunca é o único indicador — ícone + texto sempre
- Funciona 100% sem mouse

### 3.2 Progressive Disclosure
- **Nível 1** (visível abrir): Busca + Favoritos (max 12) + 3 recentes
- **Nível 2** (1 clique): Todas as categorias, Todos os apps
- **Nível 3** (2 cliques): Configurações de seção, filtros avançados

### 3.3 Carga Cognitiva Controlada
- Máximo 5-7 elementos interativos visíveis por grupo
- Máximo 3 profundidades de navegação
- Feedback visual em < 50ms para toda ação
- Labels claros, linguagem de amigo, sem jargão

### 3.4 Forgiving Design
- Undo no reordenamento de favoritos (Ctrl+Z)
- Confirmação apenas para ações destrutivas (remover favorito)
- Defaults sensatos — funciona bem out-of-the-box

### 3.5 Performance Perceptível
- Abertura do menu: < 150ms para first paint
- Busca: < 100ms para primeiro resultado
- Scroll: 60fps constante, sem janks
- Lazy loading para conteúdo abaixo do fold

---

## 4. Arquitetura do Novo Menu

### 4.1 Árvore de Componentes

```
main.qml (PlasmoidItem — root, models, compact representation)
├── FullRepresentation.qml (popup container)
│   ├── Header.qml (barra de busca + avatar + power/session buttons)
│   ├── ContentArea.qml (área principal — StackView vertical)
│   │   ├── HomePage.qml (vista padrão ao abrir)
│   │   │   ├── SmartSection.qml (apps sugeridos por contexto)
│   │   │   ├── FavoritesSection.qml (grid/lista de favoritos com drop area)
│   │   │   └── RecentSection.qml (recentes colapsável)
│   │   ├── AllAppsPage.qml (todas as categorias)
│   │   │   ├── CategorySidebar.qml (sidebar de categorias)
│   │   │   └── AppContentView.qml (grid/lista de apps da categoria)
│   │   ├── SearchResultsPage.qml (resultados categorizados)
│   │   └── PlacesPage.qml (computador, histórico, frequentes)
│   └── Footer.qml (navegação principal: Home | Apps | Places | botão power)
├── delegates/
│   ├── AppDelegate.qml (item de app — grid e lista)
│   ├── CategoryDelegate.qml (item de categoria na sidebar)
│   ├── SearchResultDelegate.qml (resultado de busca com tipo)
│   └── SectionHeaderDelegate.qml (cabeçalho de seção acessível)
├── components/
│   ├── AnimatedStackView.qml (StackView com transições padronizadas)
│   ├── AppContextMenu.qml (menu de contexto com ações)
│   ├── DragDropArea.qml (drag & drop reusável)
│   ├── FavoriteIndicator.qml (badge de favorito)
│   ├── SectionCollapser.qml (expand/collapse com contagem)
│   ├── AccessibleGridView.qml (grid com Accessible completo)
│   ├── AccessibleListView.qml (list com Accessible completo)
│   └── PowerMenu.qml (popup de power/session actions)
├── config/
│   ├── main.xml (schema de configuração expandido)
│   ├── config.qml (registration de páginas de config)
│   └── ConfigGeneral.qml (UI de configuração)
├── singletons/
│   ├── MenuSingleton.qml (métricas, temas, constantes)
│   └── ActionMenuSingleton.qml (menu de contexto singleton)
├── code/
│   └── tools.js (utilidades: favoritos, triggers, formatação)
└── qmldir (registrations)
```

### 4.2 Fluxo de Dados

```
┌─────────────────────────────────────────────────────────┐
│                    main.qml (root)                       │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────┐ │
│  │RootModel  │  │RunnerModel│ │ComputerModel│ │Usage   │ │
│  │(all apps) │  │(search)   │ │(places)     │ │Models  │ │
│  │.favorites │  │           │ │             │ │recent/ │ │
│  │Model      │  │           │ │             │ │frequent│ │
│  └─────┬─────┘  └─────┬─────┘ └──────┬──────┘ └───┬────┘ │
│        │              │              │             │      │
│        ▼              ▼              ▼             ▼      │
│  ┌────────────────────────────────────────────────────┐   │
│  │              FullRepresentation                     │   │
│  │  ┌─────────┐                                       │   │
│  │  │ Header  │─── searchText ──▶ RunnerModel.query   │   │
│  │  └─────────┘                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │ ContentArea (VerticalStackView)              │  │   │
│  │  │                                              │  │   │
│  │  │  searchText.length > 0                       │  │   │
│  │  │    ? SearchResultsPage (RunnerModel)         │  │   │
│  │  │    : currentPage based on Footer tab         │  │   │
│  │  │       0 = HomePage (favorites + recent +     │  │   │
│  │  │                      smart suggestions)      │  │   │
│  │  │       1 = AllAppsPage (categories + apps)    │  │   │
│  │  │       2 = PlacesPage (computer + history)    │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │  ┌─────────┐                                       │   │
│  │  │ Footer  │─── tab index ──▶ ContentArea page     │   │
│  │  └─────────┘                                       │   │
│  └────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

### 4.3 Sistema de Foco (Tab Order)

```
1. Header.SearchField     (foco inicial ao abrir)
2. Header.AvatarButton    (Tab)
3. Header.PowerButton     (Tab)
4. ContentArea            (Tab — delega para item corrente)
   4a. Se HomePage:
       - SmartSection items (setas)
       - FavoritesSection items (setas + Tab)
       - RecentSection items (setas)
   4b. Se AllAppsPage:
       - CategorySidebar (setas vertical)
       - AppContentView (setas grid/lista)
   4c. Se SearchResultsPage:
       - Resultados (setas vertical)
5. Footer.TabBar          (Tab — Left/Right entre abas)
6. Footer.PowerActions    (Tab)
7. → volta para 1         (Tab loops)
```

---

## 5. Roadmap de Implementação — Fases

| Fase | Descrição | Dependências | Critério de Conclusão |
|---|---|---|---|
| 1 | Fundação e Infraestrutura | — | Singleton, main.xml, main.qml compila e abre popup vazio |
| 2 | Header, Footer, Sidebar | Fase 1 | Busca funciona, abas navegáveis, power buttons |
| 3 | Páginas de Conteúdo | Fase 2 | HomePage, AllAppsPage, PlacesPage renderizando dados |
| 4 | Busca Avançada | Fase 3 | Resultados categorizados, highlight, Enter lança |
| 5 | Drag & Drop + Favoritos | Fase 3 | Reordenar, adicionar/remover, undo |
| 6 | Acessibilidade Total | Fase 3 | Orca anuncia 100% dos elementos, foco lógico |
| 7 | Inteligência e Contexto | Fase 3 | Smart section funcional |
| 8 | Config + First-Run | Fase 3 | ConfigGeneral redesenhado, onboarding |
| 9 | Performance + Polish | Fases 1-8 | Benchmarks dentro dos targets |
| 10 | Testes e Validação | Fases 1-9 | Aprovado em todos os critérios de competição |

---

## 6. Fase 1 — Fundação e Infraestrutura

### 6.1 `main.xml` — Schema de Configuração Expandido

Novas entradas a adicionar ao schema:

```xml
<!-- Visibility Controls -->
<entry name="showSmartSection" type="Bool">
    <label>Show AI-suggested apps section on the home page</label>
    <default>true</default>
</entry>
<entry name="showRecentSection" type="Bool">
    <label>Show recently used apps section on the home page</label>
    <default>true</default>
</entry>
<entry name="showFrequentSection" type="Bool">
    <label>Show frequently used apps section on the home page</label>
    <default>false</default>
</entry>
<entry name="showPlacesTab" type="Bool">
    <label>Show Places tab in the footer</label>
    <default>true</default>
</entry>

<!-- Home Page Layout -->
<entry name="maxFavoritesVisible" type="Int">
    <label>Maximum number of favorites visible without scrolling</label>
    <default>12</default>
</entry>
<entry name="maxRecentVisible" type="Int">
    <label>Maximum number of recent apps visible</label>
    <default>5</default>
</entry>
<entry name="homePageLayout" type="Int">
    <label>Home page layout: 0 = Grid, 1 = List, 2 = Compact Grid</label>
    <default>0</default>
</entry>

<!-- Search -->
<entry name="searchShowCategories" type="Bool">
    <label>Group search results by category</label>
    <default>true</default>
</entry>

<!-- Power/Session (mantidos do legado) -->
<!-- ... mantidos: primaryActions, showActionButtonCaptions, systemFavorites -->

<!-- Accessibility -->
<entry name="highContrastMode" type="Bool">
    <label>Force high contrast for all text elements</label>
    <default>false</default>
</entry>
<entry name="largeTextMode" type="Bool">
    <label>Increase text sizes for readability</label>
    <default>false</default>
</entry>

<!-- Onboarding -->
<entry name="onboardingCompleted" type="Bool">
    <label>Whether the first-run experience has been completed</label>
    <default>false</default>
</entry>
```

### 6.2 `MenuSingleton.qml` — Singleton de Métricas e Constantes

Substituir `KickoffSingleton.qml` com:

- Métricas de grid/lista/compacto (como legado)
- Constantes de animação unificadas
- Constantes de acessibilidade (min touch target: 44px, min focus ring: 2px)
- PowerManagement DataSource (mantido do legado)
- Paleta de cores acessíveis calculada dinamicamente

```
Arquivo: singletons/MenuSingleton.qml
Registrado em: qmldir como "singleton MenuSingleton 1.0 singletons/MenuSingleton.qml"
```

### 6.3 `main.qml` — Root Refatorizado

Manter:
- `RootModel`, `RunnerModel`, `ComputerModel`, `RecentUsageModel`, `FrequentUsageModel`
- `compactRepresentation` com suporte a ícone + label
- `ProcessRunner` para "Edit Applications"
- Property bindings para header/footer/sidebar/contentArea

Remover:
- `listDelegate` invisível para medição (mover para Singleton)
- Referências a `KickoffSingleton` (renomear para `MenuSingleton`)

Adicionar:
- Property `currentPage: int` (0=Home, 1=AllApps, 2=Places)
- Property `isSearchActive: bool` derivada de `searchField.text.length > 0`
- Signal `favoriteUndoRequested()` para undo de remoção de favorito

### 6.4 `qmldir` — Registration

```
singleton MenuSingleton 1.0 singletons/MenuSingleton.qml
singleton ActionMenuSingleton 1.0 singletons/ActionMenuSingleton.qml
```

### 6.5 Passos concretos

- [ ] Criar a árvore de diretórios: `delegates/`, `components/`, `singletons/`
- [ ] Criar `main.xml` expandido com todos os novos campos
- [ ] Criar `MenuSingleton.qml` baseado no legado, com as adições
- [ ] Reescrever `main.qml` mantendo os modelos, limpando o resto
- [ ] Criar `EmptyPage.qml` base (pode ser idêntico ao legado)
- [ ] Criar `AnimatedStackView.qml` unificando Horizontal e Vertical
- [ ] Atualizar `qmldir`
- [ ] Validar: popup abre, não crash, singleton acessível
- [ ] Criar `config.qml` registration (idêntico ao legado)

---

## 7. Fase 2 — UI Core: Header, Footer, Sidebar

### 7.1 `Header.qml` — Redesenho Total

**Layout**: 
```
┌────────────────────────────────────────────────┐
│ [🔍 Search apps, settings, files...        ]   │
│ ┌──┐ UserName                     [⚙] [⏻]    │
│ │🧑│ user@hostname                             │
│ └──┘                                            │
└────────────────────────────────────────────────┘
```

**Especificação**:
- Busca SEMPRE visível, foco automático ao abrir o menu
- Avatar + nome do usuário numa linha abaixo da busca (compacto)
- Botão de engrenagem (Settings) e Power no header, NÃO no footer
- Avatar clicável abre `kcm_users`
- Ao digitar, área abaixo troca para `SearchResultsPage`

**Acessibilidade**:
- `SearchField`: `Accessible.name: i18n("Search applications, settings, and files")`
- Avatar: `Accessible.name: kuser.fullName || kuser.loginName`, `Accessible.role: Accessible.Button`
- Power: `Accessible.name: i18n("Power and Session Options")`, `Accessible.role: Accessible.ButtonMenu`
- Settings: `Accessible.name: i18n("System Settings")`, `Accessible.role: Accessible.Button`

**Mudanças vs. legado**:
- ❌ Remover: busca some no hover do avatar
- ❌ Remover: `LeaveButtons` no header (mover design para PowerMenu dropdown)
- ✅ Novo: linha de info do usuário sempre visível (compacta)
- ✅ Novo: Power button abre PowerMenu popup
- ✅ Novo: Settings button abre `systemsettings`

### 7.2 `Footer.qml` — Barra de Navegação Principal

**Layout**:
```
┌────────────────────────────────────────────────┐
│  [🏠 Home]   [📦 All Apps]   [📁 Places]      │
└────────────────────────────────────────────────┘
```

**Especificação**:
- TabBar visível (ao contrário do legado onde está `visible: false`)
- 3 abas: Home, All Apps, Places (Places ocultável por config)
- Ícone + texto em cada aba
- Aba ativa indicada por highlight visual + `Accessible.checked: true`
- Navegação por Left/Right keys, loop wrap

**Acessibilidade**:
- TabBar: `Accessible.role: Accessible.TabList`
- Cada Tab: `Accessible.role: Accessible.Tab`, `Accessible.name: text`
- Aba ativa: `Accessible.pressed: true` ou uso correto de `checked` state

### 7.3 `CategorySidebar.qml` — Sidebar de Categorias

**Especificação**:
- Usado dentro de AllAppsPage
- Lista de categorias do `RootModel`
- Cada item é um `CategoryDelegate`
- Navegação por setas Up/Down
- Seleção muda conteúdo na área principal
- Separador visual entre seções (Favoritos / Categorias / All Apps)

**Acessibilidade**:
- ListView: `Accessible.role: Accessible.List`, `Accessible.name: i18n("Application categories")`
- Cada item: `Accessible.role: Accessible.MenuItem`, `Accessible.name: model.display`

### 7.4 Passos concretos

- [ ] Criar `Header.qml` novo com busca permanente + user info + power button
- [ ] Criar `components/PowerMenu.qml` (dropdown de power/session)
- [ ] Criar `Footer.qml` novo com TabBar visível de 3 abas
- [ ] Criar `delegates/CategoryDelegate.qml` 
- [ ] Integrar Header + Footer no FullRepresentation
- [ ] Validar: Tab navega Header → Content → Footer → Header
- [ ] Validar: Orca anuncia todos os botões corretamente
- [ ] Validar: Left/Right navega entre abas do footer

---

## 8. Fase 3 — Páginas de Conteúdo

### 8.1 `HomePage.qml` — Vista Padrão ao Abrir

**Layout**:
```
┌────────────────────────────────────────────────┐
│ Suggested for you                    [See all]  │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐                    │
│ │App1│ │App2│ │App3│ │App4│ (baseado em hora)   │
│ └────┘ └────┘ └────┘ └────┘                    │
│                                                 │
│ Favorites                          [Edit] (5)   │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐    │
│ │Fav1│ │Fav2│ │Fav3│ │Fav4│ │Fav5│ │Fav6│    │
│ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘    │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐    │
│ │Fav7│ │Fav8│ │Fav9│ │F10 │ │F11 │ │F12 │    │
│ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘    │
│                                                 │
│ Recent                              [Clear]     │
│  Firefox               há 5 minutos             │
│  Terminal               há 12 minutos            │
│  VS Code                há 1 hora                │
└────────────────────────────────────────────────┘
```

**SmartSection** (Suggested):
- Mostra 4-6 apps relevantes baseados em `frequentUsageModel` + hora do dia
- `SectionHeaderDelegate` com "Suggested for you" + contagem
- Colapsável via config `showSmartSection`
- Botão "See all" abre AllAppsPage com filtro por frequentes

**FavoritesSection**:
- Grid de favoritos do `rootModel.favoritesModel`
- Limite visual de `maxFavoritesVisible` (default 12)
- Botão "[Edit]" entra em modo edição (drag handles visíveis)
- Indicador numérico "(N)" no header mostra total de favoritos
- Se vazio: `PlaceholderMessage` com hint para adicionar

**RecentSection**:
- Lista colapsada das últimas `maxRecentVisible` apps usadas
- Timestamps legíveis ("há 5 minutos", não "5m ago")
- Botão "[Clear]" limpa histórico recente (com confirmação)

**Acessibilidade**:
- Cada seção: `Accessible.role: Accessible.Grouping`, `Accessible.name: sectionTitle`
- Botões de ação de seção: `Accessible.name` descritivo (ex: "See all suggested apps")
- PlaceholderMessage: `Accessible.role: Accessible.StaticText`

### 8.2 `AllAppsPage.qml` — Dual Pane

**Layout**:
```
┌────────────┬───────────────────────────────────┐
│ Categories │  Games (12)                        │
│            │                                    │
│ ⭐Favorites│  ┌────┐ ┌────┐ ┌────┐ ┌────┐    │
│  All Apps  │  │Game│ │Game│ │Game│ │Game│       │
│ ──────────│  │ 1  │ │ 2  │ │ 3  │ │ 4  │       │
│  Development│ └────┘ └────┘ └────┘ └────┘    │
│  Education │  ┌────┐ ┌────┐ ┌────┐             │
│ >Games     │  │Game│ │Game│ │Game│              │
│  Graphics  │  │ 5  │ │ 6  │ │ 7  │              │
│  Internet  │  └────┘ └────┘ └────┘             │
│  Multimedia│                                    │
│  Office    │                                    │
│  System    │                                    │
│  Utilities │                                    │
└────────────┴───────────────────────────────────┘
```

**Sidebar**:
- Reutiliza conceito do legado mas com `CategoryDelegate` melhorado
- Favorites é sempre o primeiro item
- "All Apps" mostra categorizado (ListOfGrids ou lista com seções)
- Categorias individuais mostram apenas apps daquela categoria
- Contagem de apps ao lado do nome: "Games (12)"

**Área de conteúdo**:
- Grid ou lista baseado em config
- Headers de seção com contagem
- Scroll suave com lazy loading
- Seções expansíveis com `SectionCollapser`

**Acessibilidade**:
- Sidebar: `Accessible.role: Accessible.List`, `Accessible.name: i18n("Application categories")`
- Content: `Accessible.role: Accessible.List` ou `Accessible.role: Accessible.Table`
- Section headers: `Accessible.role: Accessible.Heading`, nível 2

### 8.3 `PlacesPage.qml` — Locais e Histórico

**Mantém** conceito do legado (sidebar com Computer/History/Frequently Used), mas:
- Acessibilidade completa
- Timestamps legíveis para histórico
- Indicador "⭐" nos itens que também estão em favoritos
- Computer detecta laptop (mantido)

### 8.4 Passos concretos

- [ ] Criar `HomePage.qml` com SmartSection + FavoritesSection + RecentSection
- [ ] Criar `components/SectionCollapser.qml` (expand/collapse com contagem)
- [ ] Criar `components/FavoriteIndicator.qml` (badge overlay)
- [ ] Criar `delegates/SectionHeaderDelegate.qml` (header acessível com ação)
- [ ] Criar `AllAppsPage.qml` com sidebar + content area
- [ ] Criar `delegates/AppDelegate.qml` unificado (grid + lista modes)
- [ ] Refatorar `PlacesPage.qml` com acessibilidade
- [ ] Criar `FullRepresentation.qml` integrando tudo via ContentArea StackView
- [ ] Validar: navegar entre Home → AllApps → Places via footer
- [ ] Validar: favoritos exibidos, categorias com apps corretos

---

## 9. Fase 4 — Sistema de Busca Avançado

### 9.1 `SearchResultsPage.qml`

**Layout**:
```
┌────────────────────────────────────────────────┐
│ Applications (3)                                │
│  Firefox Web Browser              ⭐            │
│  Thunderbird Mail                               │
│  Firefox Developer Edition                      │
│                                                 │
│ System Settings (2)                             │
│  Display Configuration                          │
│  Network Settings                               │
│                                                 │
│ Files (1)                                       │
│  ~/Documents/report.pdf                         │
│                                                 │
│ Actions                                         │
│  Open Terminal Here                             │
│  Calculate: 2+2 = 4                             │
└────────────────────────────────────────────────┘
```

**Funcionalidades**:
- Resultados agrupados por tipo (Application, SystemSettings, File, Action, Calculator)
- Primeiro resultado de "Applications" pré-selecionado (Enter para lançar)
- `FavoriteIndicator` (⭐) nos apps que já são favoritos
- Se 0 resultados: `PlaceholderMessage` com sugestão ("Try searching for...")
- Busca responsiva: debounce de 150ms, resultados progressivos
- Categorias colapsáveis se houver muitos resultados

**Acessibilidade**:
- Lista: `Accessible.role: Accessible.List`, `Accessible.name: i18n("Search results for: %1", query)`
- Cada grupo: `Accessible.role: Accessible.Grouping`, `Accessible.name: categoryName + " (" + count + ")"`
- Resultado: `Accessible.role: Accessible.MenuItem`
- PlaceholderMessage: `Accessible.role: Accessible.StaticText`

### 9.2 `delegates/SearchResultDelegate.qml`

**Layout**: Ícone + Nome + Descrição + Tipo tag + ⭐ indicator
- Ícone médio (24px) à esquerda
- Nome primário em negrito
- Descrição secundária em cor atenuada
- Badge de tipo ("App", "Setting", "File") à direita em tamanho pequeno
- Indicador de favorito se aplicável

### 9.3 Passos concretos

- [ ] Criar `SearchResultsPage.qml` com categorização
- [ ] Criar `delegates/SearchResultDelegate.qml`
- [ ] Integrar com `RunnerModel` existente — agrupar por `group`/`subtext`
- [ ] Implementar debounce de busca (150ms) no Header
- [ ] Implementar Enter → lançar primeiro resultado
- [ ] Implementar escape → limpar busca → voltar para HomePage
- [ ] Validar: buscar "fire" retorna Firefox, categorizado como "Applications"
- [ ] Validar: Orca anuncia "Search results for: fire, Applications, 1 result, Firefox Web Browser"

---

## 10. Fase 5 — Drag & Drop, Favoritos e Personalização

### 10.1 `components/DragDropArea.qml`

Refatorar `KickoffDropArea.qml` legado:
- Manter: reordenação por drag, auto-scroll, atalhos Ctrl+Shift+Arrow
- Adicionar: feedback visual de "drop zone" durante drag
- Adicionar: animação de feedback quando item é solto
- Adicionar: Ctrl+Z para undo do último reordenamento

### 10.2 Menu de Contexto Expandido

Expandir `tools.js` com novas ações:
- "Add to Favorites" / "Remove from Favorites" (mantido)
- **NOVO**: "Pin to top" — move item para posição 0 dos favoritos
- **NOVO**: "Open file location" — abre Dolphin no diretório do .desktop
- **NOVO**: "Show in All Apps" — navega para a categoria do app

### 10.3 Modo de Edição de Favoritos

- Botão "[Edit]" no header de FavoritesSection entra em modo de edição
- Itens mostram handle de drag (≡) e botão de remoção (×)
- Modo de edição desativa clique para lançar (previne ação acidental)
- Sair do modo: botão "[Done]" ou Escape

### 10.4 Passos concretos

- [ ] Refatorar `DragDropArea.qml` com feedback visual
- [ ] Expandir `tools.js` com novas ações de contexto
- [ ] Implementar Edit Mode na FavoritesSection
- [ ] Implementar Ctrl+Z undo para reordenamento
- [ ] Validar: drag funciona em grid e lista
- [ ] Validar: menu de contexto mostra todas as ações
- [ ] Validar: Orca anuncia "Edit favorites mode, drag handle for Firefox, remove button"

---

## 11. Fase 6 — Acessibilidade Total (Orca / ATK)

### 11.1 Checklist de Acessibilidade por Componente

| Componente | Accessible.name | Accessible.role | Accessible.description | Focus Policy |
|---|---|---|---|---|
| SearchField | "Search applications, settings, and files" | SearchBox (default) | — | Tab + Click + Shortcut |
| AvatarButton | kuser.fullName | Button | "Open user settings" | Tab |
| PowerButton | "Power and session options" | ButtonMenu | — | Tab |
| SettingsButton | "System settings" | Button | — | Tab |
| TabBar | "Main navigation" | TabList | — | Tab |
| Tab (Home) | "Home" | Tab | "Show favorites and recent apps" | Left/Right |
| Tab (All Apps) | "All Applications" | Tab | "Browse all installed applications" | Left/Right |
| Tab (Places) | "Places" | Tab | "Computer, history, and frequent" | Left/Right |
| AppDelegate (grid) | model.display | MenuItem | model.description | Arrow keys |
| AppDelegate (list) | model.display | MenuItem | model.description | Arrow keys |
| CategoryDelegate | model.display + " (" + count + ")" | MenuItem | — | Arrow keys |
| SectionHeader | section + " (" + count + " items)" | Heading | — | — |
| SearchResultDelegate | model.display | MenuItem | model.description + " - " + category | Arrow keys |
| FavoritesEditButton | "Edit favorites" | Button | — | Tab |
| FavoriteDragHandle | "Reorder " + model.display | Button | "Use arrow keys to move" | Arrow keys |
| FavoriteRemoveButton | "Remove " + model.display + " from favorites" | Button | — | Tab |
| ClearRecentButton | "Clear recent apps" | Button | "Removes all recent app entries" | Tab |
| SectionCollapser | section + ": " + (expanded ? "collapse" : "expand") | Button | count + " items" | Tab |

### 11.2 Requisitos de Foco

1. **Tab order lógico**: Header → Content → Footer (circular)
2. **Dentro de Content**: Navegação por setas (Up/Down para listas, Up/Down/Left/Right para grids)
3. **Focus ring visível**: 2px solid, contraste com background, canto arredondado
4. **Skip links**: não necessário para menu (tamanho compacto)
5. **No mouse-only actions**: tudo acessível por teclado
6. **Escape fecha o menu**: consistente com outros popups Plasma

### 11.3 Announcements Esperadas do Orca

Cenário: Usuário abre o menu com teclado:
```
"BigLinux App Menu, popup window"
"Search applications, settings, and files, text field, focused"
```

Cenário: Usuário aperta Tab:
```
"Username, button"
```

Cenário: Usuário aperta Tab novamente:
```
"Power and session options, button menu"
```

Cenário: Usuário aperta Tab novamente:
```
"Home, tab, selected, 1 of 3"
```

Cenário: Usuário no grid de favoritos com seta:
```
"Firefox Web Browser, Web browser, menu item, 1 of 12"
```

Cenário: Usuário inicia busca:
```
"Search results for: fire"
"Applications, group, 1 result"
"Firefox Web Browser, Web browser, menu item, 1 of 1"
```

### 11.4 Contrast e Scaling

- Todos os textos: ratio ≥ 4.5:1 contra o background (WCAG AA)
- UI components grandes (>= 18pt): ratio ≥ 3:1 (WCAG AA)
- Focus ring: ratio ≥ 3:1 contra adjacentes
- Testado a 200% font scaling: layout não quebra
- Cor nunca é indicador único: favorito = ⭐ + texto, não só cor amarela
- `highContrastMode` config: força cores com ratio ≥ 7:1 (WCAG AAA)

### 11.5 Passos concretos

- [ ] Auditar TODO componente e adicionar `Accessible.name`, `.role`, `.description`
- [ ] Implementar focus ring visível (pode ser via Plasma Highlight existente)
- [ ] Verificar tab order: navegar todo o menu apenas com Tab e Shift+Tab
- [ ] Verificar seta keys: navegar dentro de listas/grids
- [ ] Verificar Escape: fecha o menu de qualquer ponto
- [ ] Verificar Enter: ativa o item focado
- [ ] Testar com Orca: cada cenário acima deve funcionar
- [ ] Testar com 200% font scaling
- [ ] Testar com tema de alto contraste do KDE
- [ ] Documentar qualquer issue como CRITICAL

---

## 12. Fase 7 — Inteligência e Contexto

### 12.1 SmartSection — Sugestões Contextuais

**Algoritmo**:
1. Combinar `frequentUsageModel` com hora do dia
2. Score = `frequency * timeWeight`
   - `timeWeight` baseado na hora: manhã (6-12), tarde (12-18), noite (18-24), madrugada (0-6)
   - Mapeamento hora → apps construído por análise dos últimos 30 dias
3. Top 4-6 apps com maior score são mostrados
4. Não duplicar apps que já estão nos favoritos (ou marcar como "also in favorites")

**Implementação**:
- Proxy model JS sobre `frequentUsageModel`
- Scoring calculado em `tools.js` (função pura, testável)
- Recalcular a cada abertura do menu (não em background)
- Persistência: não necessária — dados vêm do KActivitiesStats

**Fallback**:
- Se `frequentUsageModel.count === 0`: mostrar top apps do sistema (browser, dolphin, terminal)
- Se config `showSmartSection === false`: seção não renderiza

### 12.2 Indicador de Duplicatas

Quando um app aparece em AllAppsPage e já está em favoritos:
- Mostrar ⭐ pequena no canto do ícone via `FavoriteIndicator`
- Tooltip: "Also in your favorites"
- No menu de contexto: "Remove from Favorites" em vez de "Add to Favorites"

Query: `rootModel.favoritesModel.isFavorite(model.favoriteId)`

### 12.3 Passos concretos

- [ ] Implementar `SmartSection.qml` com proxy model
- [ ] Implementar scoring function em `tools.js`
- [ ] Implementar `FavoriteIndicator.qml` (badge overlay pequeno)
- [ ] Integrar `FavoriteIndicator` no `AppDelegate`
- [ ] Validar: sugestões mudam por hora do dia
- [ ] Validar: favoritos marcados com ⭐ em todas as vistas

---

## 13. Fase 8 — Configuração e First-Run Experience

### 13.1 `ConfigGeneral.qml` — Redesenho

**Seções**:

1. **Appearance** (Aparência)
   - Ícone e label do painel (mantido)
   - Layout da home: Grid / Lista / Grid Compacto
   - Exibição de favoritos: Grid / Lista
   - Exibição de aplicativos: Grid / Lista
   - Posição da sidebar: Esquerda / Direita
   - Ícones simbólicos on/off
   - Modo compacto on/off

2. **Sections** (Seções)
   - Toggle: Smart Suggestions
   - Toggle: Recent Apps
   - Toggle: Frequent Apps
   - Toggle: Places tab
   - Toggle: "All Applications" category
   - Max favoritos visíveis: SpinBox (4-24)
   - Max recentes visíveis: SpinBox (3-10)

3. **Actions** (Ações do sistema)
   - Power / Session / Both (mantido)
   - Show captions (mantido)

4. **Accessibility** (Acessibilidade)
   - Toggle: High contrast mode
   - Toggle: Large text mode
   - Link: "Configure screen reader (Orca)"
   
5. **Search** (Busca)
   - Toggle: Group results by category
   - Button: Configure search plugins
   - Sort alphabetically on/off

### 13.2 First-Run Experience (Onboarding)

Na **primeira abertura** do menu (`onboardingCompleted === false`):

**Passo 1**: Overlay sutil sobre o menu com 3 dicas:
```
┌─────────────────────────────────────────┐
│  Welcome to BigLinux!                    │
│                                          │
│  1. 🔍 Type to search anything           │
│  2. ⭐ Right-click to add favorites      │
│  3. 🔧 Press the gear icon to customize  │
│                                          │
│              [Got it!]                    │
└─────────────────────────────────────────┘
```

- Não bloqueia interação (pode clicar "Got it!" ou simplesmente usar o menu)
- Overlay some com `NumberAnimation` de opacidade
- Ao fechar: `Plasmoid.configuration.onboardingCompleted = true`
- Acessível: Orca anuncia "Welcome overlay, press Enter to dismiss"

### 13.3 Passos concretos

- [ ] Redesenhar `ConfigGeneral.qml` com seções organizadas
- [ ] Adicionar toggles para novas configs
- [ ] Implementar overlay de onboarding
- [ ] Validar: todas as configs refletem imediatamente no menu
- [ ] Validar: onboarding aparece na primeira vez, não aparece depois

---

## 14. Fase 9 — Performance e Polish

### 14.1 Targets de Performance

| Métrica | Target | Medição |
|---|---|---|
| First paint (popup open) | < 150ms | `console.time()` no `Component.onCompleted` |
| Search first result | < 100ms | Timer entre `onTextEdited` e primeiro item visível |
| Scroll fps | ≥ 55fps constante | `FrameRate` overlay do Qt |
| Grid de 100+ apps | < 200ms para render | `cacheBuffer` + `reuseItems: true` |
| Memory (idle) | < 50MB RSS | `ps aux` |

### 14.2 Otimizações

1. **Lazy loading de seções na HomePage**: Usar `Loader` com `active: visible`
2. **Grid cacheBuffer reduzido**: `cacheBuffer: cellHeight * 2` (não o default)
3. **Ícones assíncronos**: `Kirigami.Icon { asynchronous: true }` onde não é o foco
4. **Delegate reuse**: `reuseItems: true` em todas as views (já no legado)
5. **Model filtering no C++**: `KSortFilterProxyModel` (já usado) — não filtragem JS
6. **Debounce de busca**: 150ms para evitar queries intermediárias
7. **Avoid binding loops**: Usar `Binding` explícito com `restoreMode`
8. **Transition performante**: Usar `NumberAnimation` em `x`/`y` (não Animator — legado already found smoother)

### 14.3 Polish Visual

1. **Transições entre páginas**: Slide horizontal suave (500ms OutCubic)
2. **Hover feedback**: Escala sutil 1.02x no grid item + sombra de elevação
3. **Press feedback**: Escala 0.97x por 100ms
4. **Seção collapse**: Animar altura para 0 com OutCubic
5. **Busca typing**: Highlight gradual nos resultados (fade-in)
6. **Favorito adicionado**: Flash verde sutil no grid slot
7. **Favorito removido**: Fade-out do item com collapse do espaço

### 14.4 Passos concretos

- [ ] Implementar Loaders para seções da HomePage
- [ ] Configurar cacheBuffer em todas as views
- [ ] Adicionar `asynchronous: true` em ícones de grid
- [ ] Implementar debounce no searchField
- [ ] Adicionar microanimações de hover/press
- [ ] Perfil de performance: medir targets
- [ ] Otimizar qualquer violação de target

---

## 15. Fase 10 — Testes e Validação

### 15.1 Checklist de Competição

| Critério | Teste | Status |
|---|---|---|
| **Usabilidade** | Encontrar app em ≤ 3 cliques | ⬜ |
| **Usabilidade** | Busca retorna app correto | ⬜ |
| **Usabilidade** | Favoritos adicionáveis/removíveis | ⬜ |
| **Usabilidade** | Power/Shutdown acessível em 2 cliques | ⬜ |
| **Design** | Hierarquia visual clara | ⬜ |
| **Design** | Smooth animations (≥ 55fps) | ⬜ |
| **Design** | Consistência visual entre grid/lista | ⬜ |
| **Design** | Feedback para toda ação | ⬜ |
| **Acessibilidade** | Orca anuncia todos os widgets | ⬜ |
| **Acessibilidade** | Menu operável 100% por teclado | ⬜ |
| **Acessibilidade** | Tab order lógico | ⬜ |
| **Acessibilidade** | Contraste WCAG AA em todo texto | ⬜ |
| **Acessibilidade** | 200% font scaling não quebra layout | ⬜ |
| **Acessibilidade** | Cor não é único indicador | ⬜ |
| **Qualidade** | Sem crash em 1 hora de uso | ⬜ |
| **Qualidade** | Sem leak de memória | ⬜ |
| **Qualidade** | Sem regressão em configs existentes | ⬜ |
| **Utilidade** | Smart suggestions relevantes | ⬜ |
| **Utilidade** | Recentes / Frequentes úteis | ⬜ |
| **Utilidade** | Duplicatas eliminadas/marcadas | ⬜ |
| **i18n** | Labels usando i18n() | ⬜ |
| **i18n** | RTL layout funcional | ⬜ |
| **Touch** | Touch targets ≥ 44px | ⬜ |
| **Touch** | Long press = context menu | ⬜ |

### 15.2 Testes Manuais Obrigatórios

1. **Fluxo "Abrir Firefox"**:
   - Abrir menu → digitar "fire" → Enter → Firefox abre
   - Tempo: < 3 segundos
   
2. **Fluxo "Adicionar favorito"**:
   - Abrir menu → All Apps → Games → right-click "Solitaire" → "Add to Favorites"
   - Voltar para Home → Solitaire aparece nos favoritos

3. **Fluxo "Desligar computador"**:
   - Abrir menu → clicar Power button no header → "Shut Down" → confirma

4. **Fluxo "Orca navegar todo o menu"**:
   - Abrir menu com Super → Orca anuncia tudo → Tab por todos → chega de volta ao search

5. **Fluxo "Primeiro uso"**:
   - Zerar config → abrir menu → onboarding aparece → fechar → nunca mais aparece

6. **Fluxo "Mudar exibição"**:
   - Abrir config → mudar de Grid para Lista → apply → menu mostra em lista

### 15.3 Passos concretos

- [ ] Executar cada teste manual da seção 15.2
- [ ] Documentar qualquer falha
- [ ] Corrigir cada falha e re-testar
- [ ] Fazer bug bash de 1 hora com uso intenso
- [ ] Testar em monitores: 1080p, 4K, vertical
- [ ] Testar com Wayland e X11
- [ ] Testar em BigLinux + Manjaro + KDE Neon

---

## 16. Especificação de Acessibilidade Completa

### 16.1 Propriedades Obrigatórias em Todo Widget Interativo

```qml
// TEMPLATE — aplicar em TODOS os buttons, delegates, fields
Accessible.name: "descriptive text"              // OBRIGATÓRIO
Accessible.role: Accessible.Button               // OBRIGATÓRIO (role correto)
Accessible.description: "extra context if needed" // QUANDO name não é suficiente
Accessible.onPressAction: { /* activar */ }       // PARA itens não-standard

// PARA estados dinâmicos
Accessible.checked: isActive  // checkboxes, toggles, tabs
Accessible.disabled: !enabled // auto no Qt, mas verificar

// Focus
activeFocusOnTab: true         // PARA todo interativo
focus: true                     // PARA o item que deve ter foco inicial
```

### 16.2 Roles Corretos

| Widget | Role Correto | Role Errado (legado) |
|---|---|---|
| App no grid/lista | `Accessible.MenuItem` | `Accessible.Cell` ❌ |
| Categoria na sidebar | `Accessible.MenuItem` | — |
| Header de seção | `Accessible.Heading` | — |
| Barra de busca | `Accessible.SearchBox` (auto) | — |
| TabBar | `Accessible.TabList` | — |
| Tab | `Accessible.Tab` | — |
| Power button | `Accessible.ButtonMenu` | — |
| Drag handle | `Accessible.Button` | — |
| Remove button | `Accessible.Button` | — |
| Separador | `Accessible.Separator` | — |
| PlaceholderMessage | `Accessible.StaticText` | — |

### 16.3 Armadilhas Comuns

1. ❌ `Accessible.ignored: true` em containers que têm filhos interativos → Orca pula tudo
2. ❌ `hoverEnabled: false` sem alternativa de teclado → item inacessível
3. ❌ `visible: false` em footer → foco navega para elemento invisível
4. ❌ `z: 2` em overlay → pode bloquear assistive technology
5. ❌ `textFormat: Text.RichText` com HTML → Orca lê tags em vez de conteúdo

---

## 17. Especificação de UX / Psicologia Humana

### 17.1 Progressive Disclosure

```
Abertura do menu (Nível 1):
├── Busca (ação mais frequente — posição prioritária)
├── Smart Suggestions (4 itens — abaixo de 7, ok cognitivo)
├── Favoritos (max 12 — below de 15, não sobrecarrega)
└── Recentes (3-5 — acesso rápido sem scroll)

1 clique/Tab (Nível 2):
├── All Apps tab → sidebar de categorias
├── Places tab → Computer/History/Frequent
└── See All → vista expandida de sugestões

2 cliques (Nível 3):
├── Categoria específica → apps dessa categoria
├── Config → personalização detalhada
└── Power menu → opções de desligar
```

### 17.2 Feedback Loops — Toda Ação Tem Resposta

| Ação | Feedback | Tempo |
|---|---|---|
| Hover em app | Background highlight | < 16ms (1 frame) |
| Click em app | Press animation + app abre | < 50ms visual |
| Right-click | Context menu aparece | < 100ms |
| Digitar na busca | Resultados atualizam | < 200ms |
| Adicionar favorito | Flash highlight + item aparece na seção | < 300ms |
| Remover favorito | Fade-out + collapse | < 300ms |
| Drag | Item segue o cursor + drop zones iluminam | < 16ms |
| Tab | Focus ring move | < 16ms |
| Mudar aba | Slide transition | 300ms |

### 17.3 Error Prevention

- **Disable invalid actions**: botão "Remove from Favorites" desabilitado se lista ficaria vazia
- **Confirm destructive**: "Clear recent apps" mostra inline dialog de confirmação
- **Sensible defaults**: Favoritos default incluem browser, file manager, settings, terminal, software center
- **No accidental triggers**: Drag requer 5px de movimento antes de ativar (evita clique falso)
- **Undo**: Ctrl+Z desfaz última operação de favorito

### 17.4 Contextual Help

- Tooltip em todos os botões de ícone (delay: 700ms)
- Subtitle labels: "Suggested based on your usage", "Your pinned apps", "Recently opened"
- Search placeholder text: "Search apps, settings, and files..."
- Empty states: "No favorites yet. Right-click an app to add it here."
- First-run overlay com 3 dicas (não-bloqueante)

### 17.5 Visual Hierarchy

```
Prioridade                    Tratamento visual
─────────────────────────────────────────────────
1. Busca                       Destaque máximo, foco automático
2. Favoritos/Smart items       Ícones grandes (grid), ou ícones médios (lista)
3. Nomes de apps               Font regular, cor primária
4. Descrições de apps           Font small, cor secundária
5. Headers de seção             Font medium, bold, cor primária
6. Contagens "(12)"            Font small, cor terciária
7. Timestamps                  Font small, cor terciária
8. Separadores visuais         Linha 1px, cor de separador do tema
```

---

## 18. Mapa de Arquivos (Novo vs. Legado)

| Arquivo Legado | Destino Novo | Mudança |
|---|---|---|
| `main.qml` | `main.qml` | Refatorar: limpar, adicionar properties |
| `FullRepresentation.qml` | `FullRepresentation.qml` | Reescrever: novo layout |
| `Header.qml` | `Header.qml` | Reescrever: busca permanente, user info, power |
| `Footer.qml` | `Footer.qml` | Reescrever: TabBar visível com 3 abas |
| `NormalPage.qml` | **REMOVIDO** | Substituído por ContentArea no FullRep |
| `ApplicationsPage.qml` | `AllAppsPage.qml` | Reescrever: sidebar + content refatorados |
| `PlacesPage.qml` | `PlacesPage.qml` | Refatorar: acessibilidade + indicadores |
| `BasePage.qml` | **REMOVIDO** | Lógica absorvida por AllAppsPage e PlacesPage |
| `EmptyPage.qml` | `EmptyPage.qml` | Manter idêntico |
| `KickoffListView.qml` | `components/AccessibleListView.qml` | Refatorar: acessibilidade completa |
| `KickoffGridView.qml` | `components/AccessibleGridView.qml` | Refatorar: acessibilidade completa |
| `KickoffListDelegate.qml` | `delegates/AppDelegate.qml` | Unificar grid + lista |
| `KickoffGridDelegate.qml` | `delegates/AppDelegate.qml` | Unificar grid + lista |
| `AbstractKickoffItemDelegate.qml` | `delegates/AppDelegate.qml` | Absorvido |
| `ListOfGridsView.qml` | `AllAppsPage.qml` (inline) | Simplificar |
| `ListOfGridsViewDelegate.qml` | **REMOVIDO** | Absorvido por AllAppsPage |
| `KickoffDropArea.qml` | `components/DragDropArea.qml` | Refatorar: feedback visual |
| `DropAreaListView.qml` | **REMOVIDO** | Inline em AccessibleListView |
| `DropAreaGridView.qml` | **REMOVIDO** | Inline em AccessibleGridView |
| `SectionView.qml` | `components/SectionView.qml` | Refatorar: acessibilidade |
| `KickoffSingleton.qml` | `singletons/MenuSingleton.qml` | Refatorar: constantes expandidas |
| `ActionMenu.qml` | `singletons/ActionMenuSingleton.qml` | Refatorar: ações expandidas |
| `LeaveButtons.qml` | `components/PowerMenu.qml` | Reescrever: popup dropdown |
| `HorizontalStackView.qml` | `components/AnimatedStackView.qml` | Unificar H+V |
| `VerticalStackView.qml` | `components/AnimatedStackView.qml` | Unificar H+V |
| `ConfigGeneral.qml` | `config/ConfigGeneral.qml` | Redesenhar: seções organizadas |
| `ConfigManager.qml` | **REMOVIDO** | Arquivo vazio, dead code |
| `config.qml` | `config/config.qml` | Manter |
| `code/tools.js` | `code/tools.js` | Expandir: score, novas ações |
| **NOVO** | `HomePage.qml` | Home com Smart + Favs + Recent |
| **NOVO** | `SearchResultsPage.qml` | Busca categorizada |
| **NOVO** | `components/SectionCollapser.qml` | Expand/collapse de seções |
| **NOVO** | `components/FavoriteIndicator.qml` | Badge de favorito |
| **NOVO** | `delegates/CategoryDelegate.qml` | Categoria na sidebar |
| **NOVO** | `delegates/SectionHeaderDelegate.qml` | Header de seção acessível |
| **NOVO** | `delegates/SearchResultDelegate.qml` | Resultado de busca com tipo |

---

## Resumo: Ordem de Execução

```
Fase 1 ─► Fase 2 ─► Fase 3 ─┬► Fase 4
                              ├► Fase 5
                              ├► Fase 6
                              ├► Fase 7
                              └► Fase 8
                                    │
                               Fase 9 ◄─┘
                                    │
                              Fase 10
```

- Fases 4-8 podem ser paralelizadas após a Fase 3
- Fase 9 (Performance) requer todas as outras completas
- Fase 10 (Testes) é o gate final

---

> **Documento vivo**: Atualizar este PLANNING.md à medida que decisões são tomadas e fases concluídas. Marcar checkboxes `[x]` ao finalizar cada passo.
