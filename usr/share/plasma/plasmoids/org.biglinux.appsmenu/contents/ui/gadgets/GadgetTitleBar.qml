/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetTitleBar — the slim header every gadget card shares: icon, title,
    optional subtitle/status at the right. Owned by GadgetHost (it is also the
    drag handle in normal mode), so gadgets stay focused on content.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
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

    spacing: Kirigami.Units.smallSpacing
    implicitHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing

    Kirigami.Icon {
        source: bar.icon
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
