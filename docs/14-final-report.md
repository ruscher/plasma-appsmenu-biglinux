# 14 — Relatório Final (Rodada 1)

> Relatório vivo. Cobre o que foi entregue nesta rodada e o que resta, sem
> inflar o status. A missão completa (framework de gadgets, providers online,
> reescrita total) é trabalho de várias rodadas — o roadmap está no doc 12.

## Resumo executivo

O objetivo nº 1 — **o menu que fecha sozinho** — foi diagnosticado até a causa
raiz e corrigido. O crash era um **use-after-free dentro de `libQt6Quick`**
disparado por navegação por *hover* que chamava `StackView.replace()` em rajada,
no meio das transições. Removida a navegação por hover e adicionada guarda de
reentrância, o gatilho deixou de existir.

Além disso, foram corrigidas três outras superfícies reais de instabilidade
(delegate com deref de `model` sem guarda; API Plasma 5 quebrada no Info;
vazamento/acúmulo de `DataSource` no Info) e criada a documentação técnica
completa de auditoria e planejamento.

## Causas de crash

| # | Causa | Arquivo | Status |
|---|---|---|---|
| 1 | hover → `replace()` reentrante em transição (use-after-free) | `FullRepresentation.qml` | ✅ corrigido |
| 2 | `model.disabled` sem guarda no delegate vivo | `delegates/AppDelegate.qml` | ✅ corrigido |
| 3 | `kickoff.action("configure")` (Plasma 5) → TypeError | `InfoPage.qml` | ✅ corrigido |
| 4 | deref de `model.*` sem guarda (delegate legado) | `AbstractKickoffItemDelegate.qml` | ✅ corrigido (R2) |
| 5 | deref pós-`pop()` | `AllAppsPage.qml` | ✅ corrigido (R2) |
| 6 | `root.parent` em transição | `SearchResultsPage.qml` | ✅ corrigido (R2) |
| 7 | 2ª instância hover→replace (sidebar de categorias) | `AllAppsPage.qml` | ✅ corrigido (R2) |

## Bugs funcionais graves (Rodada 3 — varredura visual)

| # | Bug | Arquivo | Status |
|---|---|---|---|
| A | **Apps/categorias/busca em branco** (delegate sombreava `model`/`index`) | `delegates/AppDelegate.qml` | ✅ corrigido |
| B | Página de configuração nunca salvava (`id` em vez de `cfg_*`) | `ConfigGeneral.qml` | ✅ reescrita |
| C | Sidebar mostrava separadores e iniciava em linha oculta | `AllAppsPage.qml` | ✅ corrigido |
| D | Enter na busca não lançava o 1º resultado | `SearchResultsPage.qml` | ✅ corrigido |
| E | Cabeçalhos de seção gigantes (Places/busca) | `singletons/MenuSingleton.qml` | ✅ corrigido |

Verificação: screenshots de todas as abas na sessão real; contagens por
categoria batem com `kbuildsycoca6 --menutest` (165 entradas). Detalhes no doc 13.

**Correção da metodologia:** o sistema silencia todos os logs Qt
(`/etc/environment`: `QT_LOGGING_RULES='*=false'`). As validações de warnings
das rodadas anteriores eram cegas; com logging reabilitado no serviço, 7 classes
de warning reais (binding loops, `undefined`→bool, `QIcon`→string) foram
encontradas e corrigidas. Estado final: **0 warnings QML** em todas as páginas.

## Rodada 4 — Info modular + UX
- **Framework de gadgets entregue** (doc 08): grid 2/3/4 colunas com drag &
  drop e reorganização automática, tamanhos 1x1/2x1/1x2/2x2, galeria
  (adicionar/remover), configurações por gadget, persistência em
  `Plasmoid.configuration`, isolamento de falha por cartão, pausa quando
  invisível/menu fechado, cache e providers desacoplados sem chaves.
- **22 gadgets**: relógio (analógico/digital), calendário, contagem regressiva,
  notas, clima, CPU (todos os núcleos), memória, bateria, discos, monitor de
  disco, rede, informações do sistema, player (MPRIS), clipboard, links
  rápidos (editáveis, ícones grandes), feeds RSS com imagens (editáveis),
  câmbio, placares ao vivo (futebol e outros esportes), frase do dia, dicas,
  galeria, 2048.
- UX: lembra a última aba/categoria; pastas recentes na Home; sidebar de Apps
  no estilo de Places; Leave + botões Encerrar/Reiniciar/Desligar; avatar
  grande que abre a pasta pessoal.

## Estado por área (atualizado R4)
| Área | Estado |
|---|---|
| Info | **Modular** — framework + 22 gadgets, verificado por screenshots e 0 warnings. Sem shell exceto leitura única de `/proc/cpuinfo` e comandos fixos/configurados pelo usuário nos Quick Links. |

## Estado por área (R3)
| Área | Estado |
|---|---|
| Home | OK (favoritos, recentes apps/arquivos/pastas; ícones QIcon corrigidos). |
| Apps | **OK** — todas as categorias renderizam, contagens, estado vazio, config funcional. |
| Places | OK (cabeçalhos corrigidos). |
| Info | OK, tema-aware, CPU real; ainda monolítico/shell (framework de gadgets pendente). |
| Busca | OK — resultados renderizam; Enter lança o 1º. |
| Configuração | **OK** — antes não salvava nada. |

## Correções de memória/recursos
- ✅ Removido `Qt.createQmlObject` de `DataSource` por clique (vazamento).
- ✅ `DataSource` fire-and-forget agora desconecta.
- ⏳ Singletons/DataSources duplicados (Kickoff vs. novo) — consolidar.

## Arquitetura
- **Anterior:** fork de Kickoff com página única (`NormalPage`).
- **Atual:** arquitetura de 4 abas (Home/Apps/Places/Info) **ativa**, porém em
  migração pela metade (parte da stack antiga do Kickoff ainda viva via
  `AllAppsPage`; vários arquivos mortos; dois sistemas de singleton).
- **Alvo:** consolidar na stack nova (`AccessibleGridView`+`AppDelegate`+
  `MenuSingleton`), remover código morto, extrair Places, e construir o framework
  de gadgets do Info. Ver doc 12.

## Estado por área
| Área | Estado |
|---|---|
| Home | Funcional (favoritos/recentes via modelos KDE). Pequenas pendências (empty states, guardas, ações de arquivos). |
| Apps | Funcional (via KService/KSycoca pelos modelos Kicker). Dívida: stack antiga viva. |
| Places | Funcional (ComputerModel/RecentUsageModel). Futuro: KFilePlacesModel + arquivo próprio. |
| Info | Funcional mas monolítico e baseado em shell; estabilizado, mas **não** modular ainda. Framework de gadgets é trabalho futuro (doc 08). |
| Busca | Funcional; Enter-para-lançar quebrado por contrato de `contentArea` (P2). |

## Performance
Sem baseline numérico ainda (foco foi correção). Método e pontos de atenção no
doc 10. A medir na Rodada 2.

## Segurança/Privacidade
- Comandos shell no Info são fixos (sem injeção). Cópia de data usa `printf '%s'`
  com valor controlado.
- `curl wttr.in`/`phoronix` fazem rede sem enviar dados sensíveis, mas sem
  timeout/isolamento — endereçar no refactor de gadgets (doc 08).

## Testes
- `qmllint` (todo o projeto) e `plasmoidviewer` (carrega, não crasha ao iniciar):
  OK. Stress na sessão real: **pendente** (requer recarregar o plasmashell do
  usuário — deixado para o usuário; checklist no doc 11).

## Definição de pronto — status honesto
Respondido SIM: causa raiz do crash identificada e corrigida; logs graves de
runtime endereçados (itens 1-3); `main` intacta; branch nova com todas as
mudanças; documentação criada; código mais fácil de entender (mapeado + planos).

Ainda NÃO (trabalho futuro, documentado): gadgets modulares/adicionar/remover/
mover/redimensionar; persistência de layout; isolamento por-gadget; offline dos
gadgets online; consolidação da arquitetura; baseline/otimização de performance;
validação de estabilidade por stress ao vivo; itens P1/P2.

## Próximos passos
Seguir o doc 12 a partir da Rodada 2 (P1/P2 + baseline + stress), depois
consolidação de arquitetura, Places/KIO e o framework de gadgets.
