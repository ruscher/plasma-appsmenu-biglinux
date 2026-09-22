/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetGallery — "Add gadget" sheet: browse the registry by category and
    add gadgets to the grid. Also offers "Restore default layout".
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

QQC2.Popup {
    id: gallery
    required property var grid
    signal resetRequested()

    modal: true
    dim: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 2 : 600, Kirigami.Units.gridUnit * 40)
    height: Math.min(parent ? parent.height - Kirigami.Units.gridUnit * 2 : 500, Kirigami.Units.gridUnit * 30)
    padding: Kirigami.Units.largeSpacing

    property string categoryFilter: "all"

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration }
    }

    background: Kirigami.ShadowedRectangle {
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        radius: Kirigami.Units.largeSpacing * 1.5
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        shadow.size: 32
        shadow.color: Qt.rgba(0, 0, 0, 0.5)
    }
    QQC2.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "list-add"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            Kirigami.Heading {
                text: i18n("Add gadget")
                level: 2
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "window-close"
                onClicked: gallery.close()
                Accessible.name: i18n("Close")
            }
        }

        // Category chips
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PC3.ToolButton {
                text: i18nc("gadget category filter", "All")
                checkable: true
                checked: gallery.categoryFilter === "all"
                onClicked: gallery.categoryFilter = "all"
            }
            Repeater {
                model: GadgetRegistry.categories
                delegate: PC3.ToolButton {
                    required property var modelData
                    text: modelData.name
                    checkable: true
                    checked: gallery.categoryFilter === modelData.id
                    onClicked: gallery.categoryFilter = modelData.id
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridView {
                id: view
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 13))))
                cellHeight: Kirigami.Units.gridUnit * 7.2
                model: GadgetRegistry.gadgets.filter(g => gallery.categoryFilter === "all" || g.category === gallery.categoryFilter)

                delegate: Item {
                    id: cell
                    required property var modelData
                    width: view.cellWidth
                    height: view.cellHeight
                    readonly property bool alreadyAdded: !modelData.multiple && gallery.grid.hasGadget(modelData.id)

                    Kirigami.ShadowedRectangle {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.largeSpacing
                        color: Kirigami.Theme.backgroundColor
                        Kirigami.Theme.colorSet: Kirigami.Theme.View
                        Kirigami.Theme.inherit: false
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, cardHover.hovered ? 0.25 : 0.1)
                        shadow.size: cardHover.hovered ? 14 : 6
                        shadow.color: Qt.rgba(0, 0, 0, 0.25)
                        scale: cardHover.hovered ? 1.02 : 1
                        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        HoverHandler { id: cardHover }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: cell.modelData.icon
                                    fallback: cell.modelData.iconFallback || "dialog-information"
                                    isMask: String(cell.modelData.icon).indexOf("-symbolic") !== -1
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    PC3.Label {
                                        text: cell.modelData.name
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    RowLayout {
                                        spacing: 4
                                        Kirigami.Icon {
                                            visible: cell.modelData.online
                                            source: "network-connect-symbolic"
                                            Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.8
                                            opacity: 0.6
                                        }
                                        PC3.Label {
                                            text: cell.modelData.online ? i18n("Needs internet") : i18n("Works offline")
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.6
                                        }
                                    }
                                }
                            }
                            PC3.Label {
                                text: cell.modelData.description
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.75
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                            PC3.Button {
                                Layout.fillWidth: true
                                text: cell.alreadyAdded ? i18n("Added") : i18n("Add")
                                icon.name: cell.alreadyAdded ? "checkmark" : "list-add"
                                enabled: !cell.alreadyAdded
                                onClicked: {
                                    gallery.grid.addGadget(cell.modelData.id, cell.modelData.defaultSize)
                                    if (cell.modelData.multiple) {
                                        addedFlash.restart()
                                    }
                                }
                                SequentialAnimation {
                                    id: addedFlash
                                    NumberAnimation { target: cell; property: "scale"; to: 0.96; duration: 70 }
                                    NumberAnimation { target: cell; property: "scale"; to: 1; duration: 120; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Button {
                icon.name: "edit-undo"
                text: i18n("Restore default layout")
                onClicked: confirmReset.open()
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: i18np("%1 gadget on the dashboard", "%1 gadgets on the dashboard", gallery.grid.count)
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    QQC2.Popup {
        id: confirmReset
        modal: true
        anchors.centerIn: parent
        padding: Kirigami.Units.largeSpacing
        background: Kirigami.ShadowedRectangle {
            color: Kirigami.Theme.backgroundColor
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            radius: Kirigami.Units.largeSpacing
            shadow.size: 24
            shadow.color: Qt.rgba(0, 0, 0, 0.5)
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            PC3.Label {
                text: i18n("Replace your current gadgets with the default layout?")
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                PC3.Button { text: i18n("Cancel"); onClicked: confirmReset.close() }
                PC3.Button {
                    text: i18n("Restore")
                    icon.name: "edit-undo"
                    onClicked: { confirmReset.close(); gallery.resetRequested() }
                }
            }
        }
    }
}
