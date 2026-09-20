# 00 — Visão Geral do Projeto

## O que é

`org.biglinux.appsmenu` é um menu de aplicativos (menu iniciar) para KDE Plasma
6 / BigLinux. É um **fork do Kickoff** que está sendo migrado para uma
arquitetura própria de 4 abas: **Home · Apps · Places · Info**.

## Ambiente-alvo (detectado nesta máquina)

| Item | Valor |
|---|---|
| Plasma | 6.7.4 |
| Qt | 6.11.2 |
| KDE Frameworks | 6 |
| Sessão | Wayland |
| Renderização | QtQuick / Kirigami / PlasmaComponents 3 |

## Layout do repositório

```
usr/share/plasma/plasmoids/org.biglinux.appsmenu/
├── metadata.json
└── contents/
    ├── config/            # main.xml (schema), config.qml, ConfigGeneral.qml
    └── ui/
        ├── main.qml               # PlasmoidItem raiz + modelos Kicker
        ├── FullRepresentation.qml # popup: header + StackView + sidebar de abas
        ├── Header.qml             # busca + avatar + power
        ├── HomePage.qml           # favoritos + recentes (apps/arquivos/pastas)
        ├── AllAppsPage.qml        # sidebar de categorias + grid/lista de apps
        ├── InfoPage.qml           # dashboard de sistema/clima/notícias
        ├── SearchResultsPage.qml  # resultados da busca (RunnerModel)
        ├── components/            # views acessíveis, drag&drop, power menu…
        ├── delegates/             # AppDelegate (item unificado grid/lista)
        ├── singletons/            # MenuSingleton, ActionMenuSingleton
        └── code/tools.js          # utilidades JS
```

## Estado atual (importante)

O projeto está em **migração pela metade**: a arquitetura nova (Home/Apps/
Places/Info + `components/`, `delegates/`, `singletons/`) está **ativa e
acessível** a partir de `main.qml → FullRepresentation.qml`. Ao mesmo tempo:

- Parte da pilha antiga do Kickoff **ainda é usada** (via `AllAppsPage`:
  `ListOfGridsView`, `SectionView`, `KickoffListView/GridView`, delegates antigos,
  `KickoffSingleton`, `ActionMenu`).
- Vários arquivos são **código morto** (ver `02-code-audit.md`).
- Existem **dois sistemas de singleton duplicados** rodando ao mesmo tempo
  (`KickoffSingleton` + `MenuSingleton`; `ActionMenu` + `ActionMenuSingleton`).

Isso não é apenas estética: dobra alguns recursos (DataSources, FrameSvgItems) e
aumenta a superfície de bugs.

## Como testar/desenvolver

Do `instrucoes.txt` do projeto:

```bash
# Rodar o plasmoid isolado (não afeta o painel)
plasmoidviewer -a /caminho/.../org.biglinux.appsmenu

# Acompanhar logs
journalctl -f | grep org.biglinux.appsmenu

# Recarregar o shell (afeta a sessão ao vivo)
kquitapp6 plasmashell && kstart6 plasmashell
```

O plasmoid instalado do usuário vive em
`~/.local/share/plasma/plasmoids/org.biglinux.appsmenu` (cópia independente do
repo — não é symlink). Para testar as correções na sessão real é preciso
sincronizar essa cópia com o repo e recarregar o shell.

## Prioridades da missão (ordem)

1. **Correção** (crash — ver `03-crash-investigation.md`) ✅
2. **Estabilidade** (lifecycle/QML/modelos — `04-stability-plan.md`)
3. **Performance** (`10-performance-plan.md`)
4. **Arquitetura** (consolidar migração — `01`, `12`)
5. **Funcionalidades** (Home/Apps/Places/Info + gadgets — `05`–`08`)
6. **Efeitos visuais** (`09-ux-ui-plan.md`)

> Estes documentos são de planejamento/auditoria. Nenhum `.md` em `docs/` é
> necessário para o plasmoid funcionar.
