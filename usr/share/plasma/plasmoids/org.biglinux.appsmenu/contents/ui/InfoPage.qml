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
        items = migrate(items)
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
    /*  Renames a gadget has been through, applied on load so an existing
        board keeps its place and its settings instead of silently losing the
        gadget. "puzzle" was the 2048-only card; it is now one game inside
        "games", which reads the same `best` key.  */
    function migrate(items) {
        let changed = false
        const out = items.map(it => {
            if (it.id !== "puzzle") {
                return it
            }
            changed = true
            const cfg = Object.assign({}, it.cfg || {}, { game: "2048" })
            /*  1x1 no longer exists for this gadget: it now carries a game
                selector above the board. */
            const size = (it.size === "1x1" || !it.size) ? "1x2" : it.size
            return Object.assign({}, it, { id: "games", size: size, cfg: cfg })
        })
        if (changed) {
            Qt.callLater(root.saveLayoutNow)
        }
        return out
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

    /*  Listing and removal exist so a gadget can drop entries it no longer
        has any use for — the news gadget forgetting a source the user
        removed, say. Without them a dropped feed's articles would sit in the
        plasmoid config for good.  */
    function cacheKeys(prefix) {
        const out = []
        if (!root.cache) {
            return out
        }
        for (const k in root.cache) {
            if (k.indexOf(prefix) === 0) {
                out.push(k)
            }
        }
        return out
    }
    function cacheRemove(key) {
        if (!root.cache || root.cache[key] === undefined) {
            return
        }
        const c = Object.assign({}, root.cache)
        delete c[key]
        root.cache = c
        cacheSaveTimer.restart()
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
        /*  Two blocks: everything on the left fills and elides, everything on
            the right keeps its natural size. The controls therefore never move
            — not when the hint changes with edit mode, not with a long
            translation, not on a narrow menu. Before, the hint label was the
            only filler and it was hidden in edit mode, so the whole right side
            slid left every time Edit was pressed.  */
        RowLayout {
            id: toolbar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                id: toolbarLeft
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "dashboard-show"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }
                PC3.Label {
                    text: i18n("Gadgets")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: implicitWidth
                    Accessible.role: Accessible.Heading
                }
                PC3.Label {
                    text: grid.editing
                        ? i18n("Drag to reorder · use the badges to remove, resize or configure")
                        : i18n("press and hold a gadget to move it")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.55
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            RowLayout {
                id: toolbarRight
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: Kirigami.Units.smallSpacing

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
                    /*  "Edit" and "Done" differ in width, and a right-aligned
                        block moves by exactly that difference when the label
                        swaps. Sizing the button for the longer of the two, in
                        whatever language, keeps everything to its right still. */
                    TextMetrics { id: editLabel; font: editButton.font; text: i18n("Edit") }
                    TextMetrics { id: doneLabel; font: editButton.font; text: i18n("Done") }
                    Layout.preferredWidth: Math.max(editLabel.width, doneLabel.width)
                        + editButton.icon.width + editButton.spacing
                        + editButton.leftPadding + editButton.rightPadding
                }
                PC3.ToolButton {
                    icon.name: "list-add"
                    text: i18n("Add")
                    display: PC3.AbstractButton.TextBesideIcon
                    onClicked: gallery.open()
                    Accessible.name: i18n("Add gadget")
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; opacity: 0.4 }

        // ── grid ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
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
                        cacheKeys: root.cacheKeys
                        cacheRemove: root.cacheRemove
                        onLayoutChanged: saveTimer.restart()
                        onSettingsRequested: host => settingsDialog.openFor(host)
                    }
                }

                /*  Auto-scroll while a card is dragged into a zone at the top or
                    bottom edge. The zone is wide enough to hit without aiming
                    (2.6 grid units, up from 1.6) and, unlike before, it is
                    drawn while dragging so the user knows it is there. Speed
                    ramps with the square of the depth into the zone: gentle at
                    the boundary, brisk at the very edge, no jump on entry.
                    The grid keeps the card under the pointer and postpones
                    reordering until scrolling settles.  */
                property real dragViewportY: -1
                readonly property real scrollEdge: Kirigami.Units.gridUnit * 2.6
                readonly property bool inTopZone: grid.dragUid.length > 0 && dragViewportY >= 0 && dragViewportY < scrollEdge
                readonly property bool inBottomZone: grid.dragUid.length > 0 && dragViewportY > height - scrollEdge && dragViewportY <= height
                Connections {
                    target: grid
                    function onDragPointerMoved(cy) { flick.dragViewportY = cy + grid.y - flick.contentY }
                }
                Timer {
                    id: autoScroll
                    interval: 16
                    repeat: true
                    running: grid.dragUid.length > 0
                    readonly property real minStep: 1.5   // px per tick at the zone boundary (~90 px/s)
                    readonly property real maxStep: 11    // px per tick at the very edge (~660 px/s)
                    onTriggered: {
                        const y = flick.dragViewportY
                        const edge = flick.scrollEdge
                        const maxY = Math.max(0, flick.contentHeight - flick.height)
                        let delta = 0
                        if (flick.inTopZone && flick.contentY > 0) {
                            const depth = 1 - y / edge
                            delta = -(minStep + (maxStep - minStep) * depth * depth)
                        } else if (flick.inBottomZone && flick.contentY < maxY) {
                            const depth = 1 - (flick.height - y) / edge
                            delta = minStep + (maxStep - minStep) * depth * depth
                        }
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

            /*  The two zones, drawn over the viewport (not inside the content,
                so they do not scroll away) only while something is dragged. They
                take no input: the drag itself is what moves the pointer into
                them.  */
            component ScrollZone : Rectangle {
                required property bool atTop
                property bool armed: false
                readonly property bool canScroll: atTop ? flick.contentY > 0
                                                        : flick.contentY < flick.contentHeight - flick.height - 1
                anchors.left: parent.left
                anchors.right: parent.right
                height: flick.scrollEdge
                visible: opacity > 0
                opacity: grid.dragUid.length > 0 && canScroll ? (armed ? 1 : 0.55) : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                gradient: Gradient {
                    GradientStop { position: atTop ? 0 : 1; color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.22) }
                    GradientStop { position: atTop ? 1 : 0; color: "transparent" }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: parent.atTop ? "arrow-up" : "arrow-down"
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    color: Kirigami.Theme.highlightColor
                }
                Accessible.ignored: true
            }
            ScrollZone { atTop: true; anchors.top: parent.top; armed: flick.inTopZone }
            ScrollZone { atTop: false; anchors.bottom: parent.bottom; armed: flick.inBottomZone }
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
