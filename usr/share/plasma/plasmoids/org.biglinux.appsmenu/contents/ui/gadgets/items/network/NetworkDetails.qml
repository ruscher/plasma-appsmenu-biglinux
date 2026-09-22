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

    /*  plasma-nm's ConnectionDetailsModel does not publish role *names* to
        QML: in a delegate, `model.DetailLabel` and its siblings are all
        `undefined`, which is why this panel showed a correct heading over
        fourteen blank rows. The values are there — the model answers to the
        numeric roles below, which are `Qt::UserRole + 1…4` in the order
        plasma-nm declares them. Read once into plain objects rather than
        role-hunting in every delegate.  */
    readonly property int roleIsSection: 257
    readonly property int roleSectionTitle: 258
    readonly property int roleDetailLabel: 259
    readonly property int roleDetailValue: 260

    property var rowsData
    readonly property var detailRows: rowsData !== undefined ? rowsData : []
    /*  True when the model has rows but none of them carries a label or a
        value: plasma-nm changed its roles and this file needs updating.
        Better to say so than to show a panel of empty lines. */
    readonly property bool rolesUnreadable: detailsModel && detailsModel.rowCount() > 0 && detailRows.length === 0

    function rebuildRows() {
        const m = detailsModel
        const out = []
        if (m) {
            for (let r = 0; r < m.rowCount(); r++) {
                const i = m.index(r, 0)
                const section = m.data(i, roleIsSection) === true
                const title = String(m.data(i, roleSectionTitle) || "")
                const label = String(m.data(i, roleDetailLabel) || "")
                const value = String(m.data(i, roleDetailValue) || "")
                if (section ? !title.length : !(label.length || value.length)) {
                    continue
                }
                out.push({ section: section, title: title, label: label, value: value })
            }
        }
        rowsData = out
    }
    onDetailsModelChanged: rebuildRows()
    Connections {
        target: details.detailsModel
        ignoreUnknownSignals: true
        function onDataChanged() { details.rebuildRows() }
        function onRowsInserted() { details.rebuildRows() }
        function onRowsRemoved() { details.rebuildRows() }
        function onModelReset() { details.rebuildRows() }
    }

    /*  Row indices of activated, non-loopback, non-VPN connections. */
    property var candidates: []
    property var vpns: []
    property int primaryRow: -1
    /*  Settings path of NM's PrimaryConnection, when it had to be asked. */
    property string primaryPath: ""

    /*  A fingerprint of the active set, so that the constant `dataChanged`
        traffic from the model (rates, signal levels) does not keep throwing
        away an answer D-Bus already gave us. */
    property string candidateKey: ""

    /*  When the primary has to be guessed, a real uplink beats a container
        bridge or a tunnel — this machine has three Docker bridges active
        and any of them could otherwise have been picked. */
    readonly property var uplinkFirst: ({ 13: 0, 14: 0, 5: 1, 6: 1, 19: 8, 11: 8, 4: 9, 17: 9, 10: 9, 3: 9, 15: 9 })
    function uplinkRank(type) { return uplinkFirst[type] !== undefined ? uplinkFirst[type] : 5 }

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
        cands.sort((a, b) => uplinkRank(nm.data(nm.index(a, 0), PlasmaNM.NetworkModel.TypeRole))
                            - uplinkRank(nm.data(nm.index(b, 0), PlasmaNM.NetworkModel.TypeRole)))
        candidates = cands
        vpns = vpn

        const key = cands.map(i => String(nm.data(nm.index(i, 0), PlasmaNM.NetworkModel.ConnectionPathRole))).join("|")
        if (key !== candidateKey) {
            candidateKey = key
            primaryPath = ""
        }

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
    Timer { id: rescanTimer; interval: 400; onTriggered: details.rescan() }
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
            model: details.detailRows
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: rows.contentHeight > rows.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
            }

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool isSection: modelData.section
                readonly property string label: isSection ? modelData.title : modelData.label
                readonly property string value: isSection ? "" : modelData.value
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
            visible: details.primaryRow < 0 || details.rolesUnreadable
            Layout.fillWidth: true
            Layout.fillHeight: true
            /*  The second case is plasma-nm having changed the numeric roles
                this file reads. Saying so beats a panel of blank lines,
                which is exactly how that failure looked before. */
            text: details.rolesUnreadable
                ? i18n("This version of the network service reports its details in a way this gadget does not understand.")
                : i18n("Not connected")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }
}
