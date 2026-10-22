import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../Theme.js" as T

Rectangle {
    id: card
    property string title: ""
    property int value: 0
    property string suffix: ""
    property string displayText: ""
    property string glyph: "•"
    property color color1: T.ink
    property color color2: T.ink
    property bool active: true
    property real barValue: -1

    implicitHeight: 124
    radius: 12
    color: T.white
    border.width: 1
    border.color: T.line

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 16
        anchors.bottomMargin: 14
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Rectangle {
                width: 30
                height: 30
                radius: 8
                color: T.neutralPale
                Text {
                    anchors.centerIn: parent
                    text: card.glyph
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 14
                    font.bold: true
                }
            }
            Text {
                text: card.title
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 13
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            spacing: 5
            Text {
                visible: card.displayText.length > 0
                text: card.displayText
                color: T.ink
                font.family: T.fontEN
                font.pixelSize: 30
                font.bold: true
                Layout.alignment: Qt.AlignBottom
            }
            AnimatedNumber {
                visible: card.displayText.length === 0
                value: card.value
                active: card.active
                color: T.ink
                font.family: T.fontEN
                font.pixelSize: 36
                font.bold: true
                Layout.alignment: Qt.AlignBottom
            }
            Text {
                visible: card.displayText.length === 0
                text: card.suffix
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 12
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }
        }

        Item { Layout.fillHeight: true }

        AccentBar {
            visible: card.barValue >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            value: Math.max(0, Math.min(1, card.barValue))
            color1: T.accent
        }
        Item {
            visible: card.barValue < 0
            Layout.fillWidth: true
            Layout.preferredHeight: 4
        }
    }
}
