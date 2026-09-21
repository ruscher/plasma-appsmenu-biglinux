/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Minesweeper — rules implemented from scratch; no third-party code or art.

    Mines are laid *after* the first click, excluding that cell and its
    neighbours, so an opening move can never lose and never reveals a single
    lonely number.

    cfg: { minesLevel, minesBest<level> }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: mines
    required property var host

    readonly property var levels: ({
        easy:   { cols: 8,  rows: 8,  mines: 10 },
        medium: { cols: 10, rows: 10, mines: 18 },
        hard:   { cols: 12, rows: 12, mines: 30 }
    })
    readonly property string level: {
        const l = String(host.cfg.minesLevel || "easy")
        return levels[l] ? l : "easy"
    }
    readonly property var cfgLevel: levels[level]
    readonly property int cols: cfgLevel.cols
    readonly property int rows: cfgLevel.rows
    readonly property int mineCount: cfgLevel.mines

    /*  Per cell: 0 unrevealed, 1 revealed, 2 flagged. `counts` holds -1 for a
        mine and otherwise the number of neighbouring mines.  */
    property var state: []
    property var counts: []
    property bool laid: false
    property bool lost: false
    property bool won: false
    property int revealed: 0
    property int flags: 0

    readonly property int remaining: mineCount - flags
    readonly property bool finished: lost || won

    Component.onCompleted: {
        host.accentColor = "#ef4444"
        reset()
    }
    onLevelChanged: reset()

    Binding {
        target: mines.host
        property: "subtitle"
        value: mines.won ? i18n("Cleared!")
             : (mines.lost ? i18n("Boom") : i18np("%1 mine left", "%1 mines left", mines.remaining))
    }

    function idx(c, r) { return r * cols + c }
    function inside(c, r) { return c >= 0 && r >= 0 && c < cols && r < rows }

    function reset() {
        const n = cols * rows
        state = new Array(n).fill(0)
        counts = new Array(n).fill(0)
        laid = false; lost = false; won = false
        revealed = 0; flags = 0
    }

    /*  Lay the mines away from the first click and its neighbours. */
    function lay(safeC, safeR) {
        const n = cols * rows
        const c2 = new Array(n).fill(0)
        const banned = {}
        for (let dc = -1; dc <= 1; dc++) {
            for (let dr = -1; dr <= 1; dr++) {
                if (inside(safeC + dc, safeR + dr)) {
                    banned[idx(safeC + dc, safeR + dr)] = true
                }
            }
        }
        const spots = []
        for (let i = 0; i < n; i++) {
            if (!banned[i]) {
                spots.push(i)
            }
        }
        for (let k = 0; k < mineCount && spots.length; k++) {
            const pick = Math.floor(Math.random() * spots.length)
            c2[spots[pick]] = -1
            spots.splice(pick, 1)
        }
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                if (c2[idx(c, r)] === -1) {
                    continue
                }
                let k = 0
                for (let dc = -1; dc <= 1; dc++) {
                    for (let dr = -1; dr <= 1; dr++) {
                        if (inside(c + dc, r + dr) && c2[idx(c + dc, r + dr)] === -1) {
                            k++
                        }
                    }
                }
                c2[idx(c, r)] = k
            }
        }
        counts = c2
        laid = true
    }

    /*  Iterative flood fill — a recursive one would risk the stack on a large
        empty region.  */
    function reveal(c, r) {
        if (finished || !inside(c, r)) {
            return
        }
        if (!laid) {
            lay(c, r)
        }
        const st = state.slice()
        if (st[idx(c, r)] !== 0) {
            return
        }
        if (counts[idx(c, r)] === -1) {
            st[idx(c, r)] = 1
            state = st
            lost = true
            return
        }
        const queue = [[c, r]]
        let opened = 0
        while (queue.length) {
            const [cc, rr] = queue.pop()
            const i = idx(cc, rr)
            if (st[i] !== 0) {
                continue
            }
            st[i] = 1
            opened++
            if (counts[i] === 0) {
                for (let dc = -1; dc <= 1; dc++) {
                    for (let dr = -1; dr <= 1; dr++) {
                        if (inside(cc + dc, rr + dr) && st[idx(cc + dc, rr + dr)] === 0) {
                            queue.push([cc + dc, rr + dr])
                        }
                    }
                }
            }
        }
        state = st
        revealed += opened
        if (revealed === cols * rows - mineCount) {
            won = true
            recordBest()
        }
    }

    function flag(c, r) {
        if (finished || !inside(c, r)) {
            return
        }
        const i = idx(c, r)
        if (state[i] === 1) {
            return
        }
        const st = state.slice()
        st[i] = st[i] === 2 ? 0 : 2
        flags += st[i] === 2 ? 1 : -1
        state = st
    }

    function recordBest() {
        const key = "minesBest" + level
        const prev = Number(host.cfg[key] || 0)
        host.setCfg(key, prev + 1)
    }

    /*  Shown by GamesGadget under the game picker. */
    property Component gameSettings: Component {
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.ComboBox {
                    Kirigami.FormData.label: i18n("Difficulty:")
                    model: [
                        i18nc("@item:inlistbox minesweeper difficulty", "Easy — 8×8, 10 mines"),
                        i18nc("@item:inlistbox minesweeper difficulty", "Medium — 10×10, 18 mines"),
                        i18nc("@item:inlistbox minesweeper difficulty", "Hard — 12×12, 30 mines")
                    ]
                    readonly property var keys: ["easy", "medium", "hard"]
                    currentIndex: Math.max(0, keys.indexOf(mines.level))
                    onActivated: host.setCfg("minesLevel", keys[currentIndex])
                }
            }
            PC3.Label {
                text: i18np("%1 game won so far.", "%1 games won so far.",
                            Number(host.cfg["minesBest" + mines.level] || 0))
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }

    readonly property var numberColours: [
        "transparent", "#3b82f6", "#16a34a", "#ef4444", "#7c3aed",
        "#b45309", "#0891b2", "#334155", "#64748b"
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: mines.won ? i18n("You cleared it")
                                : (mines.lost ? i18n("You hit a mine") : "")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: mines.won ? Kirigami.Theme.positiveTextColor
                                 : Kirigami.Theme.negativeTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                onClicked: mines.reset()
                Accessible.name: i18n("New game")
                PC3.ToolTip.text: i18n("New game")
                PC3.ToolTip.visible: hovered
            }
        }

        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cell: Math.max(6, Math.floor(
                Math.min(width / mines.cols, height / mines.rows)))
            readonly property real bw: cell * mines.cols
            readonly property real bh: cell * mines.rows

            Grid {
                id: grid
                anchors.centerIn: parent
                width: boardBox.bw
                height: boardBox.bh
                columns: mines.cols
                rows: mines.rows

                Repeater {
                    model: mines.cols * mines.rows

                    delegate: Rectangle {
                        id: cellItem
                        required property int index
                        readonly property int cx: index % mines.cols
                        readonly property int cy: Math.floor(index / mines.cols)
                        readonly property int st: mines.state[index] || 0
                        readonly property int value: mines.counts[index] || 0
                        readonly property bool showMine: mines.lost && value === -1

                        width: boardBox.cell
                        height: boardBox.cell
                        color: st === 1 || showMine
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.06)
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                              Kirigami.Theme.backgroundColor.g,
                                              Kirigami.Theme.backgroundColor.b, 0.8)

                        PC3.Label {
                            anchors.centerIn: parent
                            font.pointSize: Math.max(5, boardBox.cell * 0.42)
                            font.weight: Font.Bold
                            text: {
                                if (cellItem.st === 2) {
                                    return "⚑"
                                }
                                if (cellItem.showMine) {
                                    return "✸"
                                }
                                if (cellItem.st !== 1) {
                                    return ""
                                }
                                return cellItem.value > 0 ? String(cellItem.value) : ""
                            }
                            color: cellItem.st === 2 ? Kirigami.Theme.neutralTextColor
                                 : (cellItem.showMine ? Kirigami.Theme.negativeTextColor
                                 : mines.numberColours[Math.max(0, Math.min(8, cellItem.value))])
                        }

                        /*  Mouse, touch and long press all reach the same two
                            actions: reveal and flag.  */
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    mines.flag(cellItem.cx, cellItem.cy)
                                } else {
                                    mines.reveal(cellItem.cx, cellItem.cy)
                                }
                            }
                            onPressAndHold: mines.flag(cellItem.cx, cellItem.cy)
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: cellItem.st === 2
                            ? i18nc("@info:whatsthis minesweeper cell", "Flagged cell")
                            : (cellItem.st === 1
                               ? i18np("Revealed cell, %1 mine nearby", "Revealed cell, %1 mines nearby", cellItem.value)
                               : i18nc("@info:whatsthis minesweeper cell", "Hidden cell"))
                    }
                }
            }
        }
    }
}
