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

## Rodada 2 — Estabilização P1/P2 (parcial ✅)
- [x] Guardas: `AllAppsPage` pós-pop + 2ª instância do crash hover→replace,
      `SearchResultsPage` root.parent, `AbstractKickoffItemDelegate`,
      `SectionView.onCompleted`.
- [x] Baseline de estabilidade/recursos ao vivo (doc 10). Deploy + restart OK.
- [ ] Contrato de `contentArea` (Enter lança 1º resultado na busca). — P2 pendente
- [ ] Baseline **instrumentado** de latência (abertura/busca) — pendente (Rodada 3).
- [ ] Teste de stress interativo na sessão real (checklist doc 11) — cabe ao usuário.

## Rodada 3 — Consolidação da arquitetura
- [ ] `AllAppsPage` usando só `AccessibleGridView`+`AppDelegate`.
- [ ] Aposentar stack antiga (KickoffSingleton/ActionMenu/Kickoff*Delegate).
- [ ] Unificar singletons (um só de métricas, um só de menu de contexto).
- [ ] Remover código morto (commit isolado; lista no doc 02).

## Rodada 4 — Places com KIO
- [ ] Extrair Places para arquivo próprio.
- [ ] Integrar `KFilePlacesModel` (Computer/Devices/Network/Remote por eventos).

## Rodada 4 (executada) — UX + Fundação de Gadgets + gadgets locais e online ✅
- [x] Lembrar aba/categoria; pastas recentes; sidebar Apps = Places; power
      buttons; avatar grande → pasta pessoal.
- [x] `GadgetRegistry` + `GadgetHost` (isolamento de falhas) + `GadgetGrid`
      (drag/drop, reorganização, auto-scroll) + galeria + configurações +
      persistência via `Plasmoid.configuration`. Pausa quando invisível.
- [x] Gadgets locais sem shell: Clock, Calendar, Countdown, Notes, CPU,
      Memory, Battery, Drive Info, Drive Monitor, Network, System Info,
      Media (MPRIS), Clipboard (Klipper), Quick Links, Quotes, Tips, Gallery, 2048.
- [x] Rede compartilhada (`GadgetNet.js`) + providers: Weather (Open-Meteo),
      Currency (Frankfurter), RSS/Atom, Sports (TheSportsDB).

## Pendências do Info (próximas)
- [ ] Testes interativos pelo usuário: arrastar/soltar, redimensionar, editar
      feeds/links/eventos, settings de cada gadget (o Wayland impede automatizar).
- [ ] Reordenação por teclado (mover ↑↓←→ no modo edição) — acessibilidade.
- [ ] Drive Info: mostrar ponto de montagem (o sensor só expõe o rótulo).
- [ ] Sports: mais ligas (Libertadores/Copa do Brasil — ids a confirmar) e
      minuto ao vivo para esportes além do futebol.

## Rodada 8 — UX/UI + performance + testes finais
- [ ] Tema (remover cores hardcoded), animações, acessibilidade completa.
- [ ] Otimizações medidas (doc 10). Testes automatizados mínimos (doc 11).
- [ ] Relatório final (doc 14).
