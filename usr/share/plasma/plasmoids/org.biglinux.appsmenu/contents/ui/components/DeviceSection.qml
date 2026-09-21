/*
    SPDX-FileCopyrightText: 2026 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    DeviceSection — storage devices, from Solid.

    Kicker's ComputerModel already carries the user's places, the network
    entries and *removable* devices, but it filters fixed drives out
    (`!FixedDeviceRole` in computermodel.cpp) and exposes neither capacity,
    mounted state nor mount/unmount. This section fills exactly that gap, so
    Computer can show internal disks and manage them.

    It uses Plasma's own Solid data engines rather than a plugin of ours or a
    shell:

      hotplug     — the list of device UDIs. Event driven: sources appear and
                    disappear as devices are plugged in and out, so there is no
                    timer and no polling anywhere in this file.
      soliddevice — per device: Accessible (mounted), Size / Free Space, Icon,
                    Removable, Device Types, File Path, Label.
      its service — the "mount" and "unmount" operations.

    These are Plasma5Support engines. That is deliberate: there is no Plasma 6
    QML binding for Solid, and the alternative would be parsing lsblk/udisksctl
    output, which the brief rules out and which would be worse in every respect.

    Nothing here needs root. Mounting goes through Solid/UDisks exactly as it
    does when the user clicks a device in Dolphin.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0

ColumnLayout {
    id: root

    readonly property int count: deviceList.count

    signal focusPreviousRequested()
    signal focusNextRequested()

    spacing: 0
    visible: count > 0

    Accessible.role: Accessible.Grouping
    Accessible.name: i18nc("@title:group storage devices", "Devices")

    /* The set of device UDIs. `connectedSources: sources` makes the engine
       push changes instead of us asking for them. */
    Plasma5Support.DataSource {
        id: hotplug
        engine: "hotplug"
        connectedSources: sources
        onSourcesChanged: devices.rebuild()
    }

    Plasma5Support.DataSource {
        id: solid
        engine: "soliddevice"
        connectedSources: hotplug.sources
        onDataChanged: devices.rebuild()
    }

    /* Only storage volumes belong here: the same engine also reports cameras,
       portable media players and so on, which are not places to open. */
    function isStorage(udi) {
        const data = solid.data[udi]
        if (!data) {
            return false
        }
        if (data["Ignored"] === true) {
            return false
        }
        const types = String(data["Device Types"] || "")
        return types.indexOf("Storage Access") !== -1 || types.indexOf("Storage Volume") !== -1
    }

    function isMounted(udi) {
        const data = solid.data[udi]
        return !!data && data["Accessible"] === true
    }

    function canEject(udi) {
        const data = solid.data[udi]
        /* Optical discs and anything the system reports as removable. Solid
           tells us; we never guess from the name. */
        return !!data && (data["Removable"] === true || String(data["Device Types"] || "").indexOf("Optical") !== -1)
    }

    function deviceLabel(udi) {
        const data = solid.data[udi]
        if (!data) {
            return udi
        }
        return String(data["Label"] || data["Description"] || data["Device"] || udi)
    }

    /* "332,5 GiB free of 465,6 GiB" — both strings come pre-formatted and
       localised from the engine, so no byte arithmetic happens here. */
    function capacityText(udi) {
        const data = solid.data[udi]
        if (!data || !root.isMounted(udi)) {
            return ""
        }
        const free = String(data["Free Space Text"] || "")
        const size = String(data["Size Text"] || "")
        if (free.length === 0 || size.length === 0) {
            return ""
        }
        return i18nc("@info:usage %1 is free space, %2 is total size", "%1 free of %2", free, size)
    }

    function usedFraction(udi) {
        const data = solid.data[udi]
        if (!data || !root.isMounted(udi)) {
            return -1
        }
        const size = Number(data["Size"] || 0)
        const free = Number(data["Free Space"] || 0)
        if (!(size > 0) || !(free >= 0)) {
            return -1
        }
        return Math.max(0, Math.min(1, (size - free) / size))
    }

    function runOperation(udi, operation) {
        const service = solid.serviceForSource(udi)
        if (!service) {
            return
        }
        const job = service.operationDescription(operation)
        service.startOperationCall(job)
    }

    function openDevice(udi) {
        const data = solid.data[udi]
        if (!data) {
            return
        }
        if (root.isMounted(udi)) {
            const path = String(data["File Path"] || "")
            if (path.length > 0) {
                /* Qt.openUrlExternally hands the URL to the desktop's own
                   handler; no command line is built from the path. */
                Qt.openUrlExternally(Qt.resolvedUrl("file://" + path))
                if (kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false
                }
            }
            return
        }
        /* Not mounted: mount it, and open it once the engine reports it
           accessible (handled by pendingOpen below). */
        devices.pendingOpenUdi = udi
        root.runOperation(udi, "mount")
    }

    ListModel {
        id: devices

        /* Set while waiting for a mount we started, so the folder opens once
           and only for the device the user actually clicked. */
        property string pendingOpenUdi: ""

        function rebuild() {
            const wanted = []
            for (let i = 0; i < hotplug.sources.length; ++i) {
                const udi = hotplug.sources[i]
                if (root.isStorage(udi)) {
                    wanted.push(udi)
                }
            }

            /* Rebuild only when the set actually changed, so a free-space
               update does not throw away and recreate every delegate. */
            let same = wanted.length === devices.count
            if (same) {
                for (let j = 0; j < wanted.length; ++j) {
                    if (devices.get(j).udi !== wanted[j]) {
                        same = false
                        break
                    }
                }
            }
            if (!same) {
                devices.clear()
                for (let k = 0; k < wanted.length; ++k) {
                    devices.append({ "udi": wanted[k] })
                }
            }

            if (devices.pendingOpenUdi.length > 0 && root.isMounted(devices.pendingOpenUdi)) {
                const udi = devices.pendingOpenUdi
                devices.pendingOpenUdi = ""
                root.openDevice(udi)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "drive-harddisk"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            opacity: 0.7
        }

        PC3.Label {
            text: i18nc("@title:group storage devices", "Devices")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Accessible.role: Accessible.Heading
        }

        PC3.Label {
            text: root.count
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.6
        }

        Item { Layout.fillWidth: true }
    }

    ListView {
        id: deviceList

        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight

        interactive: false
        keyNavigationEnabled: false
        keyNavigationWraps: false
        currentIndex: -1
        model: devices

        Accessible.role: Accessible.List
        Accessible.name: i18nc("@title:group storage devices", "Devices")

        delegate: PC3.ItemDelegate {
            id: deviceDelegate

            required property string udi
            required property int index

            readonly property bool mounted: root.isMounted(udi)
            readonly property real used: root.usedFraction(udi)
            readonly property string capacity: root.capacityText(udi)

            width: deviceList.width
            implicitHeight: Kirigami.Units.gridUnit * 2.6
            hoverEnabled: true

            Accessible.role: Accessible.MenuItem
            Accessible.name: root.deviceLabel(udi)
            Accessible.description: mounted
                ? i18nc("@info:whatsthis", "Mounted. %1", capacity)
                : i18nc("@info:whatsthis", "Not mounted. Activating will mount and open it.")

            onHoveredChanged: {
                if (hovered) {
                    deviceList.currentIndex = index
                    forceActiveFocus()
                }
            }

            onClicked: root.openDevice(udi)
            Keys.onReturnPressed: event => root.openDevice(udi)
            Keys.onEnterPressed: event => root.openDevice(udi)

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: {
                        const data = solid.data[deviceDelegate.udi]
                        return (data && data["Icon"]) ? data["Icon"] : "drive-harddisk"
                    }
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    /* Dimmed while not mounted — the state is shown, not spelled out. */
                    opacity: deviceDelegate.mounted ? 1.0 : 0.6
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PC3.Label {
                        Layout.fillWidth: true
                        text: root.deviceLabel(deviceDelegate.udi)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        visible: deviceDelegate.capacity.length > 0

                        /* A thin bar rather than a number-heavy row. */
                        Rectangle {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                            Layout.preferredHeight: Math.round(Kirigami.Units.smallSpacing / 1.5)
                            radius: height / 2
                            visible: deviceDelegate.used >= 0
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                           Kirigami.Theme.textColor.b, 0.15)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(parent.width * Math.max(0, deviceDelegate.used))
                                height: parent.height
                                radius: parent.radius
                                color: deviceDelegate.used > 0.9
                                    ? Kirigami.Theme.negativeTextColor
                                    : Kirigami.Theme.highlightColor
                            }
                        }

                        PC3.Label {
                            Layout.fillWidth: true
                            text: deviceDelegate.capacity
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }
                    }
                }

                /* Unmount / eject, only where Solid says it applies, and only
                   while the device is actually mounted. */
                PC3.ToolButton {
                    visible: deviceDelegate.mounted && (deviceDelegate.hovered || deviceDelegate.activeFocus)
                    icon.name: root.canEject(deviceDelegate.udi) ? "media-eject" : "media-playback-stop"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    display: PC3.AbstractButton.IconOnly
                    text: root.canEject(deviceDelegate.udi)
                        ? i18nc("@action:button", "Eject")
                        : i18nc("@action:button", "Unmount")

                    Accessible.role: Accessible.Button
                    Accessible.name: text

                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

                    onClicked: root.runOperation(deviceDelegate.udi, "unmount")
                }
            }

            Keys.onUpPressed: event => {
                if (deviceList.currentIndex > 0) {
                    deviceList.currentIndex--
                    deviceList.currentItem.forceActiveFocus(Qt.BacktabFocusReason)
                } else {
                    root.focusPreviousRequested()
                }
            }
            Keys.onDownPressed: event => {
                if (deviceList.currentIndex < deviceList.count - 1) {
                    deviceList.currentIndex++
                    deviceList.currentItem.forceActiveFocus(Qt.TabFocusReason)
                } else {
                    root.focusNextRequested()
                }
            }
        }
    }

    function focusFirst() {
        if (deviceList.count === 0) {
            return false
        }
        deviceList.currentIndex = 0
        if (deviceList.currentItem) {
            deviceList.currentItem.forceActiveFocus(Qt.TabFocusReason)
        }
        return true
    }

    function focusLast() {
        if (deviceList.count === 0) {
            return false
        }
        deviceList.currentIndex = deviceList.count - 1
        if (deviceList.currentItem) {
            deviceList.currentItem.forceActiveFocus(Qt.BacktabFocusReason)
        }
        return true
    }

    Component.onCompleted: devices.rebuild()
}
