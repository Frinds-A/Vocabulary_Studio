import QtQuick
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: panel

    readonly property bool hasResult: backend.result !== null && backend.result !== undefined
    readonly property bool correct: hasResult && backend.result.correct
    readonly property int correctCount: hasResult ? Number(backend.result.correctCount || 0) : 0
    readonly property bool mastered: hasResult && backend.result.mastered === true
    readonly property bool revealed: hasResult && backend.result.revealed === true
    readonly property string expected: hasResult ? String(backend.result.expected || "") : ""
    readonly property var answerMarks: hasResult && backend.result.answerMarks
                                        ? backend.result.answerMarks : []
    readonly property var entry: backend.current || ({})
    readonly property string example: entry ? String(entry.example || "") : ""
    readonly property string exampleZh: entry ? String(entry.exampleZh || "") : ""
    readonly property bool retryable: hasResult && !correct
                                     && !(backend.result && backend.result.skipped)
                                     && backend.currentMode !== "choice"
    readonly property bool validResult: hasResult
                                        && String(backend.result.expected || "").length > 0
                                        && (String(backend.answer || "").length > 0
                                            || backend.result.skipped === true)

    signal nextRequested()
    signal collectRequested()
    signal retryRequested()

    visible: validResult
    implicitWidth: 820
    implicitHeight: content.implicitHeight + 36

    Rectangle {
        id: topLine
        anchors.top: parent.top
        anchors.left: content.left
        anchors.right: content.right
        height: 1
        color: T.line
        visible: !panel.correct
    }

    ColumnLayout {
        id: content
        anchors.top: topLine.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 13

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: panel.revealed ? "已显示答案"
                                          : panel.correct ? "回答正确" : "拼写有误"
                    color: panel.revealed ? T.rose
                                          : panel.correct ? T.green : T.red
                    font.family: T.fontCN
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    text: panel.correct && panel.mastered
                          ? "已掌握"
                          : "正确 " + String(panel.correctCount) + " / 2 次"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 13
                }
            }

            Item { Layout.fillWidth: true }

            TextButton {
                text: "收藏"
                Layout.preferredWidth: 56
                onClicked: panel.collectRequested()
            }

            AppButton {
                text: panel.retryable ? "重新拼写" : "下一题"
                primary: true
                implicitHeight: 42
                implicitWidth: 112
                Layout.preferredWidth: 104
                fontSize: 13
                radiusValue: 10
                onClicked: panel.retryable ? panel.retryRequested() : panel.nextRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            spacing: 10
            visible: !panel.correct && !panel.revealed && panel.answerMarks.length > 0

            Text {
                text: "你的拼写"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 5
            }

            Row {
                spacing: 1

                Repeater {
                    model: panel.answerMarks

                    delegate: Item {
                        width: Math.max(6, markLetter.implicitWidth)
                        height: 32

                        Rectangle {
                            visible: modelData.wrong === true
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width + 2
                            height: 26
                            radius: 5
                            color: T.mistakePale
                        }

                        Text {
                            id: markLetter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: String(modelData.ch || "")
                            color: modelData.wrong ? T.mistakeInk : T.muted
                            font.family: T.fontEN
                            font.pixelSize: 21
                            font.bold: modelData.wrong === true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1.5
                            visible: modelData.wrong === true
                            color: T.mistakeLine
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            spacing: 10
            visible: !panel.correct

            Text {
                text: backend.currentMode === "choice" ? "正确答案" : "正确拼写"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 5
            }

            Text {
                Layout.fillWidth: backend.currentMode === "choice"
                text: backend.currentMode === "choice"
                      ? String((panel.entry && panel.entry.meaning) || panel.expected)
                      : panel.expected
                color: T.ink
                font.family: backend.currentMode === "choice" ? T.fontCN : T.fontEN
                font.pixelSize: backend.currentMode === "choice" ? 20 : 28
                font.bold: true
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.preferredHeight: 1
            color: T.line
            visible: panel.example.length > 0
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            spacing: 10
            visible: panel.example.length > 0

            Text {
                text: "例句"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 3
            }

            Text {
                Layout.fillWidth: true
                text: panel.example
                color: T.inkSoft
                font.family: T.fontEN
                font.pixelSize: 16
                wrapMode: Text.WordWrap
                lineHeight: 1.35
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            visible: panel.exampleZh.length > 0
            text: panel.exampleZh
            color: T.muted
            font.family: T.fontCN
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            lineHeight: 1.35
        }
    }
}
