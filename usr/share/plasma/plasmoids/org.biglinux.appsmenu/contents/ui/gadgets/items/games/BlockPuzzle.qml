/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Block Puzzle — drop the offered pieces on the board; a full row or column
    clears. No gravity and no falling: it is a placement puzzle, and it ends
    when none of the three pieces on offer still fits anywhere.

    Written from scratch under a generic name. The shapes are polyominoes,
    which are mathematics rather than anyone's artwork, and the colours come
    from the palette below — nothing is bundled from any product.

    cfg: { blocksBest }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: blocks
    required property var host

    readonly property int size: 8
    readonly property var palette: ["#ef4444", "#3b82f6", "#22c55e", "#eab308", "#a855f7", "#06b6d4", "#f97316"]

    /*  Each shape is a list of [dx, dy] offsets from its own top-left. */
    readonly property var shapes: [
        [[0, 0]],
        [[0, 0], [1, 0]],
        [[0, 0], [0, 1]],
        [[0, 0], [1, 0], [2, 0]],
        [[0, 0], [0, 1], [0, 2]],
        [[0, 0], [1, 0], [0, 1], [1, 1]],
        [[0, 0], [1, 0], [2, 0], [3, 0]],
        [[0, 0], [0, 1], [0, 2], [0, 3]],
        [[0, 0], [0, 1], [1, 1]],
        [[0, 0], [1, 0], [1, 1]],
        [[0, 0], [1, 0], [0, 1]],
        [[1, 0], [0, 1], [1, 1]],
        [[0, 0], [1, 0], [2, 0], [1, 1]],
        [[0, 0], [0, 1], [0, 2], [1, 2]],
        [[1, 0], [1, 1], [0, 2], [1, 2]],
        [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]],
        [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]],
        [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2]]
    ]

    /*  0 is empty; anything else is a palette index plus one. */
    property var board: []
    /*  Three offers; an entry is null once it has been placed. */
    property var tray: []
    property int selected: -1
    property int score: 0
    property bool over: false

    readonly property int best: Number(host.cfg.blocksBest || 0)

    Component.onCompleted: {
        host.accentColor = "#f97316"
        reset()
    }

    Binding {
        target: blocks.host
        property: "subtitle"
        value: blocks.over ? i18n("No room left — best %1", blocks.best)
                           : i18nc("@info:status current score and record", "%1 · best %2", blocks.score, blocks.best)
    }

    function reset() {
        board = new Array(size * size).fill(0)
        score = 0
        over = false
        selected = -1
        refill()
    }

    function refill() {
        const t = []
        for (let k = 0; k < 3; k++) {
            t.push({ shape: Math.floor(Math.random() * shapes.length),
                     colour: Math.floor(Math.random() * palette.length) })
        }
        tray = t
        selected = -1
        checkOver()
    }

    function fits(shapeIndex, c, r) {
        const sh = shapes[shapeIndex]
        for (const [dx, dy] of sh) {
            const x = c + dx, y = r + dy
            if (x < 0 || y < 0 || x >= size || y >= size) {
                return false
            }
            if (board[y * size + x] !== 0) {
                return false
            }
        }
        return true
    }

    function anywhere(shapeIndex) {
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                if (fits(shapeIndex, c, r)) {
                    return true
                }
            }
        }
        return false
    }

    function checkOver() {
        for (const p of tray) {
            if (p && anywhere(p.shape)) {
                over = false
                return
            }
        }
        over = true
        recordBest()
    }

    function recordBest() {
        if (score > best) {
            host.setCfg("blocksBest", score)
        }
    }

    function place(c, r) {
        if (over || selected < 0 || !tray[selected]) {
            return
        }
        const piece = tray[selected]
        if (!fits(piece.shape, c, r)) {
            return
        }
        const b = board.slice()
        for (const [dx, dy] of shapes[piece.shape]) {
            b[(r + dy) * size + (c + dx)] = piece.colour + 1
        }
        score += shapes[piece.shape].length
        board = b
        clearLines()

        const t = tray.slice()
        t[selected] = null
        tray = t
        selected = -1

        if (t.every(p => p === null)) {
            refill()
        } else {
            checkOver()
        }
    }

    /*  Full rows and columns are found first and removed together, so a piece
        completing both scores for both.  */
    function clearLines() {
        const fullRows = [], fullCols = []
        for (let r = 0; r < size; r++) {
            let full = true
            for (let c = 0; c < size; c++) {
                if (board[r * size + c] === 0) { full = false; break }
            }
            if (full) {
                fullRows.push(r)
            }
        }
        for (let c = 0; c < size; c++) {
            let full = true
            for (let r = 0; r < size; r++) {
                if (board[r * size + c] === 0) { full = false; break }
            }
            if (full) {
                fullCols.push(c)
            }
        }
        if (!fullRows.length && !fullCols.length) {
            return
        }
        const b = board.slice()
        for (const r of fullRows) {
            for (let c = 0; c < size; c++) {
                b[r * size + c] = 0
            }
        }
        for (const c of fullCols) {
            for (let r = 0; r < size; r++) {
                b[r * size + c] = 0
            }
        }
        board = b
        const lines = fullRows.length + fullCols.length
        score += lines * size * lines      // clearing two at once is worth more
        recordBest()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: blocks.over ? i18n("No room for any piece") : ""
                color: Kirigami.Theme.negativeTextColor
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                onClicked: blocks.reset()
                Accessible.name: i18n("New game")
                PC3.ToolTip.text: i18n("New game"); PC3.ToolTip.visible: hovered
            }
        }

        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real side: Math.max(60, Math.min(width, height))
            readonly property real cell: side / blocks.size

            Item {
                anchors.centerIn: parent
                width: boardBox.side
                height: boardBox.side

                Repeater {
                    model: blocks.size * blocks.size
                    delegate: Rectangle {
                        required property int index
                        readonly property int cx: index % blocks.size
                        readonly property int cy: Math.floor(index / blocks.size)
                        readonly property int v: blocks.board[index] || 0
                        readonly property bool preview: blocks.selected >= 0
                            && blocks.tray[blocks.selected]
                            && hoverArea.hoverCell === index
                            && blocks.fits(blocks.tray[blocks.selected].shape, cx, cy)

                        x: cx * boardBox.cell
                        y: cy * boardBox.cell
                        width: boardBox.cell
                        height: boardBox.cell
                        radius: 2
                        color: v > 0 ? blocks.palette[v - 1]
                             : (preview ? Qt.rgba(blocks.host.accent.r, blocks.host.accent.g, blocks.host.accent.b, 0.35)
                             : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06))
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                              Kirigami.Theme.backgroundColor.g,
                                              Kirigami.Theme.backgroundColor.b, 0.7)
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    property int hoverCell: -1

                    function cellAt(mx, my) {
                        const c = Math.floor(mx / boardBox.cell)
                        const r = Math.floor(my / boardBox.cell)
                        if (c < 0 || r < 0 || c >= blocks.size || r >= blocks.size) {
                            return -1
                        }
                        return r * blocks.size + c
                    }
                    onPositionChanged: mouse => hoverCell = cellAt(mouse.x, mouse.y)
                    onExited: hoverCell = -1
                    onClicked: mouse => {
                        const i = cellAt(mouse.x, mouse.y)
                        if (i >= 0) {
                            blocks.place(i % blocks.size, Math.floor(i / blocks.size))
                        }
                    }
                }
            }
        }

        /*  The three offers. Tap one, then tap where it goes. */
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.4
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    readonly property var piece: blocks.tray[index] || null

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Kirigami.Units.smallSpacing
                    color: blocks.selected === index
                        ? Qt.rgba(blocks.host.accent.r, blocks.host.accent.g, blocks.host.accent.b, 0.22)
                        : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)

                    Item {
                        anchors.centerIn: parent
                        readonly property var shape: parent.piece ? blocks.shapes[parent.piece.shape] : []
                        readonly property int w: {
                            let m = 0
                            for (const s of shape) { m = Math.max(m, s[0]) }
                            return m + 1
                        }
                        readonly property int h: {
                            let m = 0
                            for (const s of shape) { m = Math.max(m, s[1]) }
                            return m + 1
                        }
                        readonly property real unit: Math.min(
                            (parent.width - 8) / Math.max(1, w),
                            (parent.height - 8) / Math.max(1, h), 10)
                        width: w * unit
                        height: h * unit

                        Repeater {
                            model: parent.shape
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData[0] * parent.unit
                                y: modelData[1] * parent.unit
                                width: parent.unit - 1
                                height: parent.unit - 1
                                radius: 1
                                color: parent.parent.piece ? blocks.palette[parent.parent.piece.colour] : "transparent"
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.piece !== null && !blocks.over
                        onClicked: blocks.selected = blocks.selected === parent.index ? -1 : parent.index
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: piece ? i18nc("@info a piece waiting to be placed", "Piece %1", index + 1)
                                           : i18nc("@info an empty piece slot", "Used")
                }
            }
        }
    }
}
