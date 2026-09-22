/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Flow Connect — join each pair of dots with a path; paths may not cross.

    Mechanics written from scratch and a generic name on purpose: the idea is
    an old one, but nothing here is taken from any commercial product — no
    code, no artwork, no name. Colours come from the palette below, not from
    bundled assets.

    The two base boards were laid out by hand so that a full-coverage solution
    exists, and each new game applies one of the eight rotations and mirrors,
    which preserves solvability while keeping the boards from getting stale.

    cfg: {}
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: flow
    required property var host

    readonly property int size: 5
    readonly property var palette: ["#ef4444", "#3b82f6", "#22c55e", "#eab308", "#a855f7", "#06b6d4"]

    /*  Endpoint pairs as [col, row]; index in the array is the colour. */
    readonly property var boards: [
        [[[0, 0], [0, 4]], [[1, 0], [4, 1]], [[1, 1], [2, 2]], [[1, 2], [4, 4]], [[4, 2], [2, 3]]],
        [[[0, 0], [0, 1]], [[3, 0], [3, 1]], [[0, 2], [4, 2]], [[0, 3], [2, 3]], [[2, 4], [3, 3]]]
    ]

    /*  Endpoints of the board in play, after the transform. */
    property var ends: []
    /*  One array of cell indices per colour, in drawing order. */
    property var paths: []
    property int drawing: -1

    readonly property int pairCount: ends.length
    readonly property int connected: {
        let n = 0
        for (let c = 0; c < paths.length; c++) {
            if (isConnected(c)) {
                n++
            }
        }
        return n
    }
    readonly property bool solved: pairCount > 0 && connected === pairCount
    readonly property bool compact: host.compact

    property var titleActions: [clearAction, newAction]
    QQC2.Action {
        id: clearAction
        text: i18nc("@action:button", "Clear the board")
        icon.name: "edit-clear-symbolic"
        onTriggered: flow.clearAll()
    }
    QQC2.Action {
        id: newAction
        text: i18nc("@action:button", "New board")
        icon.name: "view-refresh-symbolic"
        onTriggered: flow.newBoard()
    }

    Component.onCompleted: {
        host.accentColor = "#06b6d4"
        newBoard()
    }

    Binding {
        target: flow.host
        property: "subtitle"
        value: flow.solved ? i18n("Solved!")
                           : i18nc("@info:status pairs joined out of the total",
                                   "%1 of %2 joined", flow.connected, flow.pairCount)
    }

    function idx(c, r) { return r * size + c }
    function colOf(i) { return i % size }
    function rowOf(i) { return Math.floor(i / size) }

    /*  One of the eight symmetries of the square, applied to every endpoint.
        A rotated solvable board is still solvable.

        Not called `transform`: every Item already has a `transform` property,
        which would shadow this and leave it un-callable — the same trap that
        `clip` set for the clipboard gadget.  */
    function mapCell(c, r, t) {
        const n = size - 1
        let x = c, y = r
        if (t & 4) { x = n - x }            // mirror
        const q = t & 3
        for (let k = 0; k < q; k++) {       // quarter turns
            const nx = n - y, ny = x
            x = nx; y = ny
        }
        return [x, y]
    }

    function newBoard() {
        const base = boards[Math.floor(Math.random() * boards.length)]
        const t = Math.floor(Math.random() * 8)
        const e = []
        for (const pair of base) {
            const a = mapCell(pair[0][0], pair[0][1], t)
            const b = mapCell(pair[1][0], pair[1][1], t)
            e.push([idx(a[0], a[1]), idx(b[0], b[1])])
        }
        ends = e
        clearAll()
    }

    function clearAll() {
        const p = []
        for (let c = 0; c < ends.length; c++) {
            p.push([ends[c][0]])            // a path always starts at its first dot
        }
        paths = p
        drawing = -1
    }

    function isEndpoint(i) {
        for (let c = 0; c < ends.length; c++) {
            if (ends[c][0] === i || ends[c][1] === i) {
                return c
            }
        }
        return -1
    }

    function isConnected(c) {
        const p = paths[c]
        if (!p || p.length < 2) {
            return false
        }
        const a = p[0], b = p[p.length - 1]
        return (a === ends[c][0] && b === ends[c][1]) || (a === ends[c][1] && b === ends[c][0])
    }

    /*  Which colour occupies a cell, or -1. */
    function ownerOf(i) {
        for (let c = 0; c < paths.length; c++) {
            if (paths[c].indexOf(i) !== -1) {
                return c
            }
        }
        return -1
    }

    function adjacent(a, b) {
        const dc = Math.abs(colOf(a) - colOf(b)), dr = Math.abs(rowOf(a) - rowOf(b))
        return dc + dr === 1
    }

    /*  Begin (or resume) drawing a colour from one of its dots, or from a
        cell already on its path — which is how a path is shortened.  */
    function begin(i) {
        const e = isEndpoint(i)
        if (e >= 0) {
            const p = paths.slice()
            p[e] = [i]
            paths = p
            drawing = e
            return
        }
        const o = ownerOf(i)
        if (o >= 0) {
            const p = paths.slice()
            p[o] = p[o].slice(0, p[o].indexOf(i) + 1)
            paths = p
            drawing = o
        }
    }

    function extend(i) {
        if (drawing < 0 || solved) {
            return
        }
        const p = paths.slice()
        const mine = p[drawing].slice()
        const last = mine[mine.length - 1]
        if (i === last) {
            return
        }
        /*  Stepping back along your own path erases the tail. */
        const back = mine.indexOf(i)
        if (back !== -1) {
            p[drawing] = mine.slice(0, back + 1)
            paths = p
            return
        }
        if (!adjacent(last, i)) {
            return
        }
        /*  A dot of another colour is a wall; that colour's own path is not,
            it simply gets cut back to before this cell.  */
        const e = isEndpoint(i)
        if (e >= 0 && e !== drawing) {
            return
        }
        const o = ownerOf(i)
        if (o >= 0 && o !== drawing) {
            const cut = p[o].indexOf(i)
            p[o] = p[o].slice(0, cut)
            if (p[o].length === 0) {
                p[o] = [ends[o][0]]
            }
        }
        mine.push(i)
        p[drawing] = mine
        paths = p
        /*  Reaching the far dot ends this colour. */
        if (e === drawing) {
            drawing = -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real side: Math.max(60, Math.min(width, height))
            readonly property real cell: side / flow.size

            Item {
                id: boardArea
                anchors.centerIn: parent
                width: boardBox.side
                height: boardBox.side

                Repeater {
                    model: flow.size * flow.size
                    delegate: Rectangle {
                        required property int index
                        readonly property int owner: flow.ownerOf(index)
                        readonly property int endColour: flow.isEndpoint(index)

                        x: flow.colOf(index) * boardBox.cell
                        y: flow.rowOf(index) * boardBox.cell
                        width: boardBox.cell
                        height: boardBox.cell
                        color: owner >= 0
                            ? Qt.rgba(Qt.color(flow.palette[owner]).r, Qt.color(flow.palette[owner]).g,
                                      Qt.color(flow.palette[owner]).b, 0.45)
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                              Kirigami.Theme.backgroundColor.g,
                                              Kirigami.Theme.backgroundColor.b, 0.7)

                        Rectangle {
                            anchors.centerIn: parent
                            visible: parent.endColour >= 0
                            width: boardBox.cell * 0.62
                            height: width
                            radius: width / 2
                            color: parent.endColour >= 0 ? flow.palette[parent.endColour] : "transparent"
                        }

                        Accessible.role: Accessible.Cell
                        Accessible.name: parent && endColour >= 0
                            ? i18nc("@info a coloured dot on the board", "Dot, colour %1", endColour + 1)
                            : i18nc("@info an empty board square", "Square")
                    }
                }

                /*  One area for the whole board: dragging across it draws, and
                    a plain tap extends by one square, so the game works with a
                    mouse, a finger, or by tapping alone.  */
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    function cellAt(mx, my) {
                        const c = Math.floor(mx / boardBox.cell)
                        const r = Math.floor(my / boardBox.cell)
                        if (c < 0 || r < 0 || c >= flow.size || r >= flow.size) {
                            return -1
                        }
                        return flow.idx(c, r)
                    }

                    onPressed: mouse => {
                        const i = cellAt(mouse.x, mouse.y)
                        if (i < 0) {
                            return
                        }
                        if (flow.drawing >= 0 && flow.adjacent(flow.paths[flow.drawing][flow.paths[flow.drawing].length - 1], i)) {
                            flow.extend(i)      // tap-to-extend
                        } else {
                            flow.begin(i)
                        }
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) {
                            return
                        }
                        const i = cellAt(mouse.x, mouse.y)
                        if (i >= 0) {
                            flow.extend(i)
                        }
                    }
                }
            }
        }
    }
}
