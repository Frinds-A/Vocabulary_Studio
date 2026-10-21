import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    objectName: "notebookPage"
    property bool reveal: false
    property string mode: "notebook"

    readonly property var notebookWords: backend.notebook || []
    readonly property var masteredWords: backend.masteredWords || []
    readonly property var shownWords: mode === "mastered" ? masteredWords : notebookWords

    function enter() {
        reveal = false
        replayTimer.restart()
    }

    Timer {
        id: replayTimer
        interval: 40
        onTriggered: page.reveal = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 2
        anchors.bottomMargin: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitHeight: 36
                implicitWidth: notebookTabText.implicitWidth + 30
                radius: 9
                color: page.mode === "notebook" ? T.neutralPale : "transparent"
                border.width: page.mode === "notebook" || notebookTabHover.hovered ? 1 : 0
                border.color: page.mode === "notebook" ? T.lineStrong : T.line
                HoverHandler { id: notebookTabHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.mode = "notebook" }
                Text {
                    id: notebookTabText
                    anchors.centerIn: parent
                    text: "生词本  " + String(page.notebookWords.length)
                    color: page.mode === "notebook" ? T.ink : T.muted
                    font.family: T.fontCN
                    font.pixelSize: 13
                    font.bold: page.mode === "notebook"
                }
            }

            Rectangle {
                implicitHeight: 36
                implicitWidth: masteredTabText.implicitWidth + 30
                radius: 9
                color: page.mode === "mastered" ? T.neutralPale : "transparent"
                border.width: page.mode === "mastered" || masteredTabHover.hovered ? 1 : 0
                border.color: page.mode === "mastered" ? T.lineStrong : T.line
                HoverHandler { id: masteredTabHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.mode = "mastered" }
                Text {
                    id: masteredTabText
                    anchors.centerIn: parent
                    text: "熟词  " + String(page.masteredWords.length)
                    color: page.mode === "mastered" ? T.ink : T.muted
                    font.family: T.fontCN
                    font.pixelSize: 13
                    font.bold: page.mode === "mastered"
                }
            }

            Item { Layout.fillWidth: true }

            AppButton {
                text: "开始复习"
                visible: page.mode === "notebook"
                implicitHeight: 42
                fontSize: 13
                enabled: page.notebookWords.length > 0
                onClicked: backend.startNotebookReview()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 11
                model: page.shownWords
                ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: wordCard
                    width: list.width
                    height: 88
                    radius: 12
                    color: T.white
                    border.width: 1
                    border.color: cardHover.hovered ? T.lineStrong : T.line
                    transform: Translate {
                        x: cardHover.hovered ? 2 : 0
                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                    }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    HoverHandler { id: cardHover }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.right: parent.right
                        anchors.rightMargin: 120
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9

                            Text {
                                text: modelData.word || ""
                                color: T.ink
                                font.family: T.fontEN
                                font.pixelSize: 24
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                width: 28
                                height: 22
                                radius: 6
                                color: T.neutralPale
                                Text {
                                    anchors.centerIn: parent
                                    text: T.posLabel(modelData.pos)
                                    color: T.muted
                                    font.family: T.fontEN
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.meaning || ""
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        visible: page.mode === "mastered"
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "答对 " + String(modelData.correctCount || 2) + " 次"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 11
                        }
                        TextButton {
                            text: "标为生词"
                            bordered: true
                            onClicked: backend.markMasteredAsNew(modelData.id)
                        }
                    }

                    TextButton {
                        visible: page.mode === "notebook"
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "移出"
                        opacity: cardHover.hovered ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        onClicked: backend.removeNotebook(modelData.id)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: page.shownWords.length === 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72
                    radius: 16
                    color: T.neutralPale
                    border.width: 1
                    border.color: T.line
                    Text {
                        anchors.centerIn: parent
                        text: page.mode === "mastered" ? "✓" : "词"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: page.mode === "mastered" ? 34 : 26
                        font.bold: true
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.mode === "mastered" ? "还没有熟词" : "生词本还是空的"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.mode === "mastered"
                          ? "同一个单词累计拼写正确两次，就会出现在这里。"
                          : "遇到想记的词，点一下收藏就会出现在这里。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 13
                }
            }
        }
    }
}
