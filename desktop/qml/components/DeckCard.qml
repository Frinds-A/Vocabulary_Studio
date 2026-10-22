import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../Theme.js" as T

Rectangle {
    id: card
    property var deck: ({})
    property bool favorite: false
    readonly property var theme: T.deckTheme(deck)
    signal start()
    signal favoriteToggled()

    implicitWidth: 520
    implicitHeight: 224
    radius: 16
    color: T.white
    border.width: 1
    border.color: hover.hovered ? T.lineStrong : T.line

    transform: Translate {
        y: hover.hovered ? -2 : 0
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#0D0F1115"
        shadowBlur: 0.25
        shadowVerticalOffset: hover.hovered ? 6 : 3
        shadowOpacity: hover.hovered ? 0.55 : 0.28
        blurMax: 18
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: card.start() }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.rightMargin: 16
        text: card.favorite ? "★" : "☆"
        color: card.favorite ? T.ink : T.faint
        font.family: T.fontEN
        font.pixelSize: 18
        z: 2
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: card.favoriteToggled()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        Item {
            Layout.preferredWidth: 150
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 7

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: T.deckShort(card.deck)
                    color: T.ink
                    font.family: T.fontEN
                    font.pixelSize: 26
                    font.bold: true
                    font.letterSpacing: 0.4
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30
                    height: 1
                    color: T.lineStrong
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: T.deckTag(card.deck)
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "LEXICON"
                    color: T.faint
                    font.family: T.fontEN
                    font.pixelSize: 9
                    font.letterSpacing: 1.6
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: T.deckTitle(card.deck)
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: tagLabel.implicitWidth + 18
                    radius: 12
                    color: T.neutralPale
                    Text {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: T.deckTag(card.deck)
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Item { Layout.preferredHeight: 6 }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                text: card.deck.description || "从一词一句开始，积累你的表达。"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 13
                lineHeight: 1.3
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "已学 " + String(card.deck.studied || 0) + " · 已掌握 " + String(card.deck.learned || 0)
                    color: T.inkSoft
                    font.family: T.fontCN
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "未掌握 " + String(card.deck.unlearned === undefined
                                             ? Math.max(0, Number(card.deck.total || 0) - Number(card.deck.learned || 0))
                                             : card.deck.unlearned)
                    color: T.faint
                    font.family: T.fontCN
                    font.pixelSize: 12
                }
            }

            Item { Layout.preferredHeight: 9 }

            AccentBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                value: T.progressOf(card.deck)
                color1: T.accent
            }

            Item { Layout.preferredHeight: 11 }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: String(card.deck.learned || 0) + " / " + String(card.deck.total || 0) + " 词"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                AppButton {
                    text: "查看单词"
                    implicitHeight: 36
                    implicitWidth: 118
                    fontSize: 13
                    onClicked: card.start()
                }
            }
        }
    }
}
