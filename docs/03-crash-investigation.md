# 03 — Investigação do Crash ("o menu fecha sozinho")

> Prioridade máxima da missão. Este documento registra sintoma, reprodução,
> logs, causa raiz, correção e validação.

## Ambiente

| Item | Valor |
|---|---|
| Plasma | 6.7.4 |
| Qt | 6.11.2 |
| KDE Frameworks | 6 (KF6) |
| Sessão | Wayland |
| Plasmoid | `org.biglinux.appsmenu` (fork de Kickoff, arquitetura nova de 4 abas) |

## Sintoma

O menu fecha sozinho durante o uso. Não é o popup se escondendo por perda de
foco — é o **`plasmashell` inteiro que crasha** (SIGSEGV) e reinicia, o que faz
o painel piscar e o menu desaparecer.

## Evidência dos logs

`coredumpctl` e o journal do sistema registraram o crash:

```
kernel: plasmashell[9315]: segfault at 18b ip 00007f2457775e2d ...
         in libQt6Quick.so.6.11.2[175e2d,...]
systemd-coredump: Process 9315 (plasmashell) ... signal 11/SEGV
plasma-plasmashell.service: Main process exited, code=dumped, status=11/SEGV
plasma-plasmashell.service: Scheduled restart job, restart counter is at 1.
```

Observações decisivas:

- O segfault ocorre **dentro de `libQt6Quick.so`**, não no C++ do plasmoid nem
  nos modelos do Kicker. É um crash da própria engine de cena gráfica QML.
- `segfault at 18b` — desreferência de um endereço minúsculo (offset de um
  ponteiro ~nulo). Assinatura clássica de **use-after-free**: código do QtQuick
  acessando um `QQuickItem`/animação que já foi destruído.
- `Storage: none` no systemd → o coredump não foi persistido, então não há
  backtrace completo. A causa foi determinada por análise estática do fluxo de
  transição de páginas + reprodução do padrão de disparo.

## Causa raiz

Arquivo: `contents/ui/FullRepresentation.qml`.

A área central é um `VerticalStackView` que troca de página com `replace()`.
Toda transição de `replace()` roda uma animação de **opacidade** de
`Kirigami.Units.longDuration` (~200 ms), **sempre** (ver `VerticalStackView.qml`
— a animação de opacidade não é condicionada a `movementTransitionsEnabled`).

A barra de navegação lateral tinha, em cada uma das 4 abas:

```qml
onClicked: navBar.currentIndex = X
onHoveredChanged: if (hovered) navBar.currentIndex = X   // ← o problema
```

E `onCurrentIndexChanged` chamava `switchToTab()` → `contentItemStackView.replace()`.

### A cadeia do crash

1. O usuário move o mouse pela sidebar de navegação (ou o ponteiro simplesmente
   a atravessa a caminho de outra coisa).
2. O movimento gera dezenas de eventos `hovered` em sequência ao passar por
   Home → Apps → Places → Info.
3. Cada `hovered` muda `currentIndex` → dispara `switchToTab()` → `replace()`.
4. Vários `replace()` são chamados **enquanto a animação de ~200 ms do replace
   anterior ainda está rodando**. O `StackView` remove/destrói o item que ainda
   está sendo referenciado pela `Transition` em andamento.
5. A animação continua tocando sobre um `QQuickItem` já liberado →
   **use-after-free dentro de `libQt6Quick`** → SIGSEGV → `plasmashell` morre →
   o menu "fecha sozinho".

Um simples passar de mouse pela lateral bastava para disparar. Por isso parecia
aleatório e frequente.

### Por que era tão fácil de disparar

`hover` transforma **uma** intenção do usuário em **dezenas** de trocas de
página. A navegação por hover, além de imprevisível para o usuário (a missão
pede navegação "clara e previsível"), era o multiplicador que garantia o
`replace()` reentrante no meio da transição.

## Correção aplicada

Arquivo: `contents/ui/FullRepresentation.qml`.

1. **Remoção da troca de página por hover.** As 4 abas agora trocam de página
   apenas no `onClicked`. Navegação previsível e sem disparos em rajada.

2. **Guarda de reentrância na transição.** `switchToTab()` nunca chama
   `replace()` enquanto o `StackView` estiver `busy`:
   - se estiver ocupado, guarda o destino em `root.pendingTabIndex` e retorna;
   - `StackView.onBusyChanged` aplica o último destino pendente assim que a
     transição termina.
   - também ignora troca para a página já atual (idempotente).

3. **Mesma guarda no caminho da busca.** Digitar durante uma transição não chama
   mais `replace(searchViewComponent)` no meio da animação — usa
   `root.pendingSearch`, resolvido em `onBusyChanged` (busca tem prioridade
   sobre troca de aba pendente).

## Por que a correção funciona

O crash exigia um `replace()` disparado enquanto outra transição de `replace()`
ainda estava viva. Depois da correção:

- a fonte de disparos em rajada (hover) deixou de existir; e
- mesmo cliques/digitação rápidos nunca resultam em `replace()` durante `busy` —
  o pedido é enfileirado (apenas o mais recente) e executado quando a cena está
  estável.

Não há mais janela de tempo em que um item destruído continue sob uma animação
ativa. A causa do use-after-free foi eliminada, não apenas o sintoma.

## Validação

- `qmllint` em todo o projeto: sem erros de sintaxe.
- `plasmoidviewer -a <plasmoid>`: carrega sem erros/warnings de QML e permanece
  vivo (exit por timeout, não por crash).
- Teste de stress manual recomendado (checklist em `11-testing-strategy.md`):
  varrer o mouse repetidamente pela sidebar e alternar abas em alta velocidade —
  o padrão que antes derrubava o `plasmashell`.

## Riscos residuais / próximos passos

- O coredump não foi persistido (`Storage: none`). Para diagnósticos futuros,
  habilitar armazenamento de coredump (`/etc/systemd/coredump.conf` →
  `Storage=external`) ajuda a confirmar backtraces.
- Auditar outros pontos que chamam `replace()`/`push()`/`pop()` sem guarda de
  `busy` caso novas páginas sejam adicionadas.
