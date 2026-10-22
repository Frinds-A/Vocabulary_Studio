import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    property bool reveal: false
    property string pickerQuery: ""
    property real accuracy: Number((backend.stats && backend.stats.accuracy) || 0)
    readonly property int studyMinutes: Math.floor(Number(backend.studySeconds || 0) / 60)
    function studyTimeText() {
        var minutes = page.studyMinutes
        if (minutes < 60)
            return String(minutes) + " min"
        return String(Math.floor(minutes / 60)) + "h " + String(minutes % 60) + "min"
    }

    function pickerDecks() {
        var source = backend.decks || []
        var needle = page.pickerQuery.trim().toLowerCase()
        if (!needle)
            return source
        var result = []
        for (var i = 0; i < source.length; ++i) {
            var deck = source[i]
            if ((String(deck.name || "") + " " + String(deck.exam || "") + " " + String(deck.type || "")).toLowerCase().indexOf(needle) >= 0)
                result.push(deck)
        }
        return result
    }

    function enter() {
        reveal = false
        replayTimer.restart()
    }

    Timer {
        id: replayTimer
        interval: 40
        onTriggered: page.reveal = true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: statsColumn.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: statsColumn
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                MetricCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    title: "累计掌握"
                    value: Number((backend.stats && backend.stats.learned) || 0)
                    suffix: "词"
                    glyph: "◈"
                    active: page.reveal
                }
                MetricCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    title: "连续学习"
                    value: Number((backend.stats && backend.stats.streak) || 0)
                    suffix: "天"
                    glyph: "✦"
                    active: page.reveal
                }
                MetricCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    title: "累计学习"
                    displayText: page.studyTimeText()
                    glyph: "◷"
                    active: page.reveal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 258
                    radius: 12
                    color: T.white
                    border.width: 1
                    border.color: T.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text {
                                    text: "本周新词"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }
                            Rectangle {
                                implicitHeight: 26
                                implicitWidth: 64
                                radius: 7
                                color: T.neutralPale
                                Text {
                                    anchors.centerIn: parent
                                    text: "近 7 天"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 24
                                anchors.bottomMargin: 22
                                color: "transparent"

                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 1
                                        y: (parent.height / 3) * index
                                        color: T.line
                                        opacity: 0.7
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 12

                                Repeater {
                                    model: (backend.stats && backend.stats.week) || [0, 0, 0, 0, 0, 0, 0]
                                    delegate: Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        readonly property real maxValue: T.weekMax((backend.stats && backend.stats.week) || [1])
                                        readonly property real ratio: Number(modelData) / maxValue

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 22
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: Math.min(38, parent.width - 14)
                                            height: page.reveal ? Math.max(6, (parent.height - 52) * ratio) : 6
                                            radius: 4
                                            color: T.accent
                                            Behavior on height { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: 5
                                                text: String(modelData)
                                                color: T.muted
                                                font.family: T.fontEN
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: T.weekLabel(index)
                                            color: index === 6 ? T.ink : T.faint
                                            font.family: T.fontCN
                                            font.pixelSize: 12
                                            font.bold: index === 6
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 330
                    Layout.preferredHeight: 288
                    radius: 12
                    color: T.white
                    border.width: 1
                    border.color: T.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 8

                        Text {
                            text: "综合正确率"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Item { Layout.fillHeight: true }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 150
                            height: 150

                            RingProgress {
                                anchors.fill: parent
                                thickness: 12
                                progress: page.reveal ? page.accuracy / 100 : 0
                                color1: T.accent
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    AnimatedNumber {
                                        value: Math.round(page.accuracy)
                                        active: page.reveal
                                        color: T.ink
                                        font.family: T.fontEN
                                        font.pixelSize: 40
                                        font.bold: true
                                    }
                                    Text {
                                        text: "%"
                                        color: T.muted
                                        font.family: T.fontEN
                                        font.pixelSize: 18
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 7
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "答对 " + String((backend.stats && backend.stats.right) || 0) + " 次"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 410
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "词库掌握度"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        TextButton {
                            text: "选择词书"
                            onClicked: statsDeckPicker.open()
                        }
                        Text {
                            text: "MASTERY"
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 10
                            font.letterSpacing: 1.6
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        Repeater {
                            model: backend.statsDecks || []
                            delegate: Item {
                                id: deckRow
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property var theme: T.deckTheme(modelData)
                                readonly property real ratio: T.progressOf(modelData)

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 14

                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 8
                                        color: T.neutralPale
                                        Text {
                                            anchors.centerIn: parent
                                            text: T.deckShort(modelData)
                                            color: T.ink
                                            font.family: T.fontEN
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: modelData.name || ""
                                                color: T.ink
                                                font.family: T.fontCN
                                                font.pixelSize: 14
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: String(modelData.learned || 0) + " / " + String(modelData.total || 0)
                                                color: T.muted
                                                font.family: T.fontEN
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                text: Math.round(deckRow.ratio * 100) + "%"
                                                color: deckRow.theme.deep
                                                font.family: T.fontEN
                                                font.pixelSize: 12
                                                font.bold: true
                                                width: 42
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                        AccentBar {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 5
                                            value: page.reveal ? deckRow.ratio : 0
                                            color1: T.accent
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: statsDeckPicker
        parent: page
        width: Math.min(520, parent.width - 60)
        height: Math.min(620, parent.height - 80)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 14
            color: T.white
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "选择展示的词书"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "5 本"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 11
                }
                Text {
                    text: "×"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 22
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: statsDeckPicker.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "点击新词书会替换最早选择的一本"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: T.white
                border.width: 1
                border.color: statsSearch.activeFocus ? T.ink : T.line
                TextField {
                    id: statsSearch
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    padding: 0
                    color: T.ink
                    placeholderText: "搜索词书"
                    placeholderTextColor: T.faint
                    font.family: T.fontCN
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    background: Rectangle { color: "transparent" }
                    text: page.pickerQuery
                    onTextChanged: page.pickerQuery = text
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: page.pickerDecks()
                ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    readonly property bool selected: (backend.statsDeckIds || []).indexOf(String(modelData.id)) >= 0
                    width: ListView.view.width
                    height: 46
                    radius: 7
                    color: selected ? T.neutralPale : (statsHover.hovered ? T.neutralPale : "transparent")
                    HoverHandler { id: statsHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            backend.selectStatsDeck(String(modelData.id))
                            statsDeckPicker.close()
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: selectedMark.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.name || "")
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        id: selectedMark
                        visible: parent.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✓"
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }
        }
    }

}
