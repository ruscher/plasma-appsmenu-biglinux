/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Sudoku — puzzles are generated here, not shipped: a complete grid is built
    by randomised backtracking and then cells are removed. Nothing is copied
    from anywhere, so there is no licence question about the puzzles.

    cfg: { sudokuLevel }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: sudoku
    required property var host

    readonly property var levels: ({ easy: 42, medium: 34, hard: 27 })
    readonly property string level: {
        const l = String(host.cfg.sudokuLevel || "easy")
        return levels[l] !== undefined ? l : "easy"
    }

    /*  `solution` is the finished grid, `given` marks the clues the player may
        not change, `cells` is what is on screen and `notes` the pencil marks
        (a bitmask per cell, bit n-1 for candidate n).  */
    property var solution: []
    property var given: []
    property var cells: []
    property var notes: []
    property int selected: -1
    property bool noteMode: false
    property bool solved: false

    Component.onCompleted: {
        host.accentColor = "#3b82f6"
        newPuzzle()
    }
    onLevelChanged: newPuzzle()

    Binding {
        target: sudoku.host
        property: "subtitle"
        value: sudoku.solved ? i18n("Solved!") : i18np("%1 empty", "%1 empty", sudoku.emptyCount)
    }

    readonly property int emptyCount: {
        let n = 0
        for (let i = 0; i < cells.length; i++) {
            if (!cells[i]) {
                n++
            }
        }
        return n
    }

    function rowOf(i) { return Math.floor(i / 9) }
    function colOf(i) { return i % 9 }
    function boxOf(i) { return Math.floor(rowOf(i) / 3) * 3 + Math.floor(colOf(i) / 3) }

    function allowed(g, i, v) {
        const r = rowOf(i), c = colOf(i)
        const br = Math.floor(r / 3) * 3, bc = Math.floor(c / 3) * 3
        for (let k = 0; k < 9; k++) {
            if (g[r * 9 + k] === v || g[k * 9 + c] === v) {
                return false
            }
            if (g[(br + Math.floor(k / 3)) * 9 + bc + (k % 3)] === v) {
                return false
            }
        }
        return true
    }

    function shuffled() {
        const a = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1))
            const t = a[i]; a[i] = a[j]; a[j] = t
        }
        return a
    }

    /*  Fills the grid in place; the randomised candidate order is what makes
        every puzzle different.  */
    function fill(g, i) {
        if (i === 81) {
            return true
        }
        const cand = shuffled()
        for (let k = 0; k < 9; k++) {
            if (allowed(g, i, cand[k])) {
                g[i] = cand[k]
                if (fill(g, i + 1)) {
                    return true
                }
                g[i] = 0
            }
        }
        return false
    }

    function newPuzzle() {
        const g = new Array(81).fill(0)
        fill(g, 0)
        solution = g.slice()

        const keep = levels[level]
        const order = []
        for (let i = 0; i < 81; i++) {
            order.push(i)
        }
        for (let i = order.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1))
            const t = order[i]; order[i] = order[j]; order[j] = t
        }
        const c = g.slice()
        const gv = new Array(81).fill(true)
        for (let k = 0; k < 81 - keep; k++) {
            c[order[k]] = 0
            gv[order[k]] = false
        }
        cells = c
        given = gv
        notes = new Array(81).fill(0)
        selected = -1
        solved = false
    }

    /*  A cell is in conflict when its value repeats in its row, column or
        box. Shown live, so a mistake is visible instead of only surfacing at
        the end.  */
    function conflicting(i) {
        const v = cells[i]
        if (!v) {
            return false
        }
        const r = rowOf(i), c = colOf(i), b = boxOf(i)
        for (let k = 0; k < 81; k++) {
            if (k !== i && cells[k] === v
                    && (rowOf(k) === r || colOf(k) === c || boxOf(k) === b)) {
                return true
            }
        }
        return false
    }

    function put(v) {
        if (selected < 0 || given[selected] || solved) {
            return
        }
        if (noteMode && v > 0) {
            const n = notes.slice()
            n[selected] = n[selected] ^ (1 << (v - 1))
            notes = n
            return
        }
        const c = cells.slice()
        c[selected] = c[selected] === v ? 0 : v
        cells = c
        const n = notes.slice()
        n[selected] = 0
        notes = n
        checkSolved()
    }

    function checkSolved() {
        for (let i = 0; i < 81; i++) {
            if (cells[i] !== solution[i]) {
                return
            }
        }
        solved = true
    }

    function move(dc, dr) {
        if (selected < 0) {
            selected = 0
            return
        }
        const c = Math.max(0, Math.min(8, colOf(selected) + dc))
        const r = Math.max(0, Math.min(8, rowOf(selected) + dr))
        selected = r * 9 + c
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { move(-1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Right) { move(1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Up) { move(0, -1); event.accepted = true }
        else if (event.key === Qt.Key_Down) { move(0, 1); event.accepted = true }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { put(event.key - Qt.Key_0); event.accepted = true }
        else if (event.key === Qt.Key_0 || event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { put(0); event.accepted = true }
        else if (event.key === Qt.Key_N) { noteMode = !noteMode; event.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: sudoku.solved ? i18n("Solved") : ""
                color: Kirigami.Theme.positiveTextColor
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PC3.ToolButton {
                icon.name: "draw-freehand"
                checkable: true
                checked: sudoku.noteMode
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                onToggled: sudoku.noteMode = checked
                Accessible.name: i18n("Pencil marks")
                PC3.ToolTip.text: i18n("Pencil marks"); PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                onClicked: sudoku.newPuzzle()
                Accessible.name: i18n("New puzzle")
                PC3.ToolTip.text: i18n("New puzzle"); PC3.ToolTip.visible: hovered
            }
        }

        Item {
            id: boardBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real side: Math.max(90, Math.min(width, height))
            readonly property real cell: side / 9

            Item {
                anchors.centerIn: parent
                width: boardBox.side
                height: boardBox.side

                Grid {
                    anchors.fill: parent
                    columns: 9
                    rows: 9

                    Repeater {
                        model: 81
                        delegate: Rectangle {
                            id: cellItem
                            required property int index
                            readonly property int value: sudoku.cells[index] || 0
                            readonly property bool isGiven: sudoku.given[index] === true
                            readonly property bool bad: sudoku.conflicting(index)
                            readonly property bool sel: sudoku.selected === index
                            readonly property bool peer: sudoku.selected >= 0 && !sel
                                && (sudoku.rowOf(index) === sudoku.rowOf(sudoku.selected)
                                 || sudoku.colOf(index) === sudoku.colOf(sudoku.selected)
                                 || sudoku.boxOf(index) === sudoku.boxOf(sudoku.selected))

                            width: boardBox.cell
                            height: boardBox.cell
                            color: sel ? Qt.rgba(sudoku.host.accent.r, sudoku.host.accent.g, sudoku.host.accent.b, 0.30)
                                 : (bad ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.25)
                                 : (peer ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                                 : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)))

                            PC3.Label {
                                anchors.centerIn: parent
                                visible: cellItem.value > 0
                                text: String(cellItem.value)
                                font.pointSize: Math.max(6, boardBox.cell * 0.5)
                                font.weight: cellItem.isGiven ? Font.Bold : Font.Normal
                                opacity: cellItem.isGiven ? 1 : 0.85
                                color: cellItem.bad ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            }

                            /*  Pencil marks, three by three inside the cell. */
                            Grid {
                                anchors.fill: parent
                                anchors.margins: 1
                                columns: 3
                                visible: cellItem.value === 0 && sudoku.notes[cellItem.index]
                                Repeater {
                                    model: 9
                                    delegate: PC3.Label {
                                        required property int index
                                        width: (boardBox.cell - 2) / 3
                                        height: (boardBox.cell - 2) / 3
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pointSize: Math.max(4, boardBox.cell * 0.18)
                                        opacity: 0.6
                                        text: (sudoku.notes[cellItem.index] & (1 << index)) ? String(index + 1) : ""
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: { sudoku.selected = cellItem.index; sudoku.forceActiveFocus() }
                            }

                            Accessible.role: Accessible.Cell
                            Accessible.name: cellItem.value > 0
                                ? i18nc("@info sudoku cell", "Row %1, column %2, value %3",
                                        sudoku.rowOf(cellItem.index) + 1, sudoku.colOf(cellItem.index) + 1, cellItem.value)
                                : i18nc("@info sudoku cell", "Row %1, column %2, empty",
                                        sudoku.rowOf(cellItem.index) + 1, sudoku.colOf(cellItem.index) + 1)
                        }
                    }
                }

                /*  The 3×3 block lines, drawn over the cells. */
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.45)
                        width: 1.5
                        height: boardBox.side
                        x: index * 3 * boardBox.cell
                    }
                }
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.45)
                        height: 1.5
                        width: boardBox.side
                        y: index * 3 * boardBox.cell
                    }
                }
            }
        }

        /*  Touch and mouse input; the keyboard has 1-9 directly. */
        RowLayout {
            Layout.fillWidth: true
            spacing: 1
            Repeater {
                model: 10
                delegate: PC3.ToolButton {
                    required property int index
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitWidth: 0
                    text: index < 9 ? String(index + 1) : "⌫"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: sudoku.put(index < 9 ? index + 1 : 0)
                    Accessible.name: index < 9 ? String(index + 1) : i18n("Clear cell")
                }
            }
        }
    }

    property Component gameSettings: Component {
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.ComboBox {
                    Kirigami.FormData.label: i18n("Difficulty:")
                    model: [
                        i18nc("@item:inlistbox sudoku difficulty", "Easy"),
                        i18nc("@item:inlistbox sudoku difficulty", "Medium"),
                        i18nc("@item:inlistbox sudoku difficulty", "Hard")
                    ]
                    readonly property var keys: ["easy", "medium", "hard"]
                    currentIndex: Math.max(0, keys.indexOf(sudoku.level))
                    onActivated: host.setCfg("sudokuLevel", keys[currentIndex])
                }
            }
            PC3.Label {
                text: i18n("Puzzles are generated on this computer, so every game is different. Press N for pencil marks.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
        }
    }
}
