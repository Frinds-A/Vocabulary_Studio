import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: control
    property string label: ""
    property var options: []
    property string currentId: ""
    signal selected(string deckId)

    implicitHeight: 66

    function currentName() {
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].id) === String(currentId))
                return String(options[i].name)
        }
        return "未选择"
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: control.label
        color: T.muted
        font.family: T.fontCN
        font.pixelSize: 11
    }

    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 42
        radius: 9
        color: T.white
        border.width: 1
        border.color: fieldHover.hovered ? T.lineStrong : T.line

        HoverHandler {
            id: fieldHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler { onTapped: popup.open() }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: control.currentName()
            color: T.ink
            font.family: T.fontCN
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "⌄"
            color: T.muted
            font.family: T.fontCN
            font.pixelSize: 14
        }
    }

    Popup {
        id: popup
        width: control.width
        height: Math.min(300, control.options.length * 41 + 12)
        y: control.height + 2
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10
            color: T.white
            border.width: 1
            border.color: T.lineStrong
        }

        contentItem: ListView {
            id: list
            clip: true
            model: control.options
            spacing: 1
            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                width: list.width
                height: 40
                radius: 7
                color: itemHover.hovered ? T.neutralPale : "transparent"

                HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        control.selected(String(modelData.id))
                        popup.close()
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: check.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(modelData.name)
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    id: check
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: String(modelData.id) === String(control.currentId)
                    text: "✓"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }
}
