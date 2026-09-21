/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetHost — the card that hosts one gadget instance.

    Responsibilities:
      • visual frame (rounded, shadowed, accent-tinted, hover lift)
      • title bar (drag handle in normal mode), edit-mode badges
        (remove, size, settings) and a static edit affordance — accent
        outline plus a slight shrink — instead of a looping wiggle
      • drag & drop: press-and-hold anywhere (or just drag the title bar /
        the whole card in edit mode); reports to GadgetGrid which re-packs
        the others live
      • fault isolation: the gadget lives in an asynchronous Loader; a load
        error or a reported error shows a retry state inside this card only
      • the "host" API given to the gadget (see the property list)
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: host

    // ── set by GadgetGrid's Repeater ──
    required property var grid
    required property string uid
    required property string gadgetId
    required property string size        // "colsxrows"
    required property string cfgJson
    required property int modelIndex

    // ── derived ──
    readonly property var def: GadgetRegistry.byId(gadgetId)
    readonly property int cols: Math.max(1, Math.min(grid.columns, parseInt(size.split("x")[0]) || 1))
    readonly property int rows: Math.max(1, parseInt(size.split("x")[1]) || 1)
    readonly property real cellWidth: grid.cellWidth
    readonly property real cellHeight: grid.cellHeight
    readonly property bool editing: grid.editing
    // Gadgets should pause timers/network while inactive.
    readonly property bool active: grid.active && inViewport && !dragging
    property bool inViewport: true
    readonly property bool hovered: hoverHandler.hovered

    // ── API for the gadget ──
    /*  `cfgData` deliberately has no initialiser: assigning a property that
        was never bound does not destroy a binding, so the model round trip
        below stops logging "Overwriting binding on … cfg" on every save —
        noise that was drowning real gadget errors in the journal. `cfg` is
        what gadgets read, and it is never undefined.  */
    property var cfgData
    readonly property var cfg: cfgData !== undefined && cfgData !== null ? cfgData : ({})
    property string title: def ? def.name : ""
    property string subtitle: ""
    property bool loading: false
    property bool offline: false
    /*  A gadget states its colour by assigning `accentColor`; everything —
        the frame here and the gadgets themselves — reads `accent`.

        The split exists because `accent` used to be both, initialised with a
        binding to the theme. Every gadget that set its own colour destroyed
        that binding and logged "Overwriting binding on … accent" at each
        start, 23 times over. `accentColor` carries a plain literal, so
        assigning it is not overwriting a binding, and `accent` keeps the
        theme fallback for any gadget that states no colour of its own.  */
    property color accentColor: "transparent"
    readonly property color accent: accentColor.a > 0 ? accentColor : Kirigami.Theme.highlightColor
    /*  Buttons the gadget wants beside its title; see GadgetTitleBar. */
    property var titleActions: []
    property Component settingsComponent: null
    property string errorText: ""
    readonly property real contentPadding: Kirigami.Units.largeSpacing
    readonly property real contentWidth: width - 2 * contentPadding
    readonly property real contentHeight: height - 2 * contentPadding - titleBar.implicitHeight - Kirigami.Units.smallSpacing
    readonly property bool compact: cols === 1 && rows === 1
    readonly property bool wide: cols >= 2
    readonly property bool tall: rows >= 2

    function setCfg(key, value) {
        const c = Object.assign({}, cfg)
        c[key] = value
        cfgData = c
        grid.saveCfg(uid, c)
    }
    function saveCfg(obj) {
        cfgData = Object.assign({}, obj)
        grid.saveCfg(uid, cfg)
    }
    function cacheGet(key) { return grid.cacheGet(uid + ":" + key) }
    function cacheSet(key, value) { grid.cacheSet(uid + ":" + key, value) }
    // Shared (not per-instance) cache — e.g. the same feed in two gadgets
    function sharedCacheGet(key) { return grid.cacheGet(gadgetId + ":" + key) }
    function sharedCacheSet(key, value) { grid.cacheSet(gadgetId + ":" + key, value) }
    /*  Keys this gadget type has cached, without the "<gadgetId>:" prefix. */
    function sharedCacheKeys(prefix) {
        const full = gadgetId + ":" + (prefix || "")
        return grid.cacheKeys(full).map(k => k.substring(gadgetId.length + 1))
    }
    function sharedCacheRemove(key) { grid.cacheRemove(gadgetId + ":" + key) }
    function setError(text) { errorText = text }
    function clearError() { errorText = "" }
    function openSettings() { grid.openSettings(host) }
    function reload() {
        errorText = ""
        loader.active = false
        loader.active = true
    }

    // ── geometry from the grid's packing ──
    readonly property var slot: grid.positions[uid]
    // While dragging the card follows the pointer in absolute grid coordinates
    // (dragX/dragY). It must NOT be slot-relative: the card's own slot moves
    // when the grid re-packs and the card would jump under the pointer.
    property real dragX: 0
    property real dragY: 0
    // kept for API compatibility (scroll compensation adds to dragY)
    property real dragDX: 0
    property real dragDY: 0
    onDragDYChanged: if (dragging && dragDY !== 0) { dragY += dragDY; dragDY = 0 }
    onDragDXChanged: if (dragging && dragDX !== 0) { dragX += dragDX; dragDX = 0 }
    property bool dragging: false

    x: dragging ? dragX : (slot ? slot.x : 0)
    y: dragging ? dragY : (slot ? slot.y : 0)
    width: cols * cellWidth + (cols - 1) * grid.spacing
    height: rows * cellHeight + (rows - 1) * grid.spacing
    z: dragging ? 100 : (hovered ? 2 : 1)

    Behavior on x { enabled: !host.dragging && Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !host.dragging && Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: Kirigami.Units.longDuration > 0; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }

    /*  Edit mode is shown statically: the card shrinks a little and gets an
        accent outline, and the badges appear. It used to wiggle with an
        infinite rotation animation per card, and that was the source of the
        "menu freezes in Edit" complaint. Measured on the lab VM with 22
        cards: entering Edit took plasmashell from ~4 % to ~230 % CPU with a
        constant ~75 fps repaint at ~12 ms a frame. Rotation is also the worst
        possible transform here — the card's content area is clipped, and a
        rotated clip cannot use the cheap scissor path, so every card fell
        back to stencil clipping every frame. A scale keeps the axes aligned
        and animates once, on the way in and out, then costs nothing.  */
    scale: dragging ? 1.04 : (editing ? 0.965 : 1.0)
    opacity: dragging ? 0.92 : 1.0
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

    onCfgJsonChanged: {
        try { cfgData = cfgJson && cfgJson.length ? JSON.parse(cfgJson) : {} } catch (e) { cfgData = {} }
    }
    Component.onCompleted: {
        try { cfgData = cfgJson && cfgJson.length ? JSON.parse(cfgJson) : {} } catch (e) { cfgData = {} }
        if (def) {
            loader.setSource(Qt.resolvedUrl("items/" + def.source), { "host": host })
        }
    }

    HoverHandler { id: hoverHandler }

    // ── card ──
    Kirigami.ShadowedRectangle {
        id: card
        anchors.fill: parent
        radius: Kirigami.Units.largeSpacing * 1.6
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false
        border.width: host.editing ? 2 : 1
        border.color: host.editing
            ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, host.hovered ? 0.9 : 0.55)
            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, host.hovered ? 0.16 : 0.09)
        shadow.size: host.dragging ? 28 : (host.hovered ? 18 : 10)
        shadow.yOffset: host.dragging ? 8 : (host.hovered ? 4 : 2)
        shadow.color: Qt.rgba(0, 0, 0, host.dragging ? 0.38 : 0.22)
        Behavior on shadow.size { NumberAnimation { duration: Kirigami.Units.shortDuration } }

        // Accent tint: soft diagonal glow in the gadget's colour
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.16) }
                GradientStop { position: 0.55; color: Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.04) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // Subtle top highlight (glass edge)
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: 1
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }
    }

    // ── content ──
    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: host.contentPadding
        spacing: Kirigami.Units.smallSpacing

        Item {
            id: titleRow
            Layout.fillWidth: true
            implicitHeight: titleBar.implicitHeight

            // Normal mode: the title bar is the drag handle (below the labels
            // so the busy/offline icons keep their tooltips)
            MouseArea {
                anchors.fill: parent
                enabled: !host.editing
                cursorShape: Qt.OpenHandCursor
                onPressed: mouse => dragLogic.begin(mouse, true)
                onPositionChanged: mouse => dragLogic.move(mouse)
                onReleased: dragLogic.end()
                onCanceled: dragLogic.end()
            }
            GadgetTitleBar {
                id: titleBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                icon: host.def ? host.def.icon : ""
                title: host.title
                subtitle: host.subtitle
                online: host.def ? host.def.online : false
                offline: host.offline
                loading: host.loading
                actions: host.titleActions
                hostHovered: host.hovered
            }
        }

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                id: loader
                anchors.fill: parent
                asynchronous: true
                visible: status === Loader.Ready && host.errorText.length === 0
                onStatusChanged: {
                    if (status === Loader.Error) {
                        host.errorText = i18n("This gadget could not be loaded.")
                    }
                }
            }

            // Loading
            PC3.BusyIndicator {
                anchors.centerIn: parent
                running: loader.status === Loader.Loading
                visible: running
            }

            // Error / retry — isolated to this card
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                visible: host.errorText.length > 0 || loader.status === Loader.Error
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: "dialog-warning"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    Layout.alignment: Qt.AlignHCenter
                    color: Kirigami.Theme.neutralTextColor
                }
                PC3.Label {
                    text: host.errorText.length > 0 ? host.errorText : i18n("This gadget could not be loaded.")
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                }
                PC3.Button {
                    text: i18n("Try again")
                    icon.name: "view-refresh"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: host.reload()
                }
            }
        }
    }

    // ── press-and-hold anywhere (normal mode) — only where the gadget does
    // not consume the press, so buttons/text fields keep working ──
    TapHandler {
        enabled: !host.editing
        longPressThreshold: 0.45
        gesturePolicy: TapHandler.DragThreshold
        onLongPressed: {
            host.grid.setEditing(true)
        }
    }

    // ── edit mode: whole card drags ──
    MouseArea {
        id: editDragArea
        anchors.fill: parent
        z: 50
        enabled: host.editing
        visible: enabled
        cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => dragLogic.begin(mouse, false)
        onPositionChanged: mouse => dragLogic.move(mouse)
        onReleased: dragLogic.end()
        onCanceled: dragLogic.end()
    }

    QtObject {
        id: dragLogic
        property real startX: 0
        property real startY: 0
        // pointer offset inside the card at grab time (keeps the grab point fixed)
        property real grabX: 0
        property real grabY: 0
        property bool armed: false
        function begin(mouse, fromTitle) {
            const p = host.mapToItem(host.grid, mouse.x, mouse.y)
            startX = p.x; startY = p.y
            grabX = p.x - host.x; grabY = p.y - host.y
            armed = true
        }
        function move(mouse) {
            if (!armed) return
            const p = host.mapToItem(host.grid, mouse.x, mouse.y)
            if (!host.dragging) {
                if (Math.abs(p.x - startX) < 8 && Math.abs(p.y - startY) < 8) return
                host.dragX = host.x; host.dragY = host.y   // start exactly where the card is
                host.dragging = true
                host.grid.dragStarted(host.uid, host)
            }
            host.dragX = p.x - grabX; host.dragY = p.y - grabY
            // the grid targets the pointer, not the card centre
            host.grid.dragMoved(host.uid, p.x, p.y)
        }
        function end() {
            armed = false
            if (host.dragging) {
                host.dragging = false   // x/y rebind to the slot and animate there
                host.grid.dragEnded(host.uid)
            }
        }
    }

    // ── edit-mode badges ──
    component Badge : PC3.AbstractButton {
        property string iconName: ""
        property color badgeColor: Kirigami.Theme.backgroundColor
        width: Kirigami.Units.iconSizes.smallMedium + 6
        height: width
        z: 60
        hoverEnabled: true
        scale: pressed ? 0.9 : (hovered ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 80 } }
        background: Kirigami.ShadowedRectangle {
            radius: width / 2
            color: badgeColor
            shadow.size: 8
            shadow.color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
        }
        contentItem: Kirigami.Icon {
            source: iconName
            color: Kirigami.Theme.textColor
        }
    }

    Badge {
        id: removeBadge
        visible: host.editing
        iconName: "list-remove-symbolic"
        badgeColor: Kirigami.Theme.negativeBackgroundColor
        anchors { left: parent.left; top: parent.top; margins: -6 }
        Accessible.name: i18n("Remove %1", host.title)
        PC3.ToolTip.text: i18n("Remove")
        PC3.ToolTip.visible: hovered
        onClicked: host.grid.removeGadget(host.uid)
    }
    Badge {
        id: sizeBadge
        visible: host.editing && host.def && host.def.sizes.length > 1
        iconName: "transform-scale-symbolic"
        anchors { right: parent.right; bottom: parent.bottom; margins: -6 }
        Accessible.name: i18n("Change size of %1", host.title)
        PC3.ToolTip.text: i18n("Size: %1 — click to change", host.size)
        PC3.ToolTip.visible: hovered
        onClicked: host.grid.cycleSize(host.uid)
    }
    Badge {
        id: settingsBadge
        visible: host.settingsComponent !== null && (host.editing || host.hovered)
        iconName: "configure-symbolic"
        anchors { right: parent.right; top: parent.top; margins: -6 }
        opacity: host.editing ? 1 : 0.85
        Accessible.name: i18n("Configure %1", host.title)
        PC3.ToolTip.text: i18n("Configure")
        PC3.ToolTip.visible: hovered
        onClicked: host.openSettings()
    }
}
