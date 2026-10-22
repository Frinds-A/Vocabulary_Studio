import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    property bool reveal: false
    property real accuracy: Number((backend.stats && backend.stats.accuracy) || 0)
    readonly property int studyMinutes: Math.floor(Number(backend.studySeconds || 0) / 60)
    readonly property int forecastMax: {
        var rows = backend.reviewForecast || []
        var result = 1
        for (var i = 0; i < rows.length; ++i)
            result = Math.max(result, Number(rows[i].count || 0))
        return result
    }
    readonly property int monthMax: {
        var rows = (backend.stats && backend.stats.month) || [1]
        var result = 1
        for (var i = 0; i < rows.length; ++i)
            result = Math.max(result, Number(rows[i] || 0))
        return result
    }

    function studyTimeText() {
        var minutes = page.studyMinutes
        if (minutes < 60)
            return String(minutes) + " min"
        return String(Math.floor(minutes / 60)) + "h " + String(minutes % 60) + "min"
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
                    Layout.preferredHeight: 288
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
                                Text {
                                    text: "全部词书的单词与词组，按首次学习日计数。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 12
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
                Layout.preferredHeight: 94
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "近 30 天"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "每天首次学习的单词数"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3
                        Repeater {
                            model: (backend.stats && backend.stats.month) || []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(3, 36 * Number(modelData || 0) / Math.max(1, page.monthMax))
                                Layout.alignment: Qt.AlignBottom
                                radius: 2
                                color: Number(modelData || 0) > 0 ? T.ink : T.neutralPale
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 126
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "复习预测"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "接下来 7 天"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        Repeater {
                            model: backend.reviewForecast || []
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(parent.width - 10, 22)
                                        height: Math.max(4, parent.height * Number(modelData.count || 0) / Math.max(1, page.forecastMax))
                                        radius: 4
                                        color: modelData.count > 0 ? T.ink : T.neutralPale
                                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: String(modelData.count || 0)
                                    color: T.muted
                                    font.family: T.fontEN
                                    font.pixelSize: 10
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: String(modelData.label || "")
                                    color: T.faint
                                    font.family: T.fontCN
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(306, 140 + ((backend.decks || []).length * 34))
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
                        spacing: 12

                        Repeater {
                            model: backend.decks || []
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
}
