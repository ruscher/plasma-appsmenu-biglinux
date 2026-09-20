/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    2048 — arrow keys or swipe. No timers; nothing runs while idle.
    cfg: { best }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: game
    required property var host

    property var board: []        // 16 ints (0 = empty)
    property int score: 0
    property bool over: false
    property bool won: false
    readonly property int best: host.cfg.best || 0

    Component.onCompleted: { host.accent = "#eab308"; reset() }
    Binding { target: game.host; property: "subtitle"; value: i18n("Best %1", game.best) }

    function reset() {
        board = new Array(16).fill(0); score = 0; over = false; won = false
        spawn(); spawn()
    }
    function spawn() {
        const empty = []
        for (let i = 0; i < 16; i++) if (board[i] === 0) empty.push(i)
        if (!empty.length) return
        const b = board.slice()
        b[empty[Math.floor(Math.random() * empty.length)]] = Math.random() < 0.9 ? 2 : 4
        board = b
    }
    function slideRow(row) {   // returns { row, gained, moved }
        const nz = row.filter(v => v !== 0)
        const out = []; let gained = 0
        for (let i = 0; i < nz.length; i++) {
            if (i + 1 < nz.length && nz[i] === nz[i + 1]) { out.push(nz[i] * 2); gained += nz[i] * 2; i++ }
            else out.push(nz[i])
        }
        while (out.length < 4) out.push(0)
        let moved = false
        for (let i = 0; i < 4; i++) if (out[i] !== row[i]) moved = true
        return { row: out, gained: gained, moved: moved }
    }
    function move(dir) {   // 0 left, 1 right, 2 up, 3 down
        if (over) return
        const b = board.slice(); let moved = false, gained = 0
        for (let k = 0; k < 4; k++) {
            let idx = []
            for (let i = 0; i < 4; i++) idx.push(dir < 2 ? k * 4 + i : i * 4 + k)
            if (dir === 1 || dir === 3) idx = idx.reverse()
            const r = slideRow(idx.map(i => b[i]))
            if (r.moved) moved = true
            gained += r.gained
            for (let i = 0; i < 4; i++) b[idx[i]] = r.row[i]
        }
        if (!moved) return
        board = b; score += gained
        if (score > best) host.setCfg("best", score)
        if (!won && b.indexOf(2048) >= 0) won = true
        spawn()
        if (!canMove()) over = true
    }
    function canMove() {
        for (let i = 0; i < 16; i++) {
            if (board[i] === 0) return true
            const r = Math.floor(i / 4), c = i % 4
            if (c < 3 && board[i] === board[i + 1]) return true
            if (r < 3 && board[i] === board[i + 4]) return true
        }
        return false
    }
    function tileColor(v) {
        const map = { 2: "#eee4da", 4: "#ede0c8", 8: "#f2b179", 16: "#f59563", 32: "#f67c5f", 64: "#f65e3b", 128: "#edcf72", 256: "#edcc61", 512: "#edc850", 1024: "#edc53f", 2048: "#edc22e" }
        return map[v] || "#3c3a32"
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { move(0); event.accepted = true }
        else if (event.key === Qt.Key_Right) { move(1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { move(2); event.accepted = true }
        else if (event.key === Qt.Key_Down) { move(3); event.accepted = true }
        else if (event.key === Qt.Key_R) { reset(); event.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label { text: i18n("Score %1", game.score); font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                icon.name: "view-refresh"; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: game.reset(); Accessible.name: i18n("New game")
                PC3.ToolTip.text: i18n("New game (R)"); PC3.ToolTip.visible: hovered
            }
        }

        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real s: Math.min(width, height)
            readonly property real gap: Math.max(3, s * 0.03)
            readonly property real cell: (s - gap * 5) / 4

            Rectangle {
                width: boardBox.s; height: boardBox.s
                anchors.centerIn: parent
                radius: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                Repeater {
                    model: 16
                    delegate: Rectangle {
                        required property int index
                        readonly property int value: game.board[index] || 0
                        x: boardBox.gap + (index % 4) * (boardBox.cell + boardBox.gap)
                        y: boardBox.gap + Math.floor(index / 4) * (boardBox.cell + boardBox.gap)
                        width: boardBox.cell; height: boardBox.cell
                        radius: Math.max(2, boardBox.cell * 0.12)
                        color: value ? game.tileColor(value) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
                        Behavior on color { ColorAnimation { duration: 90 } }
                        onValueChanged: if (value) popAnim.restart()
                        SequentialAnimation {
                            id: popAnim
                            NumberAnimation { target: tileText; property: "scale"; to: 1.18; duration: 70 }
                            NumberAnimation { target: tileText; property: "scale"; to: 1; duration: 90; easing.type: Easing.OutBack }
                        }
                        PC3.Label {
                            id: tileText
                            anchors.centerIn: parent
                            text: parent.value ? parent.value : ""
                            font.pointSize: Math.max(6, boardBox.cell * (parent.value >= 1000 ? 0.28 : parent.value >= 100 ? 0.34 : 0.42))
                            font.weight: Font.Bold
                            color: parent.value <= 4 ? "#776e65" : "#f9f6f2"
                        }
                    }
                }

                // swipe
                MouseArea {
                    anchors.fill: parent
                    property real sx: 0; property real sy: 0
                    onPressed: mouse => { sx = mouse.x; sy = mouse.y; game.forceActiveFocus() }
                    onReleased: mouse => {
                        const dx = mouse.x - sx, dy = mouse.y - sy
                        if (Math.max(Math.abs(dx), Math.abs(dy)) < 18) return
                        if (Math.abs(dx) > Math.abs(dy)) game.move(dx > 0 ? 1 : 0); else game.move(dy > 0 ? 3 : 2)
                    }
                }

                // overlay: game over / won
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: game.over || game.won
                    ColumnLayout {
                        anchors.centerIn: parent
                        PC3.Label {
                            text: game.won ? i18n("You made 2048! 🎉") : i18n("Game over")
                            color: "white"; font.weight: Font.Bold; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PC3.Button {
                            text: game.won && !game.over ? i18n("Keep going") : i18n("Play again")
                            Layout.alignment: Qt.AlignHCenter
                            onClicked: game.won && !game.over ? (game.won = false) : game.reset()
                        }
                    }
                }
            }
        }
    }
}
