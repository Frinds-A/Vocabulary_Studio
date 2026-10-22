import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Popup {
    id: dialog
    property string query: ""
    property var filteredDecks: []

    width: Math.min(1000, (parent ? parent.width : 1000) - 80)
    height: Math.min(760, (parent ? parent.height : 760) - 80)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function refreshDecks() {
        var source = backend.decks || []
        var needle = query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < source.length; ++i) {
            var deck = source[i]
            var hay = (String(deck.name || "") + " " + String(deck.exam || "")
                       + " " + String(deck.type || "")).toLowerCase()
            if (!needle || hay.indexOf(needle) >= 0)
                out.push(deck)
        }
        filteredDecks = out
    }

    function openWizard(deckId) {
        query = ""
        var target = String(deckId || backend.selectedDeckId || "")
        if (target)
            backend.selectDeck(target)
        refreshDecks()
        open()
    }

    onOpened: refreshDecks()

    background: Rectangle {
        radius: 16
        color: T.white
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "开始学习"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 22
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "×"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 24
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialog.close()
                }
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
            spacing: 18

            Item {
                Layout.preferredWidth: 264
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: T.white
                        border.width: 1
                        border.color: deckSearch.activeFocus ? T.ink : T.line
                        TextField {
                            id: deckSearch
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            padding: 0
                            color: T.ink
                            placeholderText: "搜索词书"
                            placeholderTextColor: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            background: Rectangle { color: "transparent" }
                            text: dialog.query
                            onTextChanged: {
                                dialog.query = text
                                dialog.refreshDecks()
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: dialog.filteredDecks
                        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 38
                            radius: 7
                            color: String(modelData.id) === String(backend.selectedDeckId)
                                   ? T.neutralPale : (deckHover.hovered ? T.neutralPale : "transparent")
                            HoverHandler { id: deckHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    backend.selectDeck(String(modelData.id))
                                    dialog.query = ""
                                    dialog.refreshDecks()
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(modelData.name || "")
                                color: T.ink
                                font.family: T.fontCN
                                font.pixelSize: 12
                                elide: Text.ElideRight
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
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: backend.deckName || "选择词书"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: String(backend.chapterCount || 0) + " 章 · " + String(backend.deckCount || 0) + " 词"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 11
                        }
                    }

                    GridView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: 148
                        cellHeight: 72
                        model: backend.chapterRows || []
                        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            readonly property bool done: modelData.status === "done"
                            width: 138
                            height: 62
                            radius: 9
                            color: done ? "#F2F8F4" : (chapterHover.hovered ? T.neutralPale : T.white)
                            border.width: 1
                            border.color: done ? "#B9DCC6"
                                          : (modelData.current ? T.ink : T.line)
                            HoverHandler { id: chapterHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    backend.startStudyChapter(Number(modelData.index))
                                    dialog.close()
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
                                    font.pixelSize: 11
                                    font.bold: modelData.current
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
                                width: 26
                                height: 26
                                radius: 13
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#6FAF86"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: T.white
                                    font.family: T.fontEN
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
