/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    InfoPage — a modular dashboard of gadgets (see gadgets/).

    Owns persistence (layout + shared cache in Plasmoid.configuration, debounced),
    the toolbar (columns, edit mode, add), the gallery and the settings dialog.
    Gadgets themselves live in gadgets/items/ and are isolated by GadgetHost.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.15 as T
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "gadgets" as Gadgets

EmptyPage {
    id: root
    objectName: "infoPage"

    Accessible.role: Accessible.Pane
    Accessible.name: i18n("Info dashboard")

    property bool pageActive: false
    T.StackView.onActivated: {
        kickoff.sideBar = null
        kickoff.contentArea = root
        pageActive = true
    }
    T.StackView.onDeactivated: pageActive = false
    T.StackView.onRemoved: pageActive = false

    // ── persistence ──
    property var cache: ({})
    property bool loaded: false

    function loadLayout() {
        let items = null
        try {
            const raw = Plasmoid.configuration.gadgetLayout
            if (raw && raw.length > 2) {
                const parsed = JSON.parse(raw)
                if (parsed && Array.isArray(parsed.items)) items = parsed.items
            }
        } catch (e) { items = null }
        if (!items || items.length === 0) {
            items = Gadgets.GadgetRegistry.defaultLayout.map(d => ({ id: d.id, size: d.size }))
        }
        grid.load(items)
        try {
            const rawCache = Plasmoid.configuration.gadgetCache
            cache = rawCache && rawCache.length > 2 ? JSON.parse(rawCache) : {}
        } catch (e) { cache = {} }
        /*  grid.load() is what assigns the uids, so ask it what is on the
            board rather than trusting the serialised items.  */
        pruneCache(grid.serialize())
        loaded = true
    }
    function saveLayoutNow() {
        if (!loaded) return
        Plasmoid.configuration.gadgetLayout = JSON.stringify({ v: 1, items: grid.serialize() })
    }
    function resetLayout() {
        grid.load(Gadgets.GadgetRegistry.defaultLayout.map(d => ({ id: d.id, size: d.size })))
        saveLayoutNow()
    }
    Timer {
        id: saveTimer
        interval: 700
        onTriggered: root.saveLayoutNow()
    }
    Timer {
        id: cacheSaveTimer
        interval: 1500
        onTriggered: {
            try { Plasmoid.configuration.gadgetCache = JSON.stringify(root.cache) } catch (e) {}
        }
    }
    /*  The cache is persisted into the plasmoid config and nothing ever
        removed a stale entry, so every gadget the user dropped, re-added or
        reset left its payload behind for good — a real config grew to seven
        orphaned weather and seven orphaned currency entries, each holding a
        full forecast or rate table.

        Entries are addressed either by the instance uid (host.cacheSet) or by
        the gadget id (host.sharedCacheSet), so a key is worth keeping only
        while one of those is still on the board.  */
    function pruneCache(items) {
        if (!root.cache) {
            return
        }
        const live = {}
        for (const it of items) {
            if (it.uid) live[it.uid] = true
            if (it.id) live[it.id] = true
        }
        const kept = {}
        let dropped = 0
        for (const key in root.cache) {
            const prefix = key.substring(0, key.indexOf(":"))
            if (prefix.length > 0 && live[prefix]) {
                kept[key] = root.cache[key]
            } else {
                dropped++
            }
        }
        if (dropped > 0) {
            root.cache = kept
            cacheSaveTimer.restart()
        }
    }

    function cacheGet(key) { return root.cache ? root.cache[key] : undefined }
    function cacheSet(key, value) {
        const c = Object.assign({}, root.cache)
        c[key] = value
        root.cache = c
        cacheSaveTimer.restart()
    }

    Component.onCompleted: loadLayout()

    // Escape leaves edit mode instead of closing the menu
    Keys.onEscapePressed: event => {
        if (grid.editing) { grid.editing = false; event.accepted = true }
        else event.accepted = false
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── toolbar ──
        RowLayout {
            id: toolbar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "dashboard-show"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            PC3.Label {
                text: grid.editing
                    ? i18n("Drag to reorder · use the badges to remove, resize or configure")
                    : i18n("Gadgets")
                font.weight: grid.editing ? Font.Normal : Font.DemiBold
                opacity: grid.editing ? 0.7 : 1
                elide: Text.ElideRight
            }
            PC3.Label {
                visible: !grid.editing
                text: i18n("press and hold a gadget to move it")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.5
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Columns selector
            Row {
                spacing: 2
                Repeater {
                    model: [2, 3, 4]
                    delegate: PC3.ToolButton {
                        required property int modelData
                        text: String(modelData)
                        checkable: true
                        checked: Plasmoid.configuration.gadgetColumns === modelData
                        autoExclusive: true
                        display: PC3.AbstractButton.TextOnly
                        implicitWidth: Kirigami.Units.gridUnit * 1.8
                        onClicked: Plasmoid.configuration.gadgetColumns = modelData
                        Accessible.name: i18np("%1 column", "%1 columns", modelData)
                        PC3.ToolTip.text: i18np("%1 column", "%1 columns", modelData)
                        PC3.ToolTip.visible: hovered
                    }
                }
            }

            PC3.ToolButton {
                id: editButton
                icon.name: grid.editing ? "dialog-ok-apply" : "document-edit"
                text: grid.editing ? i18n("Done") : i18n("Edit")
                display: PC3.AbstractButton.TextBesideIcon
                checkable: true
                checked: grid.editing
                onToggled: grid.editing = checked
                Accessible.name: grid.editing ? i18n("Finish editing gadgets") : i18n("Edit gadgets")
            }
            PC3.ToolButton {
                icon.name: "list-add"
                text: i18n("Add")
                display: PC3.AbstractButton.TextBesideIcon
                onClicked: gallery.open()
                Accessible.name: i18n("Add gadget")
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; opacity: 0.4 }

        // ── grid ──
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: gridWrapper.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: !grid.dragUid.length
            PC3.ScrollBar.vertical: PC3.ScrollBar { id: vbar }

            Item {
                id: gridWrapper
                width: flick.width
                implicitHeight: grid.implicitHeight + Kirigami.Units.largeSpacing * 2 + 12

                Gadgets.GadgetGrid {
                    id: grid
                    x: Kirigami.Units.largeSpacing
                    y: Kirigami.Units.largeSpacing
                    width: parent.width - Kirigami.Units.largeSpacing * 2 - Kirigami.Units.smallSpacing * 2
                    height: implicitHeight
                    columns: Math.max(2, Math.min(4, Plasmoid.configuration.gadgetColumns))
                    active: root.pageActive && kickoff.expanded
                    viewportTop: flick.contentY - y
                    viewportBottom: flick.contentY + flick.height - y
                    cacheGet: root.cacheGet
                    cacheSet: root.cacheSet
                    onLayoutChanged: saveTimer.restart()
                    onSettingsRequested: host => settingsDialog.openFor(host)
                }
            }

            // Auto-scroll while a card is dragged into a narrow zone at the
            // top/bottom edge. Speed grows with depth into the zone; the grid
            // keeps the card under the pointer and postpones reordering.
            property real dragViewportY: -1
            Connections {
                target: grid
                function onDragPointerMoved(cy) { flick.dragViewportY = cy + grid.y - flick.contentY }
            }
            Timer {
                id: autoScroll
                interval: 16
                repeat: true
                running: grid.dragUid.length > 0
                readonly property real edge: Kirigami.Units.gridUnit * 1.6
                onTriggered: {
                    const y = flick.dragViewportY
                    const maxY = Math.max(0, flick.contentHeight - flick.height)
                    let delta = 0
                    if (y >= 0 && y < edge && flick.contentY > 0)
                        delta = -(2 + 10 * (1 - y / edge))
                    else if (y > flick.height - edge && y <= flick.height && flick.contentY < maxY)
                        delta = 2 + 10 * (1 - (flick.height - y) / edge)
                    if (delta !== 0) {
                        const before = flick.contentY
                        flick.contentY = Math.max(0, Math.min(maxY, before + delta))
                        const applied = flick.contentY - before
                        grid.autoScrolling = true
                        if (applied !== 0) grid.scrollBy(applied)
                    } else if (grid.autoScrolling) {
                        grid.autoScrolling = false
                    }
                }
                onRunningChanged: if (!running) { grid.autoScrolling = false; flick.dragViewportY = -1 }
            }
        }

        // Empty state
        PlasmaExtras.PlaceholderMessage {
            visible: grid.count === 0
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit * 2
            iconName: "dashboard-show"
            text: i18n("No gadgets yet")
            explanation: i18n("Add clocks, weather, notes, live scores and more.")
            helpfulAction: Kirigami.Action {
                icon.name: "list-add"
                text: i18n("Add gadget")
                onTriggered: gallery.open()
            }
        }
    }

    Gadgets.GadgetGallery {
        id: gallery
        parent: root
        grid: grid
        onResetRequested: root.resetLayout()
    }

    Gadgets.GadgetSettingsDialog {
        id: settingsDialog
        parent: root
    }
}
