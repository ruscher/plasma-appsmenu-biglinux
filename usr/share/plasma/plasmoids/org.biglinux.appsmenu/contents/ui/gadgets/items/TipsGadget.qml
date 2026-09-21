/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Tips gadget — rotating BigLinux / KDE Plasma tricks (offline).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: tips
    required property var host

    readonly property var list: [
        { icon: "search", t: i18n("Press Meta and just start typing to search apps, files and settings — no clicking needed.") },
        { icon: "starred", t: i18n("Right-click any app and choose “Add to Favorites” to pin it to your Home tab.") },
        { icon: "edit-copy", t: i18n("Meta+V opens the clipboard history. Pick any earlier entry to paste it again.") },
        { icon: "preferences-desktop-display", t: i18n("Meta+P cycles display layouts when you plug in a second screen or projector.") },
        { icon: "view-grid", t: i18n("Meta+W shows all your windows at once (Overview) — drag them between desktops there.") },
        { icon: "spectacle", t: i18n("Print takes a screenshot; Meta+Shift+Print grabs a rectangular region.") },
        { icon: "input-keyboard", t: i18n("Meta+number switches to the nth pinned app in the task bar, just like a keyboard launcher.") },
        { icon: "preferences-system", t: i18n("BigLinux's Control Center groups the most used settings — drivers, sound, Wi-Fi — in one place.") },
        { icon: "system-software-install", t: i18n("Big Store installs native packages, Flatpaks, AppImages and Snaps from a single search.") },
        { icon: "utilities-terminal", t: i18n("In Konsole, Ctrl+Shift+F searches the scrollback; Ctrl+Shift+T opens a new tab.") },
        { icon: "folder", t: i18n("In Dolphin, F4 opens a terminal panel right in the current folder.") },
        { icon: "dashboard-show", t: i18n("Press and hold a gadget on the Info tab to rearrange it, or click Edit for more options.") },
        { icon: "preferences-desktop-theme", t: i18n("Meta+Shift+D reveals the desktop; press again to bring your windows back.") },
        { icon: "accessories-calculator", t: i18n("Type a calculation like 15% of 320 straight into the search field for an instant answer.") },
        { icon: "system-help", t: i18n("Hold Meta for a second on the desktop to see a cheat sheet of every keyboard shortcut.") },
        // Phrases from the BigLinux login screen (sddm-theme-biglinux)
        { icon: "system-file-manager", t: i18n("In the 'Dolphin' file manager, press the '/' key and type what you are looking for to filter items in the current folder, or use 'Ctrl + F' to search within subfolders as well.") },
        { icon: "kdeconnect", t: i18n("With KDEConnect, your computers, tablets, and smartphones can communicate, exchange files, serve as remote controls, and much more.") },
        { icon: "network-server", t: i18n("In the file manager, you can access files on SSH, SFTP, Samba servers, and more. Access remote files with much greater ease.") },
        { icon: "utilities-terminal", t: i18n("In the 'Dolphin' file manager and the 'Kate' text editor, press 'F4' to access the embedded terminal. The best of graphical mode and terminal in the same place.") },
        { icon: "edit-paste", t: i18n("Use the 'WinKey + V' shortcut to access the history of copied contents. After using the shortcut, type what you want to filter the results.") },
        { icon: "accessories-calculator", t: i18n("In the system menu, besides finding programs, it is also easy to do calculations and conversions, for example, '5 + 7' or '5m'.") },
        { icon: "window-duplicate", t: i18n("To split the screen with more programs, move each window to one of the sides or corners of the screen.") },
        { icon: "battery-good", t: i18n("Most laptops perform better when plugged into a power outlet.") },
        { icon: "tux", t: i18n("Every day, humans depend more on computing. Take advantage of using Linux and free software; here you can truly learn how things work.") },
        { icon: "spectacle", t: i18n("When using the 'Print Screen' key, notice the 'Edit' button, where you can make quick edits to the image. You can also copy the image and paste it directly into programs without the need to save and attach.") },
        { icon: "okular", t: i18n("In the 'Okular' document viewer, you can make annotations and notes on your PDF files, and even add digital signatures.") },
        { icon: "image-x-generic", t: i18n("By right-clicking on an image file, you can make various edits, including resizing and converting, directly from the file manager.") },
        { icon: "application-pdf", t: i18n("To convert Office documents to other formats, including PDF, just right-click and choose the format, directly from the file manager.") },
        { icon: "krunner", t: i18n("Use 'KRunner' by pressing 'Alt + Space' to perform quick searches, execute commands, and even solve mathematical calculations.") },
    ]
    property int index: Math.floor(Math.random() * list.length)

    Component.onCompleted: host.accentColor = "#8b5cf6"
    Binding { target: tips.host; property: "subtitle"; value: i18n("%1 / %2", tips.index + 1, tips.list.length) }

    Timer {
        interval: 25000
        running: tips.host.active && !tips.host.hovered
        repeat: true
        onTriggered: tips.go(1)
    }
    function go(delta) {
        index = (index + delta + list.length) % list.length
        fade.restart()
    }
    SequentialAnimation {
        id: fade
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 140 }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: tips.list[tips.index].icon
                Layout.preferredWidth: tips.host.compact ? Kirigami.Units.iconSizes.medium : Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignTop
                color: tips.host.accent
            }
            PC3.Label {
                text: tips.list[tips.index].t
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: tips.host.compact ? 6 : 4
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                icon.name: "go-previous"; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: tips.go(-1); Accessible.name: i18n("Previous tip")
            }
            PC3.ToolButton {
                icon.name: "go-next"; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: tips.go(1); Accessible.name: i18n("Next tip")
            }
        }
    }
}
