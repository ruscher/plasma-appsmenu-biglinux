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

    /*  `minCols`/`minRows` are the smallest card each game is playable on.
        A Sudoku squeezed into 1×1 would be unreadable, so it says so rather
        than drawing something nobody can use.  */
    readonly property var catalogue: [
        { id: "2048",   name: i18n("2048"),          source: "games/Game2048.qml",   minCols: 1, minRows: 2 },
        { id: "mines",  name: i18n("Minesweeper"),   source: "games/Minesweeper.qml", minCols: 1, minRows: 2 },
        { id: "sudoku", name: i18n("Sudoku"),        source: "games/Sudoku.qml",     minCols: 2, minRows: 2 },
        { id: "flow",   name: i18nc("a game about joining pairs of dots with paths", "Flow Connect"), source: "games/FlowConnect.qml", minCols: 1, minRows: 2 },
        { id: "blocks", name: i18nc("a game about dropping blocks to clear lines", "Block Puzzle"),  source: "games/BlockPuzzle.qml",  minCols: 1, minRows: 2 }
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
    readonly property bool fits: host.cols >= game.minCols && host.rows >= game.minRows

    /*  A game may publish its own options — difficulty, mostly — as a
        `gameSettings` Component; the shared dialog then shows them under the
        game picker instead of every game needing its own gadget.  */
    readonly property var currentGameSettings: board.item && board.item.gameSettings
        ? board.item.gameSettings : null

    Component.onCompleted: {
        host.accentColor = "#a855f7"
        host.settingsComponent = settings
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        /*  The same scrolling strip the news sources use, so five games never
            squeeze each other into illegibility on a narrow card. */
        G.GadgetTabStrip {
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
                if (games.fits) {
                    setSource(games.game.source, { "host": games.host })
                } else {
                    source = ""
                }
            }

            Component.onCompleted: reload()
        }

        Connections {
            target: games
            function onGameChanged() { board.reload() }
            function onFitsChanged() { board.reload() }
        }

        /*  Too small for this game: say so and offer the way out, rather than
            drawing a board nobody can read. */
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !games.fits

            Item { Layout.fillHeight: true }
            Kirigami.Icon {
                source: "zoom-in"
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.45
            }
            PC3.Label {
                text: i18n("%1 needs a bigger card. Resize this gadget to play.", games.game.name)
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
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
