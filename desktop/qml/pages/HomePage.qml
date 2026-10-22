import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    property bool reveal: false

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
        objectName: "homeFlick"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: homeColumn.implicitHeight + 26
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: homeColumn
            objectName: "homeColumn"
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 20

            // -------------------------------------------------------------
            // Today's plan
            // -------------------------------------------------------------
            Rectangle {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: 210
                radius: 16
                color: T.white
                border.width: 1
                border.color: T.line

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 28
                    anchors.topMargin: 26
                    anchors.bottomMargin: 26
                    spacing: 30

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: T.ink
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: "TODAY'S PLAN"
                                color: T.muted
                                font.family: T.fontEN
                                font.pixelSize: 10
                                font.letterSpacing: 2.2
                                font.bold: true
                            }
                        }

                        Item { Layout.preferredHeight: 12 }

                        Text {
                            Layout.fillWidth: true
                            text: "I think, therefore I am."
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 32
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            text: "我思故我在。"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            spacing: 10
                            AppButton {
                                text: "开始今日计划"
                                shortcut: "Ctrl+Enter"
                                primary: true
                                restoreStyle: true
                                implicitHeight: 44
                                fontSize: 14
                                radiusValue: 10
                                onClicked: backend.startPlan("today")
                            }
                            AppButton {
                                text: "继续上次"
                                shortcut: "Ctrl+Enter"
                                restoreStyle: true
                                visible: backend.hasSession
                                implicitHeight: 44
                                fontSize: 13
                                radiusValue: 10
                                onClicked: backend.continueSession()
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: T.line
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 218
                        Layout.fillHeight: true
                        spacing: 0

                        Text {
                            text: "今日新词"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 13
                        }

                        Item { Layout.preferredHeight: 4 }

                        RowLayout {
                            spacing: 6
                            AnimatedNumber {
                                value: backend.todayNew
                                active: page.reveal
                                color: T.ink
                                font.family: T.fontEN
                                font.pixelSize: 54
                                font.bold: true
                            }
                            Text {
                                text: "词"
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 12
                            }
                        }

                        Item { Layout.preferredHeight: 10 }

                        AccentBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            value: backend.dailyGoal > 0
                                   ? Math.min(1, Number(backend.todayNew || 0) / Number(backend.dailyGoal))
                                   : 0
                            color1: T.accent
                        }

                        Item { Layout.preferredHeight: 9 }

                        Text {
                            text: String(backend.todayNew || 0) + " / " + String(backend.dailyGoal || 0)
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 12
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // -------------------------------------------------------------
            // Weekly chart
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 330
                radius: 16
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 10

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
                                font.pixelSize: 21
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
                            implicitHeight: 28
                            implicitWidth: 68
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
                                        width: Math.min(42, parent.width - 14)
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
        }
    }
}
