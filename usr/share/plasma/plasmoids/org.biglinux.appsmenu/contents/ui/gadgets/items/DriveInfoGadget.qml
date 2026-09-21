/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Drive Info — storage volumes with used and free space, from Solid.

    It used to discover volumes by walking the KSystemStats sensor tree for
    "disk/<id>/total". That was the cause of the header disagreeing with the
    list — "3 volumes" above two rows: the tree also carries a wildcard entry
    whose sensor id is literally `disk/(?!all).*`, which matched the pattern,
    was counted, and of course never produced a value, so its row stayed
    invisible for good. It also reported the physical disk and its filesystem
    as separate volumes, knew nothing about removability, and only noticed a
    device being plugged in if the tree happened to emit rowsInserted.

    Solid answers all of that at once. The `hotplug` engine is event driven —
    devices appear and disappear on their own — and `soliddevice` reports, per
    device: Device Types, Label, File Path, Accessible (mounted), Removable,
    Size and Free Space, both raw and pre-localised, plus the icon the rest of
    the desktop uses for it. Nothing here parses `lsblk` or does byte
    arithmetic, and pseudo-filesystems never turn up in the first place.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support

Item {
    id: drives
    required property var host

    Component.onCompleted: host.accentColor = "#f97316"

    /*  `connectedSources: sources` makes the engine push changes at us
        instead of us polling it. */
    P5Support.DataSource {
        id: hotplug
        engine: "hotplug"
        connectedSources: sources
        onSourcesChanged: drives.rebuild()
    }

    P5Support.DataSource {
        id: solid
        engine: "soliddevice"
        connectedSources: hotplug.sources
        onDataChanged: drives.rebuild()
    }

    /*  The UDIs actually shown. The header counts this list and the view
        renders this list, so the two cannot drift apart again.

        Split into a settable half with no initialiser and a read-only half,
        so rebuilding does not overwrite a binding — see 00-audit.  */
    property var volumesData
    readonly property var volumes: volumesData !== undefined ? volumesData : []

    function isStorage(udi) {
        const d = solid.data[udi]
        if (!d || d["Ignored"] === true) {
            return false
        }
        const types = String(d["Device Types"] || "")
        return types.indexOf("Storage Access") !== -1 || types.indexOf("Storage Volume") !== -1
    }

    function isMounted(udi) {
        const d = solid.data[udi]
        return !!d && d["Accessible"] === true
    }

    function isRemovable(udi) {
        const d = solid.data[udi]
        return !!d && (d["Removable"] === true
                       || String(d["Device Types"] || "").indexOf("Optical") !== -1)
    }

    function isSystem(udi) {
        const d = solid.data[udi]
        return !!d && String(d["File Path"] || "") === "/"
    }

    function label(udi) {
        const d = solid.data[udi]
        if (!d) {
            return udi
        }
        return String(d["Label"] || d["Description"] || d["Device"] || udi)
    }

    function mountPath(udi) {
        const d = solid.data[udi]
        return d ? String(d["File Path"] || "") : ""
    }

    function iconFor(udi) {
        const d = solid.data[udi]
        const icon = d ? String(d["Icon"] || "") : ""
        return icon.length ? icon : "drive-harddisk"
    }

    /*  "38,0 GiB free of 50,0 GiB" — both halves arrive already formatted and
        localised, so there is no byte arithmetic and no unit guessing here. */
    function capacityText(udi) {
        const d = solid.data[udi]
        if (!d || !isMounted(udi)) {
            return i18nc("@info storage device that is present but not mounted", "Not mounted")
        }
        const free = String(d["Free Space Text"] || "")
        const size = String(d["Size Text"] || "")
        if (!free.length || !size.length) {
            return ""
        }
        return i18nc("@info:usage %1 is free space, %2 is total size", "%1 free of %2", free, size)
    }

    function usedFraction(udi) {
        const d = solid.data[udi]
        if (!d || !isMounted(udi)) {
            return -1
        }
        const size = Number(d["Size"] || 0)
        const free = Number(d["Free Space"] || 0)
        if (!(size > 0) || !(free >= 0)) {
            return -1
        }
        return Math.max(0, Math.min(1, (size - free) / size))
    }

    /*  Mounted volumes first, then removable devices that are plugged in but
        not mounted — those are worth seeing precisely because they are there
        and unavailable. Anything with no capacity and no removability is not
        a drive the user cares about.  */
    function rebuild() {
        const mounted = []
        const idle = []
        for (const udi of hotplug.sources) {
            if (!isStorage(udi)) {
                continue
            }
            if (isMounted(udi)) {
                mounted.push(udi)
            } else if (isRemovable(udi)) {
                idle.push(udi)
            }
        }
        /*  System volume first, then the rest alphabetically, so the list does
            not reshuffle every time the engine refreshes free space. */
        mounted.sort((a, b) => {
            if (isSystem(a) !== isSystem(b)) {
                return isSystem(a) ? -1 : 1
            }
            return label(a).localeCompare(label(b))
        })
        idle.sort((a, b) => label(a).localeCompare(label(b)))
        const next = mounted.concat(idle)
        if (next.length !== volumes.length || next.some((v, i) => v !== volumes[i])) {
            volumesData = next
        }
    }

    Binding {
        target: drives.host
        property: "subtitle"
        value: drives.volumes.length ? i18np("%1 volume", "%1 volumes", drives.volumes.length) : ""
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: Kirigami.Units.smallSpacing
        model: drives.volumes
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        reuseItems: true

        /*  More devices than fit is normal once a couple of sticks are
            plugged in; the list scrolls rather than cutting them off. */
        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded
                                                     : QQC2.ScrollBar.AlwaysOff
        }

        delegate: ColumnLayout {
            id: row

            required property string modelData
            readonly property string udi: modelData
            readonly property real frac: drives.usedFraction(udi)

            width: list.width
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: drives.iconFor(row.udi)
                    fallback: "drive-harddisk"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    opacity: drives.isMounted(row.udi) ? 0.85 : 0.45
                }

                PC3.Label {
                    text: drives.label(row.udi)
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                /*  Tells the three kinds apart without a legend. */
                PC3.Label {
                    visible: drives.isSystem(row.udi) || drives.isRemovable(row.udi)
                    text: drives.isSystem(row.udi)
                        ? i18nc("@label the volume the system is installed on", "System")
                        : i18nc("@label a device that can be unplugged", "Removable")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.55
                }
            }

            PC3.Label {
                text: drives.capacityText(row.udi)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                visible: row.frac >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.smallSpacing * 0.8)
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.12)

                Rectangle {
                    width: Math.max(2, parent.width * Math.max(0, row.frac))
                    height: parent.height
                    radius: parent.radius
                    color: row.frac > 0.9 ? Kirigami.Theme.negativeTextColor
                         : (row.frac > 0.75 ? Kirigami.Theme.neutralTextColor : drives.host.accent)
                    Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
            }

            Accessible.role: Accessible.ListItem
            Accessible.name: drives.label(row.udi)
            Accessible.description: drives.capacityText(row.udi)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: drives.volumes.length === 0

        Kirigami.Icon {
            source: "drive-harddisk"
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: i18n("No storage devices found")
            opacity: 0.7
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
