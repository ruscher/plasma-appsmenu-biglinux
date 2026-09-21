/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetTitleBar — the slim header every gadget card shares: icon, title,
    optional actions, subtitle/status at the right. Owned by GadgetHost (it is
    also the drag handle in normal mode), so gadgets stay focused on content.

    `actions` is a plain list of QtQuick Controls Actions a gadget publishes
    through `host.titleActions`. Keeping it generic means a gadget that wants a
    button next to its title — Calendar's "Today", say — does not have to be
    special-cased in here.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

RowLayout {
    id: bar
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool online: false
    property bool offline: false   // online gadget currently without network
    property bool loading: false
    /*  Actions (QQC2.Action) the gadget publishes for its own title bar. */
    property var actions: []
    /*  The card reports hover so the buttons can stay discreet until needed. */
    property bool hostHovered: false

    spacing: Kirigami.Units.smallSpacing
    implicitHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing

    Kirigami.Icon {
        source: bar.icon
        /*  The installed theme inherits only hicolor, so a name it does not
            carry would leave an empty gap rather than fall through to Breeze. */
        fallback: "dialog-information"
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        opacity: 0.85
        visible: bar.icon.length > 0
    }
    PC3.Label {
        text: bar.title
        font.weight: Font.DemiBold
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.8
        elide: Text.ElideRight
        Layout.fillWidth: true
        Accessible.role: Accessible.Heading
        Accessible.name: bar.title
    }
    Repeater {
        model: bar.actions
        delegate: PC3.ToolButton {
            required property var modelData

            action: modelData
            display: QQC2.AbstractButton.IconOnly
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4
            implicitHeight: implicitWidth
            opacity: bar.hostHovered ? 0.9 : 0.45

            Accessible.name: modelData.text
            PC3.ToolTip.text: modelData.text
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    PC3.BusyIndicator {
        visible: bar.loading
        running: visible
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
    }
    Kirigami.Icon {
        visible: bar.offline
        source: "network-disconnect-symbolic"
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        color: Kirigami.Theme.negativeTextColor
        PC3.ToolTip.text: i18n("Offline — showing last data")
        PC3.ToolTip.visible: offlineHover.hovered
        HoverHandler { id: offlineHover }
    }
    PC3.Label {
        visible: bar.subtitle.length > 0
        text: bar.subtitle
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.55
        elide: Text.ElideRight
        Layout.maximumWidth: Kirigami.Units.gridUnit * 9
    }
}
