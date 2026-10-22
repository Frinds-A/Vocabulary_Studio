import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: dialog
    z: 300

    property bool remember: false
    signal closed()
    signal guideRequested()

    onVisibleChanged: {
        if (visible)
            remember = false
    }

    function closeDialog() {
        dialog.visible = false
        dialog.closed()
    }

    function finish() {
        backend.setWelcomeSeen(dialog.remember)
        dialog.closeDialog()
    }

    Shortcut {
        sequence: "Return"
        enabled: dialog.visible
        onActivated: dialog.finish()
    }

    Rectangle {
        anchors.fill: parent
        color: "#4A111111"
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 80, 640)
        height: Math.min(parent.height - 80, 440)
        anchors.centerIn: parent
        radius: 16
        color: T.white
        border.width: 1
        border.color: T.line

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 30
            anchors.rightMargin: 30
            anchors.topMargin: 24
            anchors.bottomMargin: 22
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: "欢迎使用 词序"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 21
                    font.bold: true
                }
                Text {
                    text: "×"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 20
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialog.closeDialog()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "一份安静、离线的单词练习空间"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 11
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.line
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "作者的话"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: "源码在 GitHub 上。如果词序帮你多记住了一个词，求各位大人点一颗 Star 喵！QAQ"
                color: T.inkSoft
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }
            Text {
                Layout.fillWidth: true
                text: "https://github.com/Frinds-A/Vocabulary_Studio"
                color: T.accent
                font.family: T.fontEN
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://github.com/Frinds-A/Vocabulary_Studio")
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: "简单用法"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: "每天先点「今日计划」，先复习到期词，再学新词。每个词会过两遍；拼错后先看答案和例句，再重写。卡住时按 Alt + K 提示，或点「显示答案」后重新拼写。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }

            TextButton {
                Layout.fillWidth: true
                text: "打开完整使用说明  →"
                bordered: true
                onClicked: {
                    dialog.finish()
                    dialog.guideRequested()
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 17
                    height: 17
                    radius: 4
                    color: dialog.remember ? T.ink : T.white
                    border.width: 1
                    border.color: dialog.remember ? T.ink : T.lineStrong
                    Text {
                        anchors.centerIn: parent
                        visible: dialog.remember
                        text: "✓"
                        color: T.white
                        font.family: T.fontEN
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dialog.remember = !dialog.remember
                            backend.setWelcomeSeen(dialog.remember)
                        }
                    }
                }
                Text {
                    text: "下次不再弹出"
                    color: T.inkSoft
                    font.family: T.fontCN
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dialog.remember = !dialog.remember
                            backend.setWelcomeSeen(dialog.remember)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "开始学习"
                    shortcut: "Enter"
                    primary: true
                    restoreStyle: true
                    implicitWidth: 104
                    implicitHeight: 34
                    fontSize: 12
                    radiusValue: 8
                    onClicked: dialog.finish()
                }
            }
        }
    }
}
