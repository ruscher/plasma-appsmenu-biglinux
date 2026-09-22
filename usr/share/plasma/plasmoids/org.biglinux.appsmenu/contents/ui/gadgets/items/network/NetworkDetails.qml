/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    NetworkDetails — the connection that carries the default route, described
    the way Plasma's own network applet describes it.

    plasma-nm's NetworkModel already publishes, for every active connection,
    a ConnectionDetailsModel: sectioned, localised label/value rows (Ethernet
    or Wi-Fi first, then IPv4, then IPv6, each only when it exists). Reusing
    it means no parsing of /sys or nmcli, no invented fields, and no
    placeholder where the system has no value.

    What the model does not say is which active connection is the primary
    one. With a single candidate that is settled; with several, NetworkManager
    is asked once over D-Bus for its PrimaryConnection, and the answer is
    matched against ConnectionPathRole. Loopback and VPNs are never the
    primary connection; an active VPN is mentioned separately.

    Kept in its own file so that the module import is isolated: the gadget
    loads it with a Loader and shows a plain message if plasma-nm's QML
    plugin is not installed.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.networkmanagement as PlasmaNM

Item {
    id: details
    property var host: null
    property bool compact: false

    /*  NetworkManagerQt connection types (ConnectionSettings::ConnectionType). */
    readonly property var typeNames: ({
        13: i18nc("@title network connection type", "Ethernet"),
        14: i18nc("@title network connection type", "Wi-Fi"),
        11: i18nc("@title network connection type", "VPN"),
        19: i18nc("@title network connection type", "WireGuard"),
        4:  i18nc("@title network connection type", "Bridge"),
        3:  i18nc("@title network connection type", "Bond"),
        15: i18nc("@title network connection type", "Team"),
        10: i18nc("@title network connection type", "VLAN"),
        17: i18nc("@title network connection type", "Tunnel"),
        2:  i18nc("@title network connection type", "Bluetooth"),
        5:  i18nc("@title network connection type", "Mobile broadband"),
        6:  i18nc("@title network connection type", "Mobile broadband")
    })
    readonly property var typeIcons: ({
        13: "network-wired-symbolic", 14: "network-wireless-symbolic", 11: "network-vpn-symbolic",
        19: "network-vpn-symbolic", 2: "network-bluetooth-symbolic", 5: "network-mobile-symbolic",
        6: "network-mobile-symbolic"
    })
    function isVpn(t) { return t === 11 || t === 19 }

    PlasmaNM.NetworkModel { id: nm }

    /*  Row indices of activated, non-loopback, non-VPN connections. */
    property var candidates: []
    property var vpns: []
    property int primaryRow: -1
    /*  Settings path of NM's PrimaryConnection, when it had to be asked. */
    property string primaryPath: ""

    function rescan() {
        const cands = [], vpn = []
        for (let i = 0; i < nm.rowCount(); i++) {
            const idx = nm.index(i, 0)
            if (nm.data(idx, PlasmaNM.NetworkModel.ConnectionStateRole) !== PlasmaNM.Enums.Activated) continue
            const type = nm.data(idx, PlasmaNM.NetworkModel.TypeRole)
            if (type === 20) continue                        // loopback
            if (isVpn(type)) { vpn.push(i); continue }
            cands.push(i)
        }
        candidates = cands
        vpns = vpn
        if (cands.length <= 1) {
            primaryRow = cands.length ? cands[0] : -1
        } else if (primaryPath.length) {
            pickByPath()
        } else {
            primaryRow = cands[0]                             // best guess until D-Bus answers
            askPrimary()
        }
    }
    function pickByPath() {
        for (const i of candidates) {
            if (nm.data(nm.index(i, 0), PlasmaNM.NetworkModel.ConnectionPathRole) === primaryPath) { primaryRow = i; return }
        }
        primaryRow = candidates.length ? candidates[0] : -1
    }

    /*  Two fixed D-Bus property reads, run only when more than one connection
        is active and only when the set of active connections changes — no
        polling, no user data in the command line.  */
    P5Support.DataSource {
        id: bus
        engine: "executable"
        readonly property string nmService: "org.freedesktop.NetworkManager"
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = String(data && data.stdout ? data.stdout : "")
            const m = /^o "(\/org\/freedesktop\/NetworkManager\/[A-Za-z0-9_\/]+)"/.exec(out.trim())
            if (!m) return
            if (source.indexOf(" PrimaryConnection") !== -1) {
                connectSource("busctl --system get-property " + nmService + " " + m[1] + " org.freedesktop.NetworkManager.Connection.Active Connection")
            } else {
                details.primaryPath = m[1]
                details.pickByPath()
            }
        }
    }
    function askPrimary() {
        bus.connectSource("busctl --system get-property " + bus.nmService + " /org/freedesktop/NetworkManager org.freedesktop.NetworkManager PrimaryConnection")
    }

    Connections {
        target: nm
        function onRowsInserted() { rescanTimer.restart() }
        function onRowsRemoved() { rescanTimer.restart() }
        function onModelReset() { rescanTimer.restart() }
        function onDataChanged() { rescanTimer.restart() }
    }
    /*  The model emits bursts of changes while a connection comes up;
        one rescan after the burst is enough.  */
    Timer { id: rescanTimer; interval: 400; onTriggered: { details.primaryPath = ""; details.rescan() } }
    Component.onCompleted: rescanTimer.start()

    readonly property var primaryIndex: primaryRow >= 0 ? nm.index(primaryRow, 0) : null
    readonly property string primaryName: primaryIndex ? String(nm.data(primaryIndex, PlasmaNM.NetworkModel.NameRole)) : ""
    readonly property int primaryType: primaryIndex ? Number(nm.data(primaryIndex, PlasmaNM.NetworkModel.TypeRole)) : 0
    readonly property var detailsModel: primaryIndex ? nm.data(primaryIndex, PlasmaNM.NetworkModel.ConnectionDetailsModelRole) : null
    readonly property string vpnNames: vpns.map(i => String(nm.data(nm.index(i, 0), PlasmaNM.NetworkModel.NameRole))).join(", ")

    /*  Speeds, signal levels and the like are read, not pasted anywhere. */
    function copyable(value) { return value.length > 0 && !/(\/s|%|bit\/s|Bit\/s)\s*$/i.test(value) }

    TextEdit { id: copyHelper; visible: false }
    function copy(value) { copyHelper.text = value; copyHelper.selectAll(); copyHelper.copy(); copyHelper.text = "" }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: details.primaryRow >= 0
            Kirigami.Icon {
                source: details.typeIcons[details.primaryType] || "network-wired-symbolic"
                fallback: "network-wired"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PC3.Label {
                text: details.typeNames[details.primaryType] || i18nc("@title network connection type", "Connection")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            PC3.Label {
                text: details.primaryName
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
        PC3.Label {
            visible: details.vpns.length > 0
            text: i18nc("@info active VPN connections", "VPN: %1", details.vpnNames)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.75
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: details.detailsModel
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: rows.contentHeight > rows.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
            }

            delegate: Item {
                id: row
                required property var model
                readonly property bool isSection: model.IsSection === true
                readonly property string label: isSection ? String(model.SectionTitle || "") : String(model.DetailLabel || "")
                readonly property string value: isSection ? "" : String(model.DetailValue || "")
                readonly property bool canCopy: !isSection && details.copyable(value)
                width: rows.width
                implicitHeight: isSection ? sectionLabel.implicitHeight + Kirigami.Units.smallSpacing * 1.5
                                          : Math.max(valueCol.implicitHeight, copyButton.implicitHeight) + 2
                height: implicitHeight

                PC3.Label {
                    id: sectionLabel
                    visible: row.isSection
                    text: row.label
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    font.weight: Font.DemiBold
                    opacity: 0.55
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    Accessible.role: Accessible.Heading
                }
                ColumnLayout {
                    id: valueCol
                    visible: !row.isSection
                    anchors.left: parent.left
                    anchors.right: copyButton.visible ? copyButton.left : parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    PC3.Label {
                        text: row.label
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        opacity: 0.6
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: row.value
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.family: /[0-9a-f]{2}:[0-9a-f]{2}/i.test(row.value) || /\d+\.\d+\.\d+\.\d+/.test(row.value) || row.value.indexOf(":") !== -1 ? "monospace" : Kirigami.Theme.defaultFont.family
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }
                PC3.ToolButton {
                    id: copyButton
                    visible: row.canCopy
                    property bool copied: false
                    icon.name: copied ? "dialog-ok-symbolic" : "edit-copy-symbolic"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { details.copy(row.value); copied = true; copiedTimer.restart() }
                    Timer { id: copiedTimer; interval: 1400; onTriggered: copyButton.copied = false }
                    Accessible.name: i18nc("@action:button %1 is the field name, e.g. IPv4 address", "Copy %1", row.label)
                    PC3.ToolTip.text: copied ? i18nc("@info:tooltip", "Copied") : Accessible.name
                    PC3.ToolTip.visible: hovered || copied
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        PC3.Label {
            visible: details.primaryRow < 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: i18n("Not connected")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }
}
