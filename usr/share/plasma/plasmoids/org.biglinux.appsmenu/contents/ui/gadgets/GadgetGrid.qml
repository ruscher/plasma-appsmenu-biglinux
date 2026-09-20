/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetGrid — packs gadget cards into a column grid (2/3/4 columns) and
    re-packs live while one is dragged (first-fit, top-left, keeping order).

    The grid owns the instance list (a ListModel with roles uid, gadgetId,
    size, cfgJson) and emits layoutChanged() whenever something that must be
    persisted changes. Persistence and the shared cache live in InfoPage.
*/

import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: gadgetGrid

    property int columns: 3
    property real spacing: Kirigami.Units.largeSpacing
    property bool editing: false
    // false while the Info page is hidden or the menu is closed → gadgets pause
    property bool active: true
    // Visible viewport (in grid coordinates) so off-screen gadgets can pause
    property real viewportTop: 0
    property real viewportBottom: 1e9

    readonly property real cellWidth: Math.max(80, Math.floor((width - spacing * (columns - 1)) / columns))
    readonly property real cellHeight: Math.round(cellWidth * 0.94)
    property var positions: ({})
    property var occupancy: []
    property int rowsUsed: 0
    readonly property int count: layoutModel.count

    implicitHeight: rowsUsed > 0 ? rowsUsed * cellHeight + (rowsUsed - 1) * spacing : 0

    signal layoutChanged()
    signal settingsRequested(var host)
    // y (grid coords) of the pointer while dragging — lets the page auto-scroll
    signal dragPointerMoved(real cy)
    // cache functions are injected by the page
    property var cacheGet: function(key) { return undefined }
    property var cacheSet: function(key, value) {}

    ListModel {
        id: layoutModel
    }

    // ── model management ──
    function clear() { layoutModel.clear(); relayout() }
    function load(items) {
        layoutModel.clear()
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (!GadgetRegistry.byId(it.id)) continue
            layoutModel.append({
                uid: it.uid || (it.id + "-" + Date.now() + "-" + i),
                gadgetId: it.id,
                size: it.size || GadgetRegistry.byId(it.id).defaultSize,
                cfgJson: it.cfg ? JSON.stringify(it.cfg) : ""
            })
        }
        relayout()
    }
    function serialize() {
        const out = []
        for (let i = 0; i < layoutModel.count; i++) {
            const it = layoutModel.get(i)
            let cfg = {}
            try { cfg = it.cfgJson ? JSON.parse(it.cfgJson) : {} } catch (e) {}
            out.push({ uid: it.uid, id: it.gadgetId, size: it.size, cfg: cfg })
        }
        return out
    }
    function indexOfUid(uid) {
        for (let i = 0; i < layoutModel.count; i++)
            if (layoutModel.get(i).uid === uid) return i
        return -1
    }
    function hasGadget(gadgetId) {
        for (let i = 0; i < layoutModel.count; i++)
            if (layoutModel.get(i).gadgetId === gadgetId) return true
        return false
    }
    function addGadget(gadgetId, size) {
        const def = GadgetRegistry.byId(gadgetId)
        if (!def) return
        layoutModel.append({
            uid: gadgetId + "-" + Date.now(),
            gadgetId: gadgetId,
            size: size || def.defaultSize,
            cfgJson: ""
        })
        relayout()
        layoutChanged()
    }
    function removeGadget(uid) {
        const i = indexOfUid(uid)
        if (i < 0) return
        layoutModel.remove(i)
        relayout()
        layoutChanged()
    }
    function cycleSize(uid) {
        const i = indexOfUid(uid)
        if (i < 0) return
        const it = layoutModel.get(i)
        const def = GadgetRegistry.byId(it.gadgetId)
        if (!def || def.sizes.length < 2) return
        const k = def.sizes.indexOf(it.size)
        layoutModel.setProperty(i, "size", def.sizes[(k + 1) % def.sizes.length])
        relayout()
        layoutChanged()
    }
    function setSize(uid, size) {
        const i = indexOfUid(uid)
        if (i < 0) return
        layoutModel.setProperty(i, "size", size)
        relayout()
        layoutChanged()
    }
    function saveCfg(uid, cfg) {
        const i = indexOfUid(uid)
        if (i < 0) return
        layoutModel.setProperty(i, "cfgJson", JSON.stringify(cfg || {}))
        layoutChanged()
    }
    function setEditing(on) { editing = on }
    function openSettings(host) { settingsRequested(host) }

    // ── packing ──
    function sizeOf(it) {
        const parts = String(it.size).split("x")
        return { w: Math.max(1, Math.min(columns, parseInt(parts[0]) || 1)), h: Math.max(1, parseInt(parts[1]) || 1) }
    }
    function relayout() {
        const occ = []
        const pos = {}
        let maxRow = 0
        // Compute from `width` directly: when called from onWidthChanged the
        // cellWidth/cellHeight bindings may not have re-evaluated yet.
        const cw = Math.max(80, Math.floor((width - spacing * (columns - 1)) / columns))
        const ch = Math.round(cw * 0.94)
        const stepX = cw + spacing, stepY = ch + spacing
        function fits(r, c, w, h) {
            if (c + w > columns) return false
            for (let i = r; i < r + h; i++)
                for (let j = c; j < c + w; j++)
                    if (occ[i] && occ[i][j]) return false
            return true
        }
        for (let i = 0; i < layoutModel.count; i++) {
            const it = layoutModel.get(i)
            const s = sizeOf(it)
            let placed = false
            for (let r = 0; !placed && r < 500; r++) {
                for (let c = 0; c <= columns - s.w; c++) {
                    if (fits(r, c, s.w, s.h)) {
                        for (let a = r; a < r + s.h; a++) {
                            if (!occ[a]) occ[a] = []
                            for (let b = c; b < c + s.w; b++) occ[a][b] = it.uid
                        }
                        pos[it.uid] = { col: c, row: r, w: s.w, h: s.h, x: c * stepX, y: r * stepY }
                        maxRow = Math.max(maxRow, r + s.h)
                        placed = true
                        break
                    }
                }
            }
        }
        occupancy = occ
        positions = pos
        rowsUsed = maxRow
    }
    onColumnsChanged: relayout()
    onWidthChanged: relayout()
    onCellWidthChanged: relayout()
    onSpacingChanged: relayout()

    // ── drag & drop ──
    // The target slot follows the POINTER (not the card centre). A reorder is
    // only applied after the pointer rests in a new cell for `dwellMs`, never
    // while the page is auto-scrolling, so cards don't shuffle under you.
    property string dragUid: ""
    property Item dragHost: null
    property real pointerX: 0
    property real pointerY: 0
    property bool autoScrolling: false
    property int dwellMs: 140
    property int pendingRow: -1
    property int pendingCol: -1

    function hostForUid(uid) {
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i)
            if (it && it.uid === uid) return it
        }
        return null
    }
    function cellAt(px, py) {
        const stepX = cellWidth + spacing, stepY = cellHeight + spacing
        return { col: Math.max(0, Math.min(columns - 1, Math.floor(px / stepX))),
                 row: Math.max(0, Math.floor(py / stepY)) }
    }
    function dragStarted(uid, hostItem) {
        dragUid = uid
        dragHost = hostItem || hostForUid(uid)
        pendingRow = -1; pendingCol = -1
        dwellTimer.stop()
    }
    // px/py: pointer position in grid coordinates
    function dragMoved(uid, px, py) {
        if (uid !== dragUid) return
        pointerX = px; pointerY = py
        dragPointerMoved(py)
        const c = cellAt(px, py)
        if (c.row === pendingRow && c.col === pendingCol) return
        pendingRow = c.row; pendingCol = c.col
        dwellTimer.restart()
    }
    // Called by the page while it auto-scrolls: keep the card under the
    // pointer and postpone any reorder until scrolling settles.
    function scrollBy(delta) {
        if (!dragUid.length) return
        pointerY += delta
        if (dragHost) dragHost.dragY += delta
        dwellTimer.restart()
    }
    onAutoScrollingChanged: if (!autoScrolling && dragUid.length) dwellTimer.restart()

    Timer {
        id: dwellTimer
        interval: gadgetGrid.dwellMs
        onTriggered: {
            if (!gadgetGrid.dragUid.length || gadgetGrid.autoScrolling) return
            gadgetGrid.applyTarget(gadgetGrid.pendingRow, gadgetGrid.pendingCol)
        }
    }
    function applyTarget(row, col) {
        const uid = dragUid
        const from = indexOfUid(uid)
        if (from < 0) return
        const mine = positions[uid]
        // pointer inside the card's own slot → nothing to do
        if (mine && row >= mine.row && row < mine.row + mine.h && col >= mine.col && col < mine.col + mine.w) return
        const occupant = occupancy[row] ? occupancy[row][col] : undefined
        let to = -1
        if (occupant && occupant !== uid) {
            to = indexOfUid(occupant)
        } else if (!occupant && row >= rowsUsed) {
            to = layoutModel.count - 1
        } else if (!occupant) {
            // empty cell inside the grid: place after the nearest previous item in reading order
            let best = -1
            for (let r = row; r >= 0 && best < 0; r--) {
                for (let cc = (r === row ? col : columns - 1); cc >= 0; cc--) {
                    const o = occupancy[r] ? occupancy[r][cc] : undefined
                    if (o && o !== uid) { best = indexOfUid(o); break }
                }
            }
            to = best >= 0 ? (best < from ? best + 1 : best) : 0
        }
        if (to >= 0 && to !== from) {
            layoutModel.move(from, to, 1)
            relayout()
        }
    }
    function dragEnded(uid) {
        dwellTimer.stop()
        dragUid = ""
        dragHost = null
        autoScrolling = false
        relayout()
        layoutChanged()
    }

    // ── ghost: where the dragged card will land ──
    Rectangle {
        id: ghost
        readonly property var slot: gadgetGrid.dragUid.length ? gadgetGrid.positions[gadgetGrid.dragUid] : null
        visible: slot !== null && slot !== undefined
        z: 90
        x: slot ? slot.x : 0
        y: slot ? slot.y : 0
        width: slot ? slot.w * gadgetGrid.cellWidth + (slot.w - 1) * gadgetGrid.spacing : 0
        height: slot ? slot.h * gadgetGrid.cellHeight + (slot.h - 1) * gadgetGrid.spacing : 0
        radius: Kirigami.Units.largeSpacing * 1.6
        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.14)
        border.width: 2
        border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.75)
        Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        // "skeleton" lines
        Column {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            opacity: 0.35
            Rectangle { width: ghost.width * 0.45; height: 8; radius: 4; color: Kirigami.Theme.highlightColor }
            Rectangle { width: ghost.width * 0.65; height: 8; radius: 4; color: Kirigami.Theme.highlightColor }
            Rectangle { width: ghost.width * 0.35; height: 8; radius: 4; color: Kirigami.Theme.highlightColor }
        }
        Kirigami.Icon {
            source: "arrow-down"
            width: Kirigami.Units.iconSizes.smallMedium; height: width
            anchors { top: parent.top; right: parent.right; margins: Kirigami.Units.smallSpacing }
            color: Kirigami.Theme.highlightColor
            opacity: 0.8
        }
        SequentialAnimation on opacity {
            running: ghost.visible && Kirigami.Units.longDuration > 0
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutSine }
        }
    }

    // ── cards ──
    Repeater {
        id: repeater
        model: layoutModel
        delegate: GadgetHost {
            required property var model
            required property int index
            grid: gadgetGrid
            uid: model.uid
            gadgetId: model.gadgetId
            size: model.size
            cfgJson: model.cfgJson
            modelIndex: index
            inViewport: (y + height) >= gadgetGrid.viewportTop - gadgetGrid.cellHeight && y <= gadgetGrid.viewportBottom + gadgetGrid.cellHeight
        }
    }
}
