import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: dialog
    z: 300

    property bool remember: false
    signal closed()

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
        objectName: "welcomeCard"
        width: Math.min(parent.width - 80, 700)
        height: Math.min(parent.height - 48, 690)
        anchors.centerIn: parent
        radius: 18
        color: T.white
        border.width: 1
        border.color: T.line

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 36
            anchors.rightMargin: 36
            anchors.topMargin: 28
            anchors.bottomMargin: 26
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "欢迎使用 词序"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 22
                    font.bold: true
                    Layout.fillWidth: true
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
                AppButton {
                    text: "开始学习"
                    shortcut: "Enter"
                    primary: true
                    restoreStyle: true
                    implicitWidth: 94
                    implicitHeight: 32
                    fontSize: 12
                    radiusValue: 8
                    onClicked: dialog.finish()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "一份安静、离线的单词练习空间。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    width: 18
                    height: 18
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
                        font.pixelSize: 11
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
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.line
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                objectName: "welcomeScroll"

                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: welcomeBody.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: welcomeBody
                        width: parent.width - 12
                        spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "怎么学"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: "每天从今日计划开始：先复习到期单词，再学新词。每个单词会过两遍；拼错后先看正确答案和例句，再重写直到正确；重写时可以点「忘记了」自动补全。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                lineHeight: 1.55
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "完整操作和快捷键可在「偏好设置 → 使用说明」中随时查看。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.45
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: 1
                color: T.line
            }

            Text {
                Layout.fillWidth: true
                text: "关于更新与源码"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: "学习和发音都可以离线使用；只有检查更新、下载新版本需要联网。更新会在软件内完成，不会跳转浏览器。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.45
            }
            Text {
                Layout.fillWidth: true
                objectName: "welcomeStar"
                text: "GitHub 源码：https://github.com/Frinds-A/Vocabulary_Studio\n如果词序帮你多记住了一个词，求各位大人点一个 Star 喵！QAQ"
                color: T.accent
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.55
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://github.com/Frinds-A/Vocabulary_Studio")
                }
            }

            Text {
                Layout.fillWidth: true
                text: "—— Petrichor"
                color: T.muted
                font.family: T.fontEN
                font.pixelSize: 13
                font.italic: true
                horizontalAlignment: Text.AlignRight
            }
                }
            }
            }
        }
    }
}
