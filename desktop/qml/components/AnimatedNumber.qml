import QtQuick

Text {
    id: number
    property int value: 0
    property bool active: true
    property int shown: active ? value : 0

    text: String(shown)
    Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutExpo } }
}
