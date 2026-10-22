import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"
import md3.Core as MD3

Item {
    id: page
    objectName: "deckDetailPage"
    property bool reveal: false
    property string query: ""
    property string selectedWordId: ""
    property bool confirmReset: false
    property bool confirmDelete: false
    readonly property bool active: backend.page === "deck"
    readonly property var allWords: active ? (backend.deckEntries || []) : []
    readonly property var filteredWords: {
        var source = page.allWords
        var needle = page.query.trim().toLowerCase()
        if (!needle)
            return source
        var result = []
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i]
            var haystack = (String(entry.word || "") + " " + String(entry.meaning || "")
                            + " " + String(entry.phonetic || "")).toLowerCase()
            if (haystack.indexOf(needle) >= 0)
                result.push(entry)
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            TextButton {
                text: "返回词库"
                shortcut: "Esc"
                bordered: true
                onClicked: backend.openPage("library")
            }

            Text {
                text: String(backend.deckCount || 0) + " 个词条"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            TextButton {
                text: "重学词书"
                shortcut: "Ctrl+Shift+R"
                bordered: true
                onClicked: page.confirmReset = true
            }

            TextButton {
                text: "删除词书"
                shortcut: "Delete"
                bordered: true
                contentColor: T.red
                visible: backend.selectedDeckCustom
                onClicked: page.confirmDelete = true
            }

            AppButton {
                text: "开始学习"
                shortcut: "Ctrl+Enter"
                primary: true
                showBorder: true
                implicitHeight: 42
                implicitWidth: 112
                fontSize: 13
                onClicked: backend.startPlan("today")
            }
        }

        MD3.TextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            type: "outlined"
            placeholderText: "搜索单词、释义或音标…"
            leadingIcon: "search"
            text: page.query
            onTextChanged: if (text !== page.query) page.query = text
        }

        ListView {
            id: wordList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: page.filteredWords
            cacheBuffer: 1200
            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: wordRow
                width: ListView.view.width
                height: rowColumn.implicitHeight + (expanded ? 22 : 16)
                color: expanded ? T.neutralPale : T.white

                readonly property var entry: modelData
                readonly property bool expanded: page.selectedWordId === String(entry.id || "")

                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        var id = String(wordRow.entry.id || "")
                        page.selectedWordId = page.selectedWordId === id ? "" : id
                    }
                }

                ColumnLayout {
                    id: rowColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 10
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: String(wordRow.entry.word || "")
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            visible: String(wordRow.entry.phonetic || "").length > 0
                            text: "/" + String(wordRow.entry.phonetic || "") + "/"
                            color: T.muted
                            font.family: T.fontEN
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }

                        Text {
                            text: wordRow.entry.mastered ? "已掌握"
                                  : (wordRow.entry.studied ? "已学" : "")
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextButton {
                            text: "发音"
                            onClicked: backend.speak(String(wordRow.entry.word || ""))
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 9
                        visible: wordRow.expanded

                        Repeater {
                            model: T.senseRows(wordRow.entry)
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: T.posLabel(modelData.pos)
                                    color: T.rose
                                    font.family: T.fontEN
                                    font.pixelSize: 13
                                    font.italic: true
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: T.rowMeaning(modelData)
                                    color: T.inkSoft
                                    font.family: T.fontCN
                                    font.pixelSize: 15
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.35
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: T.line
                            visible: String(wordRow.entry.example || "").length > 0
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: String(wordRow.entry.example || "").length > 0
                            text: String(wordRow.entry.example || "")
                            color: T.inkSoft
                            font.family: T.fontEN
                            font.pixelSize: 15
                            wrapMode: Text.WordWrap
                            lineHeight: 1.35
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: String(wordRow.entry.exampleZh || "").length > 0
                            text: String(wordRow.entry.exampleZh || "")
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.35
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: T.line
                        visible: !wordRow.expanded
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: page.filteredWords.length === 0
                text: page.query.length > 0 ? "没有找到匹配的单词" : "这个词库还没有词条"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 14
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#5A000000"
        visible: page.confirmReset
        z: 200

        MouseArea {
            anchors.fill: parent
            onClicked: page.confirmReset = false
        }

        Rectangle {
            width: 380
            height: 190
            anchors.centerIn: parent
            radius: 12
            color: T.white
            border.width: 1
            border.color: T.lineStrong

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 10

                Text {
                    text: "重学这本词书？"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "会清空《" + String(backend.deckName || "") + "》全部学习进度，所有单词回到未学状态。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    TextButton {
                        text: "取消"
                        onClicked: page.confirmReset = false
                    }
                    TextButton {
                        text: "确认重学"
                        onClicked: {
                            page.confirmReset = false
                            backend.resetDeck(backend.selectedDeckId)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#5A000000"
        visible: page.confirmDelete
        z: 201

        MouseArea {
            anchors.fill: parent
            onClicked: page.confirmDelete = false
        }

        Rectangle {
            width: 380
            height: 190
            anchors.centerIn: parent
            radius: 12
            color: T.white
            border.width: 1
            border.color: T.lineStrong

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 10

                Text {
                    text: "删除这本词书？"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "会从词书列表中移除《" + String(backend.deckName || "") + "》，并清除其学习进度。此操作不可撤销。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    TextButton {
                        text: "取消"
                        bordered: true
                        onClicked: page.confirmDelete = false
                    }
                    TextButton {
                        text: "确认删除"
                        bordered: true
                        contentColor: T.red
                        onClicked: {
                            page.confirmDelete = false
                            backend.deleteCustomBook(backend.selectedDeckId)
                        }
                    }
                }
            }
        }
    }
}
