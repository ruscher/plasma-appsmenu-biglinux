/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    2048 — play with the on-screen arrows, by swiping, or with the keyboard.
    Tiles are kept as individual items so they slide and merge instead of
    blinking into place. No timers; nothing runs while the menu is closed.

    Loaded by GamesGadget. It keeps its original `cfg.best` key so a high
    score saved before the games were gathered under one gadget survives.

    cfg: { best }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: game
    required property var host

    property int score: 0
    property bool over: false
    property bool won: false
    property bool keepPlaying: false
    property int nextId: 1
    readonly property int best: host.cfg.best || 0
    // one level of undo, captured before each move
    property var undoState: null

    Component.onCompleted: { host.accentColor = "#eab308"; reset() }
    Binding { target: game.host; property: "subtitle"; value: i18n("Best %1", game.best) }

    // ── model: one entry per tile, positioned by row/col ──
    ListModel { id: tiles }

    function reset() {
        tiles.clear()
        score = 0; over = false; won = false; keepPlaying = false
        undoState = null
        nextId = 1
        spawn(); spawn()
    }

    function occupied() {
        const g = new Array(16).fill(-1)
        for (let i = 0; i < tiles.count; i++) {
            const t = tiles.get(i)
            if (!t.dead) g[t.row * 4 + t.col] = i
        }
        return g
    }

    function spawn() {
        const g = occupied()
        const free = []
        for (let i = 0; i < 16; i++) if (g[i] < 0) free.push(i)
        if (!free.length) return
        const at = free[Math.floor(Math.random() * free.length)]
        tiles.append({
            tid: nextId++,
            val: Math.random() < 0.9 ? 2 : 4,
            row: Math.floor(at / 4), col: at % 4,
            dead: false, merged: false, fresh: true
        })
    }

    function snapshot() {
        const list = []
        for (let i = 0; i < tiles.count; i++) {
            const t = tiles.get(i)
            if (!t.dead) list.push({ val: t.val, row: t.row, col: t.col })
        }
        return { list: list, score: score }
    }

    function restore(state) {
        tiles.clear()
        for (let i = 0; i < state.list.length; i++) {
            const t = state.list[i]
            tiles.append({ tid: nextId++, val: t.val, row: t.row, col: t.col, dead: false, merged: false, fresh: false })
        }
        score = state.score
        over = false
    }

    function undo() {
        if (!undoState) return
        restore(undoState)
        undoState = null
    }

    // dir: 0 left, 1 right, 2 up, 3 down
    function move(dir) {
        if (over && !won) return
        const before = snapshot()
        const g = occupied()
        let moved = false, gained = 0
        const dead = []

        for (let line = 0; line < 4; line++) {
            // cell indexes along the travel direction, destination first
            let idx = []
            for (let i = 0; i < 4; i++) idx.push(dir < 2 ? line * 4 + i : i * 4 + line)
            if (dir === 1 || dir === 3) idx = idx.reverse()

            // tiles in that order
            const seq = []
            for (let i = 0; i < 4; i++) if (g[idx[i]] >= 0) seq.push(g[idx[i]])

            const packed = []
            let i = 0
            while (i < seq.length) {
                const a = seq[i]
                if (i + 1 < seq.length && tiles.get(a).val === tiles.get(seq[i + 1]).val) {
                    packed.push({ keep: a, eat: seq[i + 1], val: tiles.get(a).val * 2 })
                    gained += tiles.get(a).val * 2
                    i += 2
                } else {
                    packed.push({ keep: a, eat: -1, val: tiles.get(a).val })
                    i += 1
                }
            }

            for (let k = 0; k < packed.length; k++) {
                const target = idx[k]
                const p = packed[k]
                const row = Math.floor(target / 4), col = target % 4
                const keep = tiles.get(p.keep)
                if (keep.row !== row || keep.col !== col) moved = true
                tiles.setProperty(p.keep, "row", row)
                tiles.setProperty(p.keep, "col", col)
                tiles.setProperty(p.keep, "fresh", false)
                if (p.eat >= 0) {
                    // the eaten tile slides onto the survivor, then disappears
                    tiles.setProperty(p.eat, "row", row)
                    tiles.setProperty(p.eat, "col", col)
                    tiles.setProperty(p.eat, "dead", true)
                    tiles.setProperty(p.keep, "val", p.val)
                    tiles.setProperty(p.keep, "merged", true)
                    dead.push(p.eat)
                    moved = true
                }
            }
        }

        if (!moved) return

        undoState = before
        score += gained
        if (score > best) host.setCfg("best", score)
        sweep.start()
    }

    // remove eaten tiles once they have finished sliding, then spawn
    Timer {
        id: sweep
        interval: 130
        onTriggered: {
            for (let i = tiles.count - 1; i >= 0; i--) if (tiles.get(i).dead) tiles.remove(i)
            for (let j = 0; j < tiles.count; j++) tiles.setProperty(j, "merged", false)
            game.spawn()
            if (!game.won && game.hasValue(2048)) game.won = true
            if (!game.canMove()) game.over = true
        }
    }

    function hasValue(v) {
        for (let i = 0; i < tiles.count; i++) if (tiles.get(i).val === v) return true
        return false
    }

    function canMove() {
        const g = occupied()
        for (let i = 0; i < 16; i++) {
            if (g[i] < 0) return true
            const r = Math.floor(i / 4), c = i % 4
            const v = tiles.get(g[i]).val
            if (c < 3 && g[i + 1] >= 0 && tiles.get(g[i + 1]).val === v) return true
            if (r < 3 && g[i + 4] >= 0 && tiles.get(g[i + 4]).val === v) return true
        }
        return false
    }

    function tileColor(v) {
        const map = { 2: "#eee4da", 4: "#ede0c8", 8: "#f2b179", 16: "#f59563", 32: "#f67c5f",
                      64: "#f65e3b", 128: "#edcf72", 256: "#edcc61", 512: "#edc850",
                      1024: "#edc53f", 2048: "#edc22e" }
        return map[v] || "#3c3a32"
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { move(0); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { move(1); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { move(2); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { move(3); event.accepted = true }
        else if (event.key === Qt.Key_R) { reset(); event.accepted = true }
        else if (event.key === Qt.Key_U) { undo(); event.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // ── score row ──
        RowLayout {
            id: scoreRow
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: i18n("Score %1", game.score)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "edit-undo"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                enabled: game.undoState !== null
                onClicked: game.undo()
                Accessible.name: i18n("Undo")
                PC3.ToolTip.text: i18n("Undo (U)"); PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: game.reset()
                Accessible.name: i18n("New game")
                PC3.ToolTip.text: i18n("New game (R)"); PC3.ToolTip.visible: hovered
            }
        }

        // ── board ──
        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 4
            // The arrows live inside this item, right under the board, and the
            // board is shrunk to leave room for them: a card taller than the
            // scrolling viewport would otherwise clip a row of the layout.
            readonly property real dpadHeight: dpad.implicitHeight + Kirigami.Units.smallSpacing
            readonly property real s: Math.max(40, Math.min(width, height - dpadHeight))
            readonly property real gap: Math.max(3, s * 0.03)
            readonly property real cell: (s - gap * 5) / 4

            function px(col) { return boardBox.gap + col * (boardBox.cell + boardBox.gap) }

            Rectangle {
                id: boardBg
                width: boardBox.s; height: boardBox.s
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(0, (boardBox.height - boardBox.s - boardBox.dpadHeight) / 2)
                radius: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                // empty slots
                Repeater {
                    model: 16
                    delegate: Rectangle {
                        required property int index
                        x: boardBox.px(index % 4)
                        y: boardBox.px(Math.floor(index / 4))
                        width: boardBox.cell; height: boardBox.cell
                        radius: Math.max(2, boardBox.cell * 0.12)
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                    }
                }

                // tiles
                Repeater {
                    model: tiles
                    delegate: Rectangle {
                        id: tile
                        required property int tid
                        required property int val
                        required property int row
                        required property int col
                        required property bool dead
                        required property bool merged
                        required property bool fresh

                        x: boardBox.px(col)
                        y: boardBox.px(row)
                        width: boardBox.cell; height: boardBox.cell
                        radius: Math.max(2, boardBox.cell * 0.12)
                        color: game.tileColor(val)
                        z: dead ? 1 : 2
                        antialiasing: true

                        Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 110 } }

                        // new tiles pop in, merged tiles bump
                        scale: 1
                        Component.onCompleted: if (fresh) spawnAnim.start()
                        onMergedChanged: if (merged) mergeAnim.start()
                        NumberAnimation {
                            id: spawnAnim
                            target: tile; property: "scale"; from: 0.1; to: 1
                            duration: 140; easing.type: Easing.OutBack
                        }
                        SequentialAnimation {
                            id: mergeAnim
                            NumberAnimation { target: tile; property: "scale"; to: 1.16; duration: 80 }
                            NumberAnimation { target: tile; property: "scale"; to: 1; duration: 100; easing.type: Easing.OutBack }
                        }

                        PC3.Label {
                            anchors.centerIn: parent
                            text: tile.val
                            font.pointSize: Math.max(6, boardBox.cell * (tile.val >= 1000 ? 0.28 : tile.val >= 100 ? 0.34 : 0.42))
                            font.weight: Font.Bold
                            color: tile.val <= 4 ? "#776e65" : "#f9f6f2"
                        }
                    }
                }

                // swipe — preventStealing keeps the gesture away from the
                // scrolling Flickable the gadget grid lives in
                MouseArea {
                    anchors.fill: parent
                    z: 10
                    preventStealing: true
                    property real sx: 0
                    property real sy: 0
                    onPressed: mouse => { sx = mouse.x; sy = mouse.y; game.forceActiveFocus() }
                    onReleased: mouse => {
                        const dx = mouse.x - sx, dy = mouse.y - sy
                        if (Math.max(Math.abs(dx), Math.abs(dy)) < 16) return
                        if (Math.abs(dx) > Math.abs(dy)) game.move(dx > 0 ? 1 : 0)
                        else game.move(dy > 0 ? 3 : 2)
                    }
                }

                // overlay: game over / won
                Rectangle {
                    anchors.fill: parent
                    z: 20
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: game.over || (game.won && !game.keepPlaying)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        PC3.Label {
                            text: game.over ? i18n("Game over") : i18n("You made 2048! 🎉")
                            color: "white"; font.weight: Font.Bold
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PC3.Label {
                            text: i18n("Score %1", game.score)
                            color: "white"; opacity: 0.85
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PC3.Button {
                            text: game.over ? i18n("Play again") : i18n("Keep going")
                            Layout.alignment: Qt.AlignHCenter
                            onClicked: {
                                if (game.over) game.reset()
                                else game.keepPlaying = true
                            }
                        }
                    }
                }
            }

            // ── direction pad: the game is usable with the mouse alone ──
            Row {
                id: dpad
                anchors.top: boardBg.bottom
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Kirigami.Units.smallSpacing

                component Dir : PC3.ToolButton {
                    property int dir: 0
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    implicitWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
                    autoRepeat: true
                    onClicked: game.move(dir)
                }

                Dir { dir: 0; icon.name: "arrow-left";  Accessible.name: i18n("Move left") }
                Dir { dir: 2; icon.name: "arrow-up";    Accessible.name: i18n("Move up") }
                Dir { dir: 3; icon.name: "arrow-down";  Accessible.name: i18n("Move down") }
                Dir { dir: 1; icon.name: "arrow-right"; Accessible.name: i18n("Move right") }
            }
        }
    }
}
