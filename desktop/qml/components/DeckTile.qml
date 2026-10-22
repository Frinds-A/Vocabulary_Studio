import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../Theme.js" as T

Rectangle {
    id: tile
    property var deck: ({})
    readonly property var theme: T.deckTheme(deck)
    signal start()

    implicitWidth: 250
    implicitHeight: 236
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
    TapHandler { onTapped: tile.start() }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 18
        anchors.bottomMargin: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 42
                height: 42
                radius: 10
                color: T.neutralPale
                Text {
                    anchors.centerIn: parent
                    text: T.deckShort(tile.deck)
                    color: T.ink
                    font.family: T.fontEN
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.3
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 24
                implicitWidth: tagText.implicitWidth + 18
                radius: 12
                color: T.neutralPale
                border.width: 1
                border.color: T.line
                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: T.deckTag(tile.deck)
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        Item { Layout.preferredHeight: 12 }

        Text {
            Layout.fillWidth: true
            text: T.deckTitle(tile.deck)
            color: T.ink
            font.family: T.fontCN
            font.pixelSize: 18
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        AccentBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            value: T.progressOf(tile.deck)
            color1: T.accent
        }

        Item { Layout.preferredHeight: 10 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "已学 " + String(tile.deck.studied || 0) + " · 掌握 " + String(tile.deck.learned || 0)
                color: T.inkSoft
                font.family: T.fontCN
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "共 " + String(tile.deck.total || 0) + " 词"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
            }
        }

        Item { Layout.preferredHeight: 10 }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "查看单词"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 12
                font.bold: true
                Layout.fillWidth: true
            }
        }
    }
}
