/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Gallery — slideshow of a local folder with crossfade + slow zoom.
    cfg: { folder: "file:///…", interval: seconds }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import Qt.labs.folderlistmodel 2.15
import Qt.labs.platform as Platform
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import "../lib/GadgetNet.js" as Net

Item {
    id: gallery
    required property var host

    readonly property string defaultFolder: Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
    readonly property string folder: host.cfg.folder && host.cfg.folder.length ? host.cfg.folder : defaultFolder
    readonly property int intervalMs: Math.max(3, host.cfg.interval || 8) * 1000
    property int index: 0
    property bool front: true   // which layer is on top

    Component.onCompleted: { host.accentColor = "#06b6d4"; host.settingsComponent = settings }
    Binding { target: gallery.host; property: "subtitle"; value: files.count > 0 ? (gallery.index + 1) + "/" + files.count : "" }

    onFolderChanged: { brokenData = ({}); brokenCount = 0 }

    FolderListModel {
        id: files
        folder: gallery.folder
        /*  Only formats Qt can really decode here. Checked against
            QImageReader.supportedImageFormats() on the target system rather
            than assumed: kimageformats supplies avif, heif/heic and jxl, and
            Qt itself the rest. A system without kimageformats simply fails to
            decode those three, which the slide handler below survives.

            `caseSensitive: false` replaces the hand-written "*.JPG" variants,
            which only covered three of the extensions anyway.  */
        nameFilters: [
            "*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp",
            "*.webp", "*.tif", "*.tiff",
            "*.avif", "*.heic", "*.heif", "*.jxl"
        ]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
    }
    /*  Files that failed to decode — a format this system has no plugin for,
        or a truncated download. They are remembered so the slideshow stops
        returning to them, and so a folder full of them cannot spin forever. */
    property var brokenData
    readonly property var broken: brokenData !== undefined ? brokenData : ({})
    property int brokenCount: 0

    function wrap(i) { return files.count > 0 ? ((i % files.count) + files.count) % files.count : 0 }
    function urlAt(i) { return files.count > 0 ? files.get(wrap(i), "fileUrl") : "" }

    /*  First index from `i` in direction `dir` that has not already failed;
        -1 when every picture in the folder is unreadable.  */
    function usableFrom(i, dir) {
        for (let n = 0; n < files.count; n++) {
            const c = wrap(i + dir * n)
            if (!broken[String(urlAt(c))]) {
                return c
            }
        }
        return -1
    }

    function show(i, dir) {
        if (files.count === 0) {
            return
        }
        const step = dir === undefined ? 1 : dir
        const target = usableFrom(i, step)
        if (target < 0) {
            return
        }
        index = target
        if (front) { back.source = urlAt(index) } else { frontImg.source = urlAt(index) }
        front = !front
    }

    /*  A picture the decoder cannot read is skipped, not fatal: the gadget
        logs which file and moves to the next one. Only the file name reaches
        the log, never the contents.  */
    function markBroken(url, dir) {
        const u = String(url || "")
        if (!u.length || broken[u]) {
            return
        }
        const b = Object.assign({}, broken)
        b[u] = true
        brokenData = b
        brokenCount++
        console.warn("GalleryGadget: cannot decode",
                     u.substring(u.lastIndexOf("/") + 1), "— skipping it")
        if (brokenCount < files.count) {
            skipBroken.dir = dir === undefined ? 1 : dir
            skipBroken.restart()
        }
    }

    /*  Deferred by a tick: advancing straight out of onStatusChanged would
        reassign the source of the very image still reporting its status. */
    Timer {
        id: skipBroken
        property int dir: 1
        interval: 1
        onTriggered: gallery.show(gallery.index + dir, dir)
    }
    Timer {
        interval: gallery.intervalMs
        running: gallery.host.active && files.count > 1 && !gallery.host.hovered
        repeat: true
        onTriggered: gallery.show(gallery.index + 1, 1)
    }
    Connections {
        target: files
        function onCountChanged() { if (files.count > 0 && frontImg.source == "" ) { frontImg.source = gallery.urlAt(0); gallery.front = true } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.largeSpacing
        color: Qt.rgba(0, 0, 0, 0.25)
        clip: true

        component Slide : Image {
            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1024
            sourceSize.height: 1024
            smooth: true
            property bool shown: false
            opacity: shown ? 1 : 0
            /*  The zoom lasts as long as the crossfade. It used to run for the
                whole interval, which meant the popup was repainting at vsync
                for as long as this gadget was on screen — the effect is still
                there at every transition, and the card is still between them.  */
            scale: shown ? 1.04 : 1.0
            Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
            Behavior on scale { enabled: shown; NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            onStatusChanged: {
                if (status === Image.Ready) {
                    shown = true
                } else if (status === Image.Error) {
                    gallery.markBroken(source, 1)
                }
            }
            onSourceChanged: shown = false
        }
        Slide { id: back; z: gallery.front ? 0 : 1 }
        Slide { id: frontImg; z: gallery.front ? 1 : 0 }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { gallery.forceActiveFocus(); const u = gallery.urlAt(gallery.index); if (u) Qt.openUrlExternally(u) }
        }

        /*  Previous / Next. They used to be bare tool buttons at opacity 0
            until the card was hovered, drawn straight over the photograph —
            so with no hover there was nothing, and with hover a grey glyph on
            whatever the picture happened to be. Now each sits on a translucent
            disc that reads on any picture, stays faintly present at rest so it
            can be discovered, and comes fully up on hover or keyboard focus.  */
        component NavButton : PC3.AbstractButton {
            id: nav
            required property string iconName
            property bool atLeft: false
            width: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
            height: width
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            opacity: files.count > 1 ? (gallery.host.hovered || gallery.activeFocus || hovered ? 0.95 : 0.35) : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            background: Rectangle {
                radius: width / 2
                color: Qt.rgba(0, 0, 0, nav.pressed ? 0.75 : (nav.hovered ? 0.6 : 0.45))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
            }
            contentItem: Kirigami.Icon {
                source: nav.iconName
                color: "white"
                isMask: true
            }
            PC3.ToolTip.text: nav.Accessible.name
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        NavButton {
            iconName: "go-previous-symbolic"
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.smallSpacing
            onClicked: gallery.show(gallery.index - 1, -1)
            Accessible.name: i18n("Previous picture")
        }
        NavButton {
            iconName: "go-next-symbolic"
            anchors.right: parent.right
            anchors.rightMargin: Kirigami.Units.smallSpacing
            onClicked: gallery.show(gallery.index + 1, 1)
            Accessible.name: i18n("Next picture")
        }
    }

    /*  Left / Right step through the pictures while the gadget has focus,
        which it takes on click. Other keys are left alone so the menu's own
        navigation (Tab, Escape, Up/Down between rows) keeps working.  */
    activeFocusOnTab: true
    Keys.onLeftPressed: event => { gallery.show(gallery.index - 1, -1); event.accepted = true }
    Keys.onRightPressed: event => { gallery.show(gallery.index + 1, 1); event.accepted = true }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: files.count === 0
        Kirigami.Icon { source: "folder-pictures"; Layout.preferredWidth: Kirigami.Units.iconSizes.large; Layout.preferredHeight: Kirigami.Units.iconSizes.large; Layout.alignment: Qt.AlignHCenter; opacity: 0.45 }
        PC3.Label { text: i18n("No pictures in this folder"); opacity: 0.7; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        PC3.Button { text: i18n("Choose folder"); icon.name: "folder-open"; Layout.alignment: Qt.AlignHCenter; onClicked: gallery.host.openSettings() }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                RowLayout {
                    Kirigami.FormData.label: i18n("Folder:")
                    QQC2.TextField {
                        id: folderField
                        Layout.fillWidth: true
                        text: host.cfg.folder || gallery.defaultFolder
                        onEditingFinished: host.setCfg("folder", text.trim())
                    }
                    PC3.Button {
                        icon.name: "folder-open"
                        onClicked: folderDialog.open()
                        Accessible.name: i18n("Browse")
                    }
                    Platform.FolderDialog {
                        id: folderDialog
                        currentFolder: host.cfg.folder || gallery.defaultFolder
                        onAccepted: { folderField.text = String(folder); host.setCfg("folder", String(folder)) }
                    }
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Seconds per picture:")
                    from: 3; to: 120
                    value: host.cfg.interval || 8
                    onValueModified: host.setCfg("interval", value)
                }
            }
        }
    }
}
