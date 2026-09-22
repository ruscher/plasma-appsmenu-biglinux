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
import QtQuick.Controls 2.15 as QQC2
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
    readonly property bool compact: host.compact

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

    function coveredBy(shapeIndex, anchor, target) {
        const ac = anchor % size, ar = Math.floor(anchor / size)
        for (const [dx, dy] of shapes[shapeIndex]) {
            if ((ar + dy) * size + (ac + dx) === target && ac + dx < size) return true
        }
        return false
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

    /*  Two arrangements, chosen from the real geometry rather than the size
        label: the tray sits beside the board when the content area is wider
        than it is tall (1x1 and 2x1 cards), under it when there is more
        height than width (1x2). Either way the board takes the largest square
        the remaining space allows, which on a 1x1 card is nearly all of it —
        the tray is a column of three pieces drawn at three quarters of a board cell.  */
    readonly property bool sideTray: width >= height * 0.95
    /*  The tray takes about a quarter of the card, or whatever the square
        board leaves over when that is more, up to a comfortable maximum.  */
    readonly property real trayThickness: sideTray
        ? Math.max(Kirigami.Units.gridUnit * 1.7, Math.min(Math.max(width * 0.28, width - height - gapSize), Kirigami.Units.gridUnit * 5))
        : Math.max(Kirigami.Units.gridUnit * 1.7, Math.min(Math.max(height * 0.24, height - width - gapSize), Kirigami.Units.gridUnit * 5))
    readonly property real gapSize: Kirigami.Units.smallSpacing
    readonly property real boardSide: Math.max(48, sideTray
        ? Math.min(width - trayThickness - gapSize, height)
        : Math.min(width, height - trayThickness - gapSize))
    readonly property real cellSize: boardSide / size
    /*  Whatever the square board and the tray do not use is split evenly
        around them, so a wide card does not leave everything hugging a side. */
    readonly property real originX: Math.round((width - boardSide - (sideTray ? gapSize + trayThickness : 0)) / 2)
    readonly property real originY: Math.round((height - boardSide - (sideTray ? 0 : gapSize + trayThickness)) / 2)

    property var titleActions: [newAction]
    QQC2.Action {
        id: newAction
        text: i18nc("@action:button", "New game")
        icon.name: "view-refresh-symbolic"
        onTriggered: blocks.reset()
    }

    Item {
        id: boardBox
        x: blocks.originX
        y: blocks.originY
        width: blocks.boardSide
        height: blocks.boardSide

        Repeater {
            model: blocks.size * blocks.size
            delegate: Rectangle {
                required property int index
                readonly property int cx: index % blocks.size
                readonly property int cy: Math.floor(index / blocks.size)
                readonly property int v: blocks.board[index] || 0
                readonly property var piece: blocks.selected >= 0 ? blocks.tray[blocks.selected] : null
                readonly property bool hoverHere: hoverArea.hoverCell === index
                readonly property bool fitsHere: piece && hoverHere ? blocks.fits(piece.shape, cx, cy) : false
                /*  Green-ish ghost where the piece would land, red tint where it
                    cannot: the answer is visible before the tap, not after. */
                readonly property bool ghost: piece && hoverArea.hoverCell >= 0 && fitsAtHover && blocks.coveredBy(piece.shape, hoverArea.hoverCell, index)
                readonly property bool fitsAtHover: piece && hoverArea.hoverCell >= 0
                    ? blocks.fits(piece.shape, hoverArea.hoverCell % blocks.size, Math.floor(hoverArea.hoverCell / blocks.size)) : false
                readonly property bool rejected: piece && hoverHere && !fitsAtHover

                x: cx * blocks.cellSize
                y: cy * blocks.cellSize
                width: blocks.cellSize
                height: blocks.cellSize
                radius: Math.max(1, blocks.cellSize * 0.12)
                color: v > 0 ? blocks.palette[v - 1]
                     : ghost ? Qt.rgba(blocks.host.accent.r, blocks.host.accent.g, blocks.host.accent.b, 0.45)
                     : rejected ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.35)
                     : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.7)
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            property int hoverCell: -1
            function cellAt(mx, my) {
                const c = Math.floor(mx / blocks.cellSize), r = Math.floor(my / blocks.cellSize)
                if (c < 0 || r < 0 || c >= blocks.size || r >= blocks.size) return -1
                return r * blocks.size + c
            }
            onPositionChanged: mouse => hoverCell = cellAt(mouse.x, mouse.y)
            onExited: hoverCell = -1
            onClicked: mouse => {
                const i = cellAt(mouse.x, mouse.y)
                if (i >= 0) blocks.place(i % blocks.size, Math.floor(i / blocks.size))
            }
        }

        /*  Game over is said on the board itself, with the way out.  */
        Rectangle {
            anchors.fill: parent
            visible: blocks.over
            radius: Kirigami.Units.smallSpacing
            color: Qt.rgba(0, 0, 0, 0.55)
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing
                PC3.Label {
                    text: i18n("No room for any piece")
                    color: "white"; font.weight: Font.Bold
                    font.pointSize: blocks.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    Layout.maximumWidth: boardBox.width - Kirigami.Units.largeSpacing
                }
                PC3.Label {
                    text: i18nc("@info:status score and record", "%1 · best %2", blocks.score, blocks.best)
                    color: "white"; opacity: 0.85; font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.alignment: Qt.AlignHCenter
                }
                PC3.Button { text: i18n("Play again"); Layout.alignment: Qt.AlignHCenter; onClicked: blocks.reset() }
            }
        }
    }

    /*  The three offers, as a column beside the board or a row under it.  */
    Grid {
        id: trayGrid
        x: blocks.sideTray ? boardBox.x + blocks.boardSide + blocks.gapSize : boardBox.x
        y: blocks.sideTray ? boardBox.y : boardBox.y + blocks.boardSide + blocks.gapSize
        width: blocks.sideTray ? blocks.trayThickness : blocks.boardSide
        height: blocks.sideTray ? blocks.boardSide : blocks.trayThickness
        /*  Only the column count is set: giving rows as well makes the two
            change one after the other and the Grid complains about a 1×1
            holding three items in between.  */
        columns: blocks.sideTray ? 1 : 3
        spacing: Kirigami.Units.smallSpacing

        readonly property real slotW: blocks.sideTray ? width : (width - spacing * 2) / 3
        readonly property real slotH: blocks.sideTray ? (height - spacing * 2) / 3 : height

        Repeater {
            model: 3
            delegate: Rectangle {
                id: slot
                required property int index
                readonly property var piece: blocks.tray[index] || null
                readonly property bool selected: blocks.selected === index
                width: trayGrid.slotW
                height: trayGrid.slotH
                radius: Kirigami.Units.smallSpacing
                color: selected ? Qt.rgba(blocks.host.accent.r, blocks.host.accent.g, blocks.host.accent.b, 0.28)
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, piece ? 0.06 : 0.02)
                border.width: selected ? 2 : 0
                border.color: blocks.host.accent

                Item {
                    id: glyph
                    anchors.centerIn: parent
                    readonly property var shape: slot.piece ? blocks.shapes[slot.piece.shape] : []
                    readonly property int w: shape.reduce((m, s) => Math.max(m, s[0]), 0) + 1
                    readonly property int h: shape.reduce((m, s) => Math.max(m, s[1]), 0) + 1
                    readonly property real unit: Math.max(3, Math.min((slot.width - 6) / w, (slot.height - 6) / h, blocks.cellSize * 0.75))
                    width: w * unit
                    height: h * unit
                    Repeater {
                        model: glyph.shape
                        delegate: Rectangle {
                            required property var modelData
                            x: modelData[0] * glyph.unit
                            y: modelData[1] * glyph.unit
                            width: glyph.unit - 1
                            height: glyph.unit - 1
                            radius: 1
                            color: slot.piece ? blocks.palette[slot.piece.colour] : "transparent"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: slot.piece !== null && !blocks.over
                    onClicked: blocks.selected = blocks.selected === slot.index ? -1 : slot.index
                }

                Accessible.role: Accessible.Button
                Accessible.name: piece ? (selected ? i18nc("@info a piece that is selected", "Piece %1, selected", index + 1)
                                                  : i18nc("@info a piece waiting to be placed", "Piece %1", index + 1))
                                       : i18nc("@info an empty piece slot", "Used")
            }
        }
    }
}
