import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"
import md3.Core as MD3

Item {
    id: page
    signal importRequested()
    property bool reveal: false
    property string query: ""
    property string examFilter: "all"
    property string typeFilter: "all"
    property bool favoriteOnly: false
    property var filtered: []

    function refresh() {
        var all = backend.decks || []
        var out = []
        var q = page.query.trim().toLowerCase()
        for (var i = 0; i < all.length; ++i) {
            var deck = all[i]
            var deckExam = String(deck.exam || "").toLowerCase()
            if (page.examFilter === "cet") {
                if (deckExam !== "cet" && deckExam !== "cet4" && deckExam !== "cet6")
                    continue
            } else if (page.examFilter !== "all" && deckExam !== page.examFilter) {
                continue
            }
            if (page.typeFilter !== "all" && String(deck.type || "").toLowerCase() !== page.typeFilter)
                continue
            if (page.favoriteOnly && !deck.favorite)
                continue
            var hay = (String(deck.name || "") + " " + String(deck.exam || "") + " "
                       + String(deck.type || "") + " " + String(deck.tag || "")).toLowerCase()
            if (q.length && hay.indexOf(q) < 0)
                continue
            out.push(deck)
        }
        filtered = out
    }

    function enter() {
        reveal = false
        replayTimer.restart()
        refresh()
    }

    onQueryChanged: refresh()
    onExamFilterChanged: refresh()
    onTypeFilterChanged: refresh()
    onFavoriteOnlyChanged: refresh()

    Timer {
        id: replayTimer
        interval: 40
        onTriggered: page.reveal = true
    }

    Connections {
        target: backend
        function onStateChanged() { page.refresh() }
    }

    Component.onCompleted: refresh()

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: libraryColumn.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: libraryColumn
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MD3.TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    type: "outlined"
                    placeholderText: "搜索词库名称、考试类型…"
                    leadingIcon: "search"
                    text: page.query
                    onTextChanged: if (text !== page.query) page.query = text
                }

                AppButton {
                    text: "导入词书"
                    shortcut: "Ctrl+I"
                    primary: true
                    implicitHeight: 46
                    implicitWidth: 136
                    fontSize: 13
                    radiusValue: 10
                    onClicked: page.importRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                Chip {
                    label: "全部"
                    selected: page.examFilter === "all" && page.typeFilter === "all" && !page.favoriteOnly
                    onClicked: {
                        page.examFilter = "all"
                        page.typeFilter = "all"
                        page.favoriteOnly = false
                    }
                }
                Chip {
                    label: "四六级"
                    selected: page.examFilter === "cet"
                    onClicked: page.examFilter = page.examFilter === "cet" ? "all" : "cet"
                }
                Chip {
                    label: "考研"
                    selected: page.examFilter === "postgrad"
                    onClicked: page.examFilter = page.examFilter === "postgrad" ? "all" : "postgrad"
                }
                Chip {
                    label: "出国"
                    selected: page.examFilter === "abroad"
                    onClicked: page.examFilter = page.examFilter === "abroad" ? "all" : "abroad"
                }
                Chip {
                    label: "国内"
                    selected: page.examFilter === "domestic"
                    onClicked: page.examFilter = page.examFilter === "domestic" ? "all" : "domestic"
                }
                Chip {
                    label: "通用"
                    selected: page.examFilter === "general"
                    onClicked: page.examFilter = page.examFilter === "general" ? "all" : "general"
                }
                Chip {
                    label: "专业"
                    selected: page.examFilter === "professional"
                    onClicked: page.examFilter = page.examFilter === "professional" ? "all" : "professional"
                }
                Chip {
                    label: "AI"
                    selected: page.examFilter === "ai"
                    onClicked: page.examFilter = page.examFilter === "ai" ? "all" : "ai"
                }
                Chip {
                    label: "收藏"
                    selected: page.favoriteOnly
                    onClicked: page.favoriteOnly = !page.favoriteOnly
                }
                Chip {
                    label: "单词"
                    selected: page.typeFilter === "words"
                    onClicked: page.typeFilter = page.typeFilter === "words" ? "all" : "words"
                }
                Chip {
                    label: "词组"
                    selected: page.typeFilter === "phrases"
                    onClicked: page.typeFilter = page.typeFilter === "phrases" ? "all" : "phrases"
                }

                Item { Layout.fillWidth: true }
                Text {
                    text: "LEXICON LIBRARY"
                    color: T.faint
                    font.family: T.fontEN
                    font.pixelSize: 10
                    font.letterSpacing: 1.7
                }
            }

            Grid {
                Layout.fillWidth: true
                columns: flick.width > 1010 ? 2 : 1
                spacing: 16

                Repeater {
                    model: page.filtered
                    delegate: DeckCard {
                        width: flick.width > 1010 ? (flick.width - 80 - 16) / 2 : flick.width - 80
                        height: 224
                        deck: modelData
                        favorite: modelData.favorite || false
                        onStart: {
                            backend.openDeck(deck.id)
                        }
                        onFavoriteToggled: backend.toggleDeckFavorite(modelData.id)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 220 : 0
                visible: (page.filtered || []).length === 0
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72
                        radius: 36
                        color: T.neutralPale
                        Text {
                            anchors.centerIn: parent
                            text: "⌕"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 30
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "还没有找到这本词书"
                        color: T.inkSoft
                        font.family: T.fontCN
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "换个关键词，或导入自己的词书。"
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
