import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    objectName: "deckDetailPage"
    property bool reveal: false
    property string query: ""
    property string selectedWordId: ""
    property int browseChapter: 0
    readonly property bool active: backend.page === "deck"
    readonly property var allWords: active ? (backend.deckEntries || []) : []
    readonly property int chapterClamped: Math.max(0, Math.min(page.browseChapter,
                                                               Math.max(0, Number(backend.chapterCount || 1) - 1)))
    readonly property var chapterWords: {
        var size = Math.max(1, Number(backend.chapterSize || 20))
        var start = page.chapterClamped * size
        return page.allWords.slice(start, start + size)
    }
    readonly property var filteredWords: {
        var needle = page.query.trim().toLowerCase()
        if (!needle)
            return page.chapterWords
        var result = []
        for (var i = 0; i < page.chapterWords.length; ++i) {
            var entry = page.chapterWords[i]
            var haystack = (String(entry.word || "") + " " + String(entry.meaning || "")
                            + " " + String(entry.phonetic || "")).toLowerCase()
            if (haystack.indexOf(needle) >= 0)
                result.push(entry)
        }
        return result
    }

    function enter() {
        page.browseChapter = Math.max(0, Number(backend.currentChapter || 0))
        page.query = ""
        page.selectedWordId = ""
        reveal = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 0
        anchors.bottomMargin: 20
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 400
            Layout.maximumWidth: 440
            Layout.preferredHeight: 38
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            Layout.alignment: Qt.AlignLeft
            radius: 19
            color: T.white
            border.width: 1
            border.color: searchField.activeFocus ? T.ink : T.line

            TextField {
                id: searchField
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                padding: 0
                color: T.ink
                placeholderText: "搜索本章单词、释义或音标…"
                placeholderTextColor: T.faint
                font.family: T.fontCN
                font.pixelSize: 12
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle { color: "transparent" }
                text: page.query
                onTextChanged: if (text !== page.query) page.query = text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: T.line
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.preferredWidth: 296
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Text {
                            text: "章节"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: String(backend.chapterCount || 0) + " 章"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: T.line
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: backend.chapterRows || []
                        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            readonly property bool selected: Number(modelData.index) === page.chapterClamped
                            readonly property bool done: modelData.status === "done"
                            width: ListView.view.width - 12
                            x: 6
                            height: 46
                            radius: 8
                            color: selected ? T.neutralPale : (chapterHover.hovered ? T.neutralPale : "transparent")

                            HoverHandler { id: chapterHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    page.browseChapter = Number(modelData.index)
                                    page.selectedWordId = ""
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: String(modelData.label)
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 12
                                    font.bold: selected
                                }
                                Text {
                                    text: done ? "已完成"
                                          : (modelData.status === "active"
                                             ? "学习中·" + String(modelData.percent) + "%" : "未开始")
                                    color: done ? "#5D9371" : T.faint
                                    font.family: T.fontCN
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                visible: done
                                width: 22
                                height: 22
                                radius: 11
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#6FAF86"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: T.white
                                    font.family: T.fontEN
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: T.line
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 0
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.rightMargin: 40
                        Text {
                            text: "第 " + String(page.chapterClamped + 1) + " 章"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: String(page.chapterWords.length) + " 个词条"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: T.line
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        model: page.filteredWords
                        cacheBuffer: 1200
                        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            id: wordRow
                            width: ListView.view.width - 12
                            x: 6
                            height: expanded ? wordColumn.implicitHeight + 20 : 54
                            radius: 9
                            color: expanded ? T.neutralPale : "transparent"

                            readonly property var entry: modelData
                            readonly property bool expanded: page.selectedWordId === String(entry.id || "")
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    var id = String(wordRow.entry.id || "")
                                    page.selectedWordId = page.selectedWordId === id ? "" : id
                                }
                            }

                            ColumnLayout {
                                id: wordColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.rightMargin: 40
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text {
                                        text: String(wordRow.entry.word || "")
                                        color: T.ink
                                        font.family: T.fontEN
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                    Text {
                                        visible: String(wordRow.entry.phonetic || "").length > 0
                                        text: "/" + String(wordRow.entry.phonetic || "") + "/"
                                        color: T.muted
                                        font.family: T.fontEN
                                        font.pixelSize: 12
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: wordRow.entry.mastered ? "已掌握"
                                              : (wordRow.entry.studied ? "已学" : "")
                                        color: T.faint
                                        font.family: T.fontCN
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    TextButton {
                                        text: "发音"
                                        onClicked: backend.speak(String(wordRow.entry.word || ""))
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.rightMargin: 20
                                    visible: wordRow.expanded && String(wordRow.entry.meaning || "").length > 0
                                    text: String(wordRow.entry.meaning || "")
                                    color: T.inkSoft
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.4
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
                            text: page.query.length > 0 ? "没有找到匹配的单词" : "这一章还没有词条"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
