import QtQuick
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
        width: Math.min(parent.width - 80, 700)
        height: Math.min(parent.height - 48, 620)
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
            }

            Text {
                Layout.fillWidth: true
                text: "一份安静、离线的单词练习空间。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.line
            }

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
                text: "三种练习：拼写最扎实，选择题适合词组和快速复习，听音拼写练辨音。卡住时先点「提示」；点「显示答案」后建议再点「重新拼写」，不要直接下一题。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                lineHeight: 1.55
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "快捷操作"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 14
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 20
                rowSpacing: 6

                Text { text: "F11"; color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 12 }
                Text { text: "进入 / 退出全屏专注"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
                Text { text: "Alt + K"; color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 12 }
                Text { text: "提示第一个字母"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
                Text { text: "Alt + A"; color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 12 }
                Text { text: "显示答案"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
                Text { text: "Enter"; color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 12 }
                Text { text: "判定 / 下一题"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
                Text { text: "Ctrl + H / L / P / B / T"; color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 12 }
                Text { text: "切换页面"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: 1
                color: T.line
            }

            Text {
                Layout.fillWidth: true
                text: "致使用词序的你："
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: "欢迎使用词序。愿这里安静的每一页，都能陪你多记住一个词，也多靠近一点想去的地方。"
                color: T.inkSoft
                font.family: T.fontCN
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                lineHeight: 1.55
            }
            Text {
                Layout.fillWidth: true
                text: "完整说明和分享包说明都在「偏好设置 → 使用说明」中，随时可以重新查看。"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.45
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

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 28

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
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
                        }
                        Text {
                            text: "下次不再弹出"
                            color: T.inkSoft
                            font.family: T.fontCN
                            font.pixelSize: 12
                        }
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

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "开始学习"
                    shortcut: "Enter"
                    primary: true
                    restoreStyle: true
                    implicitWidth: 112
                    implicitHeight: 38
                    fontSize: 13
                    radiusValue: 9
                    onClicked: {
                        dialog.finish()
                    }
                }
            }
        }
    }
}
