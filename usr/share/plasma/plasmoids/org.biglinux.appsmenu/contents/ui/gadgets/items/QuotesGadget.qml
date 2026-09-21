/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Quote of the Day — a local collection (works offline); optional online
    quote via ZenQuotes when cfg.online is true.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../lib/GadgetNet.js" as Net

Item {
    id: quotes
    required property var host

    readonly property var local: [
        { q: "The best way to predict the future is to invent it.", a: "Alan Kay" },
        { q: "Simplicity is the ultimate sophistication.", a: "Leonardo da Vinci" },
        { q: "Talk is cheap. Show me the code.", a: "Linus Torvalds" },
        { q: "Programs must be written for people to read, and only incidentally for machines to execute.", a: "Harold Abelson" },
        { q: "The only way to do great work is to love what you do.", a: "Steve Jobs" },
        { q: "Software is a great combination of artistry and engineering.", a: "Bill Gates" },
        { q: "First, solve the problem. Then, write the code.", a: "John Johnson" },
        { q: "Any sufficiently advanced technology is indistinguishable from magic.", a: "Arthur C. Clarke" },
        { q: "Make it work, make it right, make it fast.", a: "Kent Beck" },
        { q: "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away.", a: "Antoine de Saint-Exupéry" },
        { q: "Given enough eyeballs, all bugs are shallow.", a: "Linus's Law" },
        { q: "It always seems impossible until it's done.", a: "Nelson Mandela" },
        { q: "What we know is a drop, what we don't know is an ocean.", a: "Isaac Newton" },
        { q: "Stay hungry, stay foolish.", a: "Stewart Brand" },
        { q: "The computer was born to solve problems that did not exist before.", a: "Bill Gates" },
        { q: "Free software is a matter of liberty, not price.", a: "Richard Stallman" },
        { q: "In the middle of difficulty lies opportunity.", a: "Albert Einstein" },
        { q: "Do or do not. There is no try.", a: "Yoda" },
        { q: "Well done is better than well said.", a: "Benjamin Franklin" },
        { q: "The journey of a thousand miles begins with a single step.", a: "Lao Tzu" },
        { q: "Whether you think you can or you think you can't, you're right.", a: "Henry Ford" },
        { q: "Creativity is intelligence having fun.", a: "Albert Einstein" },
        { q: "Code is like humor. When you have to explain it, it's bad.", a: "Cory House" },
        { q: "Optimism is an occupational hazard of programming; feedback is the treatment.", a: "Kent Beck" },
    ]
    readonly property bool online: host.cfg.online === true
    property int index: 0
    /*  A literal, not a binding on `local`, so onCompleted may set it. */
    property var current: null

    Component.onCompleted: {
        host.accentColor = "#f59e0b"
        host.settingsComponent = settings
        const day = Math.floor(Date.now() / 86400000)
        index = day % local.length
        current = local[index]
        if (online) fetchOnline()
    }
    Connections {
        target: quotes.host
        function onCfgChanged() { if (quotes.online) quotes.fetchOnline() }
    }
    function next() {
        index = (index + 1 + Math.floor(Math.random() * (local.length - 1))) % local.length
        current = local[index]
        pop.restart()
    }
    function fetchOnline() {
        const cached = host.cacheGet("today")
        if (Net.cacheFresh(cached, 6 * 60 * 60 * 1000)) { current = cached.v; return }
        host.loading = true
        Net.fetchJson("https://zenquotes.io/api/today", (err, d) => {
            host.loading = false
            if (err || !Array.isArray(d) || !d.length || !d[0].q) { host.offline = !!err; return }
            host.offline = false
            current = { q: d[0].q, a: d[0].a }
            host.cacheSet("today", Net.cacheEntry(current))
        })
    }

    SequentialAnimation {
        id: pop
        NumberAnimation { target: quoteCol; property: "opacity"; to: 0; duration: 120 }
        NumberAnimation { target: quoteCol; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: quoteCol
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        PC3.Label {
            text: "“"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
            font.family: "serif"
            color: quotes.host.accent
            opacity: 0.8
            Layout.preferredHeight: implicitHeight * 0.55
        }
        PC3.Label {
            text: quotes.current ? quotes.current.q : ""
            wrapMode: Text.Wrap
            font.italic: true
            font.pointSize: quotes.host.compact ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.defaultFont.pointSize * 1.15
            elide: Text.ElideRight
            maximumLineCount: quotes.host.compact ? 5 : 6
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
        }
        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: quotes.current ? "— " + quotes.current.a : ""
                opacity: 0.65
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "edit-copy"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: { copyHelper.text = "“" + quotes.current.q + "” — " + quotes.current.a; copyHelper.selectAll(); copyHelper.copy() }
                Accessible.name: i18n("Copy quote")
                PC3.ToolTip.text: i18n("Copy"); PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: quotes.next()
                Accessible.name: i18n("Another quote")
                PC3.ToolTip.text: i18n("Another quote"); PC3.ToolTip.visible: hovered
            }
        }
    }
    TextEdit { id: copyHelper; visible: false }

    Component {
        id: settings
        ColumnLayout {
            property var host
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Source:")
                    text: i18n("Also fetch today's quote online (zenquotes.io)")
                    checked: host.cfg.online === true
                    onToggled: host.setCfg("online", checked)
                }
            }
        }
    }
}
