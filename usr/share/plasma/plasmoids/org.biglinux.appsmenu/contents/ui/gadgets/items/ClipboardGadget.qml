/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Clipboard gadget — the very same Klipper history Plasma shows on SUPER+V,
    not a second clipboard of our own: `Clipboard.HistoryModel` is a proxy over
    the one history object living in this plasmashell process.

    Roles it publishes, confirmed against Plasma 6.7 (klipperplugin.qmltypes
    and the stock delegates in org/kde/plasma/private/clipboard):

        display    string   the text, or a label for images
        decoration variant  usable directly as an Image source
        imageSize  size     the original pixel size of an image entry
        uuid       string   identity, for moveToTop()/remove()
        type       int      2 = text, 4 = image, 8 = URL

    Privacy: contents can be masked (cfg.masked), never reach the network, and
    are never written to the log — not even truncated.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.clipboard as Clipboard

/*  The root id must not be `clip`: every Item — every delegate included — has
    a built-in `clip` property, which shadows the id inside them. That is what
    made this gadget look broken. `clip.preview(…)` resolved to `false.preview`
    and threw "Property 'preview' of object false is not a function" for every
    row, so each delegate rendered empty while the header still counted the
    entries: the reported "8 items and an empty list".  */
Item {
    id: clipboard
    required property var host

    readonly property bool masked: host.cfg.masked === true

    /*  Type values come from Plasma's own DelegateChooser (ClipboardMenu.qml). */
    readonly property int typeText: 2
    readonly property int typeImage: 4
    readonly property int typeUrl: 8

    /*  A tooltip has to stay readable, so the full text is bounded too. */
    readonly property int tooltipLimit: 2000

    Clipboard.HistoryModel { id: history }

    Component.onCompleted: {
        host.accentColor = "#64748b"
        host.settingsComponent = settings
    }

    Binding {
        target: clipboard.host
        property: "subtitle"
        value: history.count > 0 ? i18np("%1 item", "%1 items", history.count) : ""
    }

    function iconFor(type) {
        if (type === clipboard.typeImage) {
            return "image-x-generic"
        }
        if (type === clipboard.typeUrl) {
            return "link"
        }
        return "text-x-generic"
    }

    /*  One-line summary for the row. Klipper labels an image "▨ 120x80",
        which is neither translatable nor useful next to a thumbnail, so the
        size role is used instead.  */
    function preview(text, type, size) {
        if (clipboard.masked) {
            return "••••••••••••"
        }
        if (type === clipboard.typeImage) {
            return size && size.width > 0
                ? i18nc("image dimensions", "Image · %1 × %2", size.width, size.height)
                : i18n("Image")
        }
        const s = String(text || "").replace(/\s+/g, " ").trim()
        return s.length > 90 ? s.substring(0, 90) + "…" : s
    }

    /*  Full content for the tooltip. Masking wins here as well — revealing on
        hover what the user asked to hide would defeat the setting.  */
    function fullText(text, type) {
        if (clipboard.masked) {
            return i18n("Contents are hidden.")
        }
        const s = String(text || "")
        return s.length > clipboard.tooltipLimit
            ? s.substring(0, clipboard.tooltipLimit) + "…"
            : s
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            /*  Vertical only: rows elide instead of scrolling sideways. */
            clip: true
            model: history
            spacing: 1
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            /*  The list scrolls now. It used to hide every row past a fixed
                count with `visible: index < maxRows`, which silently dropped
                the rest of the history instead of letting the user reach it. */
            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded
                                                         : QQC2.ScrollBar.AlwaysOff
            }

            delegate: PC3.ItemDelegate {
                id: row

                required property var model
                required property int index
                required property var uuid
                required property int type
                required property var decoration
                required property size imageSize

                width: list.width
                hoverEnabled: true

                readonly property bool isImage: type === clipboard.typeImage
                readonly property bool showThumbnail: isImage && !clipboard.masked

                onClicked: history.moveToTop(row.uuid)

                Accessible.name: clipboard.preview(row.model.display, row.type, row.imageSize)
                Accessible.description: i18n("Click to copy")

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    /*  Image entries get a real thumbnail; everything else a
                        small type icon. Both occupy the same slot so rows stay
                        aligned.  */
                    Item {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small

                        Kirigami.Icon {
                            anchors.fill: parent
                            visible: !row.showThumbnail
                            source: clipboard.iconFor(row.type)
                            opacity: 0.6
                        }
                        Image {
                            anchors.fill: parent
                            visible: row.showThumbnail
                            source: row.showThumbnail ? row.decoration : ""
                            sourceSize.width: Kirigami.Units.iconSizes.small
                            sourceSize.height: Kirigami.Units.iconSizes.small
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    PC3.Label {
                        text: clipboard.preview(row.model.display, row.type, row.imageSize)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.fillWidth: true
                    }

                    PC3.ToolButton {
                        icon.name: "edit-delete"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        opacity: row.hovered ? 1 : 0
                        onClicked: history.remove(row.uuid)
                        Accessible.name: i18n("Remove entry")

                        PC3.ToolTip.text: i18n("Remove entry")
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                /*  Hover reveals the whole entry. A tooltip is a Popup, so it
                    is free of the gadget's clipping, but it must not grow
                    without limit: text wraps inside a fixed width and an image
                    preview is capped in both directions.  */
                PC3.ToolTip {
                    id: tip
                    visible: row.hovered
                    delay: Kirigami.Units.toolTipDelay

                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Image {
                            visible: row.showThumbnail
                            source: visible ? row.decoration : ""
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                            Layout.maximumHeight: Kirigami.Units.gridUnit * 12
                            Layout.preferredWidth: Math.min(row.imageSize.width,
                                                            Kirigami.Units.gridUnit * 16)
                            Layout.preferredHeight: Math.min(row.imageSize.height,
                                                             Kirigami.Units.gridUnit * 12)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        PC3.Label {
                            text: row.isImage && !clipboard.masked
                                ? i18nc("image dimensions", "Image · %1 × %2",
                                        row.imageSize.width, row.imageSize.height)
                                : clipboard.fullText(row.model.display, row.type)
                            wrapMode: Text.Wrap
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }

                        PC3.Label {
                            text: i18n("Click to copy")
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: history.count > 0

            PC3.ToolButton {
                icon.name: clipboard.masked ? "view-visible" : "view-hidden"
                text: clipboard.masked ? i18n("Show") : i18n("Hide")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                onClicked: clipboard.host.setCfg("masked", !clipboard.masked)
                Accessible.name: clipboard.masked ? i18n("Show clipboard contents")
                                                  : i18n("Hide clipboard contents")
            }

            Item { Layout.fillWidth: true }

            PC3.ToolButton {
                icon.name: "edit-clear-history"
                text: i18n("Clear")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                onClicked: confirmClear.open()
                Accessible.name: i18n("Clear clipboard history")
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: history.count === 0

        Kirigami.Icon {
            source: "edit-paste"
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: i18n("Clipboard is empty")
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
        }
    }

    QQC2.Popup {
        id: confirmClear
        parent: clipboard.host
        modal: true
        anchors.centerIn: parent
        padding: Kirigami.Units.largeSpacing
        background: Kirigami.ShadowedRectangle {
            color: Kirigami.Theme.backgroundColor
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            radius: Kirigami.Units.largeSpacing
            shadow.size: 20
            shadow.color: Qt.rgba(0, 0, 0, 0.5)
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            PC3.Label {
                text: i18n("Clear the whole clipboard history?")
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                PC3.Button { text: i18n("Cancel"); onClicked: confirmClear.close() }
                PC3.Button {
                    text: i18n("Clear")
                    icon.name: "edit-clear-history"
                    onClicked: { history.clearHistory(); confirmClear.close() }
                }
            }
        }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Privacy:")
                    text: i18n("Mask contents until I choose to show them")
                    checked: host.cfg.masked === true
                    onToggled: host.setCfg("masked", checked)
                }
            }
            PC3.Label {
                text: i18n("Entries come from Plasma's clipboard history (Klipper) and never leave this computer.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
        }
    }
}
