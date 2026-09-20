/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    ConfigGeneral — settings for Appearance, Applications, Home and Info.

    Plasma binds each `cfg_<key>` property to the matching main.xml entry.
    (Plain `id`s do NOT bind — the previous page never saved anything.)
*/

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    // ── Appearance ──
    property alias cfg_useSymbolicIcons: useSymbolicIcons.checked
    property alias cfg_compactMode: compactMode.checked

    // ── Applications ──
    property alias cfg_showAllApplications: showAllApplications.checked
    property alias cfg_alphaSort: alphaSort.checked
    property int cfg_applicationsDisplay
    property int cfg_favoritesDisplay

    // ── Home ──
    property alias cfg_showRecentSection: showRecentSection.checked
    property alias cfg_showRecentFiles: showRecentFiles.checked
    property alias cfg_showRecentFolders: showRecentFolders.checked
    property alias cfg_showFrequentSection: showFrequentSection.checked
    property alias cfg_recentAppsMax: recentAppsMax.value
    property alias cfg_recentFilesMax: recentFilesMax.value
    property alias cfg_recentFoldersMax: recentFoldersMax.value

    QQC2.ButtonGroup { id: appsGroup }
    QQC2.ButtonGroup { id: favsGroup }

    Kirigami.FormLayout {
        id: form

        // ─── APPEARANCE ───
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }
        QQC2.CheckBox {
            id: useSymbolicIcons
            Kirigami.FormData.label: i18n("Icons:")
            text: i18n("Use symbolic (monochrome) category icons")
        }
        QQC2.CheckBox {
            id: compactMode
            Kirigami.FormData.label: i18n("Lists:")
            text: i18n("Compact list items")
        }

        // ─── APPLICATIONS ───
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Applications")
        }
        QQC2.CheckBox {
            id: showAllApplications
            Kirigami.FormData.label: i18n("Categories:")
            text: i18n("Show an \"All Applications\" category")
        }
        QQC2.CheckBox {
            id: alphaSort
            text: i18n("Sort alphabetically")
        }
        QQC2.RadioButton {
            id: appsGrid
            QQC2.ButtonGroup.group: appsGroup
            Kirigami.FormData.label: i18n("Show applications as:")
            text: i18n("Grid")
            checked: root.cfg_applicationsDisplay === 0
            onToggled: if (checked) root.cfg_applicationsDisplay = 0
        }
        QQC2.RadioButton {
            id: appsList
            QQC2.ButtonGroup.group: appsGroup
            text: i18n("List")
            checked: root.cfg_applicationsDisplay === 1
            onToggled: if (checked) root.cfg_applicationsDisplay = 1
        }
        QQC2.RadioButton {
            id: favsGrid
            QQC2.ButtonGroup.group: favsGroup
            Kirigami.FormData.label: i18n("Show favorites as:")
            text: i18n("Grid")
            checked: root.cfg_favoritesDisplay === 0
            onToggled: if (checked) root.cfg_favoritesDisplay = 0
        }
        QQC2.RadioButton {
            id: favsList
            QQC2.ButtonGroup.group: favsGroup
            text: i18n("List")
            checked: root.cfg_favoritesDisplay === 1
            onToggled: if (checked) root.cfg_favoritesDisplay = 1
        }

        // ─── HOME ───
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Home")
        }
        QQC2.CheckBox {
            id: showRecentSection
            Kirigami.FormData.label: i18n("Sections:")
            text: i18n("Recent applications")
        }
        QQC2.CheckBox {
            id: showRecentFiles
            text: i18n("Recent files")
        }
        QQC2.CheckBox {
            id: showRecentFolders
            text: i18n("Recent folders")
        }
        QQC2.CheckBox {
            id: showFrequentSection
            text: i18n("Frequently used")
        }
        QQC2.SpinBox {
            id: recentAppsMax
            Kirigami.FormData.label: i18n("Max recent applications:")
            from: 1; to: 20
        }
        QQC2.SpinBox {
            id: recentFilesMax
            Kirigami.FormData.label: i18n("Max recent files:")
            from: 1; to: 20
        }
        QQC2.SpinBox {
            id: recentFoldersMax
            Kirigami.FormData.label: i18n("Max recent folders:")
            from: 1; to: 20
        }

    }
}
