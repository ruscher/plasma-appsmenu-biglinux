/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Games — one card that holds several small games, with a selector.

    Five separate gadgets would have crowded the gallery for no benefit, so
    they live behind one entry and share the card, the settings dialog and the
    host. Each game is an Item in items/games/ that receives `host` and owns
    its own keys inside `host.cfg`; the 2048 board keeps the `best` key it
    always had, so a score saved before this reorganisation is still there.

    Everything here — rules, boards and puzzles — is written for this project.
    No third-party code, art or sound is bundled, and the games inspired by
    commercial products carry generic names and mechanics implemented from
    scratch, which is why they are "Flow Connect" and "Block Puzzle".
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import ".." as G

Item {
    id: games
    required property var host

    /*  Every game plays at every size, 1x1 included: each one carries its
        own compact layout (see the `compact` property they all read) rather
        than a minimum card size. The earlier `minRows` gate is gone.  */
    readonly property var catalogue: [
        { id: "2048",   name: i18n("2048"),          source: "games/Game2048.qml",    icon: "view-grid-symbolic" },
        { id: "mines",  name: i18n("Minesweeper"),   source: "games/Minesweeper.qml", icon: "dialog-warning-symbolic" },
        { id: "sudoku", name: i18n("Sudoku"),        source: "games/Sudoku.qml",      icon: "view-list-details-symbolic" },
        { id: "flow",   name: i18nc("a game about joining pairs of dots with paths", "Flow Connect"), source: "games/FlowConnect.qml", icon: "draw-path-symbolic" },
        { id: "blocks", name: i18nc("a game about dropping blocks to clear lines", "Block Puzzle"),  source: "games/BlockPuzzle.qml",  icon: "view-grid-symbolic" }
    ]

    readonly property int currentIndex: {
        const want = String(host.cfg.game || "2048")
        for (let i = 0; i < catalogue.length; i++) {
            if (catalogue[i].id === want) {
                return i
            }
        }
        return 0
    }
    readonly property var game: catalogue[currentIndex]
    /*  On a 1x1 card the strip would eat a quarter of the height, so the
        switcher moves into the title bar as a menu and the board gets the
        whole card. Larger cards keep the strip, which is quicker to scan.  */
    readonly property bool compact: host.compact

    /*  A game may publish its own options — difficulty, mostly — as a
        `gameSettings` Component; the shared dialog then shows them under the
        game picker instead of every game needing its own gadget.  */
    readonly property var currentGameSettings: board.item && board.item.gameSettings
        ? board.item.gameSettings : null

    Component.onCompleted: {
        host.accentColor = "#a855f7"
        host.settingsComponent = settings
        publishActions()
    }

    /*  The title bar shows the game switcher (compact only) followed by the
        actions the current game publishes — New game, Undo, pencil marks —
        so a compact card keeps its controls without spending board space on
        them. Games expose them as `titleActions`; the container merges.  */
    function publishActions() {
        const own = compact ? [switchAction] : []
        const theirs = board.item && board.item.titleActions ? board.item.titleActions : []
        host.titleActions = own.concat(theirs)
    }
    onCompactChanged: publishActions()

    QQC2.Action {
        id: switchAction
        text: i18nc("@action:button choose another game", "Switch game")
        icon.name: "view-more-symbolic"
        onTriggered: switchMenu.popup()
    }
    QQC2.Menu {
        id: switchMenu
        Repeater {
            model: games.catalogue
            delegate: QQC2.MenuItem {
                required property var modelData
                required property int index
                text: modelData.name
                checkable: true
                checked: index === games.currentIndex
                onTriggered: games.host.setCfg("game", modelData.id)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        /*  The same scrolling strip the news sources use, so five games never
            squeeze each other into illegibility on a narrow card. */
        G.GadgetTabStrip {
            visible: !games.compact
            Layout.fillWidth: true
            model: games.catalogue
            currentIndex: games.currentIndex
            onActivated: index => games.host.setCfg("game", games.catalogue[index].id)
        }

        /*  setSource rather than a `source` binding: a game declaring
            `required property var host` cannot have it assigned after
            creation, and assigning in onLoaded is already too late — the
            board would fail to load with no visible reason.  */
        Loader {
            id: board

            Layout.fillWidth: true
            Layout.fillHeight: true

            function reload() {
                setSource(games.game.source, { "host": games.host })
            }

            Component.onCompleted: reload()
            onLoaded: games.publishActions()
        }

        Connections {
            target: games
            function onGameChanged() { board.reload() }
        }
        Connections {
            target: board.item
            ignoreUnknownSignals: true
            function onTitleActionsChanged() { games.publishActions() }
        }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.ComboBox {
                    Kirigami.FormData.label: i18n("Game:")
                    model: games.catalogue.map(g => g.name)
                    currentIndex: games.currentIndex
                    onActivated: host.setCfg("game", games.catalogue[currentIndex].id)
                }
            }

            Kirigami.Separator {
                visible: gameOptions.active
                Layout.fillWidth: true
                opacity: 0.3
            }
            Loader {
                id: gameOptions
                Layout.fillWidth: true
                active: !!games.currentGameSettings
                sourceComponent: games.currentGameSettings
                onLoaded: if (item) { item.host = host }
            }

            PC3.Label {
                text: i18n("Each game keeps its own difficulty and best score. All of them are written for BigLinux and use no third-party artwork.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
        }
    }
}
