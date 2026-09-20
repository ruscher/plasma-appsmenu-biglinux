# 12 — Roadmap de Implementação

Ordem que respeita a prioridade da missão (correção → estabilidade → performance
→ arquitetura → funcionalidades → visual). Estado no fim de cada rodada.

## Rodada 1 — Correção do crash + estabilização inicial ✅ (esta)
- [x] Git seguro: branch `feature/rafael-personal-menu`, `main` intacta.
- [x] Engenharia reversa + mapa da arquitetura (docs 00–02).
- [x] Causa raiz do crash identificada e corrigida (doc 03).
- [x] Correções de estabilidade P0 (AppDelegate, InfoPage action, leaks).
- [x] Validação por `qmllint` + `plasmoidviewer`.
- [x] Documentação de auditoria/planos (docs 00–14).

## Rodada 2 — Estabilização P1/P2
- [ ] Guardas: `AllAppsPage` pós-pop, `SearchResultsPage` root.parent,
      `AbstractKickoffItemDelegate`, `SectionView.onCompleted`.
- [ ] Contrato de `contentArea` (Enter lança 1º resultado na busca).
- [ ] Baseline de performance (doc 10) — medir antes das otimizações.
- [ ] Teste de stress na sessão real (doc 11) e registrar resultado no doc 13.

## Rodada 3 — Consolidação da arquitetura
- [ ] `AllAppsPage` usando só `AccessibleGridView`+`AppDelegate`.
- [ ] Aposentar stack antiga (KickoffSingleton/ActionMenu/Kickoff*Delegate).
- [ ] Unificar singletons (um só de métricas, um só de menu de contexto).
- [ ] Remover código morto (commit isolado; lista no doc 02).

## Rodada 4 — Places com KIO
- [ ] Extrair Places para arquivo próprio.
- [ ] Integrar `KFilePlacesModel` (Computer/Devices/Network/Remote por eventos).

## Rodada 5 — Fundação de Gadgets (Info)
- [ ] `GadgetManager` + `GadgetHost` (isolamento de falhas) + `GadgetGrid`
      (drag/drop, colisão, snap) + persistência via `Plasmoid.configuration`.
- [ ] Migrar 2 gadgets locais (Clock, DriveInfo) para dados **sem shell**
      (Qt/Solid). Lazy load + pause quando invisível.

## Rodada 6 — Gadgets locais restantes
- [ ] Calendar, Notes, CpuMeter (KSystemStats), Battery (Solid/UPower),
      Clipboard (Klipper/DBus), Countdown, MediaControls (MPRIS), DriveMonitor.

## Rodada 7 — Gadgets online (providers)
- [ ] Infra de rede compartilhada (timeout/retry/cache/offline).
- [ ] Weather, Currency, RSS, Sports, Quotes/Tips — providers desacoplados,
      sem API keys no repo, degradação graciosa offline.

## Rodada 8 — UX/UI + performance + testes finais
- [ ] Tema (remover cores hardcoded), animações, acessibilidade completa.
- [ ] Otimizações medidas (doc 10). Testes automatizados mínimos (doc 11).
- [ ] Relatório final (doc 14).
