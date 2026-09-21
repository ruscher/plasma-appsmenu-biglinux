/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Quick Links gadget — big icons for apps and sites; add/remove/edit.

    cfg: { links: [{ target, name?, icon? }] }
      target:  "<id>.desktop"  an installed application, resolved through
                               contents/tools/desktop-entry — name, icon and
                               the command all come from the desktop entry
               http(s)://…     opened with the default handler
               file://…, mailto:…
               anything else   run as a command line

    Names and icons are *not* copied for desktop entries. They used to be, and
    they drifted: the Big Store tile asked for the icon "bigstore" while the
    application installs "big-store", so it rendered an empty gap. Reading the
    entry also gets the translated name and the proper launch semantics for
    free, and tells us when an application simply is not installed.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.iconthemes as KIconThemes

Item {
    id: ql
    required property var host

    /*  BigLinux's own tools first. Each entry names a desktop id; `alt` lists
        equivalents to try when the first one is not installed, so a machine
        without KCalc still gets a calculator instead of a gap.  */
    readonly property var defaults: [
        { target: "bigcontrolcenter.desktop" },
        { target: "bigcontrolcenter/biglinux-settings.desktop" },
        { target: "bigcontrolcenter/big-themes-gui.desktop" },
        { target: "org.communitybig.ashyterm.desktop" },
        { target: "big-store.desktop" },
        { target: "br.com.biglinux.webapps.desktop" },
        { target: "pamac-updates.desktop", alt: ["org.manjaro.pamac.manager.desktop"] },
        { target: "org.kde.kcalc.desktop", alt: ["org.gnome.Calculator.desktop", "galculator.desktop"] },
        { target: "org.kde.kate.desktop", alt: ["org.gnome.TextEditor.desktop"] },
        { target: "org.kde.dolphin.desktop", alt: ["org.gnome.Nautilus.desktop"] },
    ]

    readonly property var links: host.cfg.links && host.cfg.links.length ? host.cfg.links : defaults

    /*  The helper, resolved from this file so it keeps working wherever the
        plasmoid is installed.  */
    readonly property string helper: {
        const url = Qt.resolvedUrl("../../../tools/desktop-entry")
        return url.toString().replace(/^file:\/\//, "")
    }

    /*  A desktop id, and nothing else. One slash is allowed because BigLinux
        ships bigcontrolcenter/biglinux-settings.desktop inside a subdirectory.
        Targets come from configuration and the executable data engine runs
        through a shell, so this is checked here as well as in the helper.  */
    readonly property var desktopIdPattern: /^[A-Za-z0-9._+-]+(\/[A-Za-z0-9._+-]+)?\.desktop$/

    function isDesktopId(t) {
        return desktopIdPattern.test(String(t || "")) && String(t).indexOf("..") === -1
    }

    /*  id → { path, name, icon }, filled by the resolver below. */
    property var resolved: ({})
    property bool resolving: false

    /*  Links with every unresolvable application dropped, so the grid never
        shows a button that cannot do anything.  */
    readonly property var effectiveLinks: {
        const out = []
        for (const link of links) {
            if (!isDesktopId(link.target)) {
                out.push(link)      // URL or command: nothing to resolve
                continue
            }
            const ids = [link.target].concat(link.alt || [])
            let hit = null
            for (const id of ids) {
                const r = resolved[id]
                if (r && r.path) { hit = { id: id, info: r }; break }
            }
            if (!hit) {
                continue            // not installed anywhere: leave it out
            }
            out.push({
                target: hit.id,
                name: link.name || hit.info.name || hit.id,
                icon: link.icon || hit.info.icon || "application-x-executable"
            })
        }
        return out
    }

    Component.onCompleted: {
        host.accentColor = "#14b8a6"
        host.settingsComponent = settings
        resolve()
    }

    onLinksChanged: resolve()

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf(" resolve ") !== -1) {
                ql.applyResolution(data && data.stdout ? data.stdout : "")
            }
        }
    }

    function resolve() {
        const ids = []
        for (const link of links) {
            for (const id of [link.target].concat(link.alt || [])) {
                if (isDesktopId(id) && ids.indexOf(id) === -1) {
                    ids.push(id)
                }
            }
        }
        if (!ids.length) {
            resolved = ({})
            return
        }
        resolving = true
        /*  Every id has already been matched against desktopIdPattern, which
            admits no quote, space or shell metacharacter; single quotes are
            added anyway so the command cannot be reshaped by a surprise.  */
        const args = ids.map(id => "'" + id + "'").join(" ")
        runner.connectSource("'" + helper + "' resolve " + args)
    }

    function applyResolution(stdout) {
        const map = {}
        for (const line of String(stdout).split("\n")) {
            if (!line.length) {
                continue
            }
            const f = line.split("\t")
            if (f.length >= 4 && f[1].length) {
                map[f[0]] = { path: f[1], name: f[2], icon: f[3] }
            }
        }
        resolved = map
        resolving = false
    }

    function activate(link) {
        const t = String(link.target || "").trim()
        if (!t.length) {
            return
        }
        if (isDesktopId(t)) {
            /*  Launching through the entry keeps its field codes, working
                directory, terminal flag and D-Bus activation.  */
            runner.connectSource("'" + helper + "' launch '" + t + "'")
        } else if (/^(https?|file|mailto):/i.test(t)) {
            Qt.openUrlExternally(t)
        } else if (!/[\x00-\x1f]/.test(t)) {
            /*  A free-form command line is what this field is for, so shell
                syntax stays available; control characters do not, since they
                could smuggle a second command past the user's own reading of
                what they typed.  */
            runner.connectSource(t)
        }
        if (kickoff.hideOnWindowDeactivate) {
            kickoff.expanded = false
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        readonly property int cols: Math.max(2, Math.floor(width / (Kirigami.Units.gridUnit * 4.2)))
        cellWidth: Math.floor(width / cols)
        cellHeight: Math.min(height / Math.max(1, Math.ceil(count / cols)), Kirigami.Units.gridUnit * 5)
        model: ql.effectiveLinks
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        QQC2.ScrollBar.vertical: PC3.ScrollBar {
            policy: grid.contentHeight > grid.height ? QQC2.ScrollBar.AsNeeded
                                                     : QQC2.ScrollBar.AlwaysOff
        }
        delegate: PC3.AbstractButton {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            hoverEnabled: true
            onClicked: ql.activate(modelData)
            Accessible.name: modelData.name
            Accessible.role: Accessible.Button
            PC3.ToolTip.text: modelData.name
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            background: Rectangle {
                radius: Kirigami.Units.largeSpacing
                color: parent.hovered ? Qt.rgba(ql.host.accent.r, ql.host.accent.g, ql.host.accent.b, 0.16) : "transparent"
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }
            contentItem: ColumnLayout {
                spacing: 2
                Kirigami.Icon {
                    source: modelData.icon || "application-x-executable"
                    /*  A tile must never be an empty gap. */
                    fallback: "application-x-executable"
                    readonly property int sz: Math.min(Kirigami.Units.iconSizes.large, Math.round(Math.min(grid.cellWidth, grid.cellHeight) * 0.55))
                    Layout.preferredWidth: sz
                    Layout.preferredHeight: sz
                    Layout.alignment: Qt.AlignHCenter
                    scale: parent.parent.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                }
                PC3.Label {
                    text: modelData.name
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }
            scale: pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 80 } }
        }
    }

    // ── settings: link editor with icon picker ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            readonly property var list: host.cfg.links && host.cfg.links.length ? host.cfg.links : ql.defaults
            function labelFor(l) {
                const r = ql.resolved[l.target]
                return l.name || (r && r.name ? r.name : "")
            }
            function iconFor(l) {
                const r = ql.resolved[l.target]
                return l.icon || (r && r.icon ? r.icon : "application-x-executable")
            }
            function save(l) { host.setCfg("links", l) }
            property int iconRow: -1

            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: {
                    if (se.iconRow >= 0 && iconName.length) {
                        const l = se.list.map(x => Object.assign({}, x)); l[se.iconRow].icon = iconName; se.save(l)
                    } else if (se.iconRow === -1 && iconName.length) {
                        newIcon.text = iconName
                    }
                }
            }

            PC3.Label { text: i18n("Links"); font.weight: Font.DemiBold }
            Repeater {
                model: se.list
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    PC3.ToolButton {
                        icon.name: se.iconFor(modelData)
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        onClicked: { se.iconRow = index; iconDialog.open() }
                        PC3.ToolTip.text: i18n("Change icon"); PC3.ToolTip.visible: hovered
                        Accessible.name: i18n("Change icon")
                    }
                    QQC2.TextField {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                        text: se.labelFor(modelData)
                        placeholderText: i18n("Name")
                        onEditingFinished: { const l = se.list.map(x => Object.assign({}, x)); l[index].name = text; se.save(l) }
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: modelData.target
                        placeholderText: i18n("Command or URL")
                        onEditingFinished: { const l = se.list.map(x => Object.assign({}, x)); l[index].target = text.trim(); se.save(l) }
                    }
                    PC3.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: { const l = se.list.map(x => Object.assign({}, x)); const t = l[index - 1]; l[index - 1] = l[index]; l[index] = t; se.save(l) }
                        Accessible.name: i18n("Move up")
                    }
                    PC3.ToolButton {
                        icon.name: "list-remove"
                        onClicked: se.save(se.list.filter((x, i) => i !== index))
                        Accessible.name: i18n("Remove link")
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                PC3.ToolButton {
                    icon.name: newIcon.text || "list-add"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: { se.iconRow = -1; iconDialog.open() }
                    Accessible.name: i18n("Choose icon")
                }
                QQC2.TextField { id: newIcon; visible: false }
                QQC2.TextField { id: newName; Layout.preferredWidth: Kirigami.Units.gridUnit * 6; placeholderText: i18n("Name") }
                QQC2.TextField { id: newTarget; Layout.fillWidth: true; placeholderText: i18n("Command or URL") }
                PC3.Button {
                    icon.name: "list-add"; text: i18n("Add")
                    enabled: newName.text.trim().length > 0 && newTarget.text.trim().length > 0
                    onClicked: {
                        const l = se.list.map(x => Object.assign({}, x))
                        l.push({ name: newName.text.trim(), icon: newIcon.text || "application-x-executable", target: newTarget.text.trim() })
                        se.save(l); newName.text = ""; newTarget.text = ""; newIcon.text = ""
                    }
                }
            }
            PC3.Label {
                text: i18n("Use an application id (e.g. org.kde.dolphin.desktop) so the name and icon follow the system, a URL (https://…) to open a site, or a command to run something else.")
                opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }
}
