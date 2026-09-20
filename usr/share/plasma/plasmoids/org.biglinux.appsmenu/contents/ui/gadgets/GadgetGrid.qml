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
    // y (grid coords) of the dragged card's centre — lets the page auto-scroll
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
    property string dragUid: ""
    property int lastDragCellRow: -1
    property int lastDragCellCol: -1

    function dragStarted(uid) {
        dragUid = uid
        lastDragCellRow = -1; lastDragCellCol = -1
    }
    function dragMoved(uid, cx, cy) {
        dragPointerMoved(cy)
        const stepX = cellWidth + spacing, stepY = cellHeight + spacing
        const col = Math.max(0, Math.min(columns - 1, Math.floor(cx / stepX)))
        const row = Math.max(0, Math.floor(cy / stepY))
        if (row === lastDragCellRow && col === lastDragCellCol) return
        lastDragCellRow = row; lastDragCellCol = col

        const from = indexOfUid(uid)
        if (from < 0) return
        const occupant = occupancy[row] ? occupancy[row][col] : undefined
        let to = -1
        if (occupant && occupant !== uid) {
            to = indexOfUid(occupant)
        } else if (!occupant && row >= rowsUsed) {
            to = layoutModel.count - 1
        }
        if (to >= 0 && to !== from) {
            layoutModel.move(from, to, 1)
            relayout()
        }
    }
    function dragEnded(uid) {
        dragUid = ""
        relayout()
        layoutChanged()
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
