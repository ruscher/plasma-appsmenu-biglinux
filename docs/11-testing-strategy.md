# 11 — Estratégia de Testes

## Ferramentas disponíveis nesta máquina
- `qmllint` (`/usr/sbin/qmllint`) — checagem de sintaxe/erros. **Usado**.
- `plasmoidviewer` (`/usr/sbin/plasmoidviewer`) — roda o plasmoid isolado.
  ⚠️ Esta versão **não** aceita `--width/--height`. **Usado**.
- `plasmawindowed` — alternativa.
- `journalctl` / `coredumpctl` — logs e crashes. **Usados**.

## Validação já executada
- `qmllint --bare` em **todos** os `.qml` do projeto: sem erros de sintaxe.
- `plasmoidviewer -a <plasmoid>`: carrega sem erros/warnings de QML e permanece
  vivo (não crasha na inicialização) após as correções.

## Teste de stress manual (rodar na sessão real)
Sincronizar o repo → `~/.local/share/plasma/plasmoids/org.biglinux.appsmenu` e
`kquitapp6 plasmashell && kstart6 plasmashell`, depois:

Checklist:
```
[ ] abrir / fechar o menu ~100×
[ ] varrer o mouse repetidamente pela sidebar de abas (padrão que crashava)
[ ] alternar Home ↔ Apps ↔ Places ↔ Info ~100× em alta velocidade
[ ] digitar/apagar busca repetidamente durante transições
[ ] abrir apps a partir de Home/Apps/Busca
[ ] adicionar/remover/reordenar favoritos
[ ] arquivos/pastas recentes: abrir
[ ] Info: abrir, clicar engrenagem, copiar data, links rápidos
[ ] deixar Info aberto vários minutos (observar RAM/processos)
[ ] reiniciar plasmashell e confirmar que config persistiu
[ ] Wayland (atual) e X11 quando disponível
[ ] escalas 100/125/150/200%
```
Monitorar em paralelo: `journalctl -f | grep appsmenu` e
`watch -n2 'ps -o rss,pcpu -p $(pgrep -x plasmashell)'`.

## Testes automatizados (futuro)
- `qmltestrunner` para lógica pura de `tools.js` (favoritos, ranking) e providers
  de gadgets (sucesso/timeout/offline/JSON inválido) usando fixtures — sem
  depender de API real.
- Não montar infraestrutura pesada além do necessário.
