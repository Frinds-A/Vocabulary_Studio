import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: card
    property string mode: ""
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property bool selected: false
    property color accent: T.ink
    property color accent2: T.ink
    property string shortcut: ""
    signal clicked()

    ToolTip.visible: hover.hovered && card.shortcut.length > 0
    ToolTip.text: card.shortcut
    ToolTip.delay: 250

    implicitHeight: 92
    scale: tap.pressed ? 0.99 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: card.selected ? "#FAFAFA" : (hover.hovered ? T.neutralSoft : T.white)
        border.width: card.selected ? 1.5 : 1
        border.color: card.selected ? T.ink : (hover.hovered ? T.lineStrong : T.line)
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                width: 44
                height: 44
                radius: 10
                color: card.selected ? T.ink : T.neutralPale
                Text {
                    anchors.centerIn: parent
                    text: card.glyph
                    color: card.selected ? T.white : T.ink
                    font.family: T.fontCN
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: card.title
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Item {
                width: 20
                height: 20
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: card.selected ? T.ink : "transparent"
                    border.width: card.selected ? 0 : 1
                    border.color: T.lineStrong
                }
                Text {
                    anchors.centerIn: parent
                    visible: card.selected
                    text: "✓"
                    color: T.white
                    font.family: T.fontCN
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: card.clicked() }
}
