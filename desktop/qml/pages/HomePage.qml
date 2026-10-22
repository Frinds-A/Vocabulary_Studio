import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    property bool reveal: false
    signal studyWizardRequested(string deckId)

    function scopeLabel() {
        if (backend.studyScope === "new")
            return "只学新词"
        if (backend.studyScope === "review")
            return "只复习"
        return "新词 + 复习"
    }

    function openScopePicker() {
        var point = scopePill.mapToItem(page, 0, scopePill.height + 6)
        scopePicker.x = Math.max(20, Math.min(page.width - scopePicker.width - 20, point.x))
        scopePicker.y = Math.max(20, Math.min(page.height - scopePicker.height - 20, point.y))
        scopePicker.open()
    }

    function studyScopeSummary() {
        var ids = backend.selectedDeckIds || []
        var all = backend.decks || []
        var names = []
        for (var i = 0; i < all.length; ++i) {
            if (ids.indexOf(String(all[i].id)) >= 0)
                names.push(String(all[i].name || ""))
        }
        var books = names.length ? names.slice(0, 2).join("、")
                                + (names.length > 2 ? " 等 " + names.length + " 本" : "")
                                : "未选择词书"
        var scope = backend.studyScope === "new" ? "只学新词"
                  : (backend.studyScope === "review" ? "只复习" : "新词 + 复习")
        return books + " · " + scope
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

    Flickable {
        id: flick
        objectName: "homeFlick"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: homeColumn.implicitHeight + 26
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: homeColumn
            objectName: "homeColumn"
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 20

            // -------------------------------------------------------------
            // Today's plan
            // -------------------------------------------------------------
            Rectangle {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: 210
                radius: 16
                color: T.white
                border.width: 1
                border.color: T.line

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 28
                    anchors.topMargin: 26
                    anchors.bottomMargin: 26
                    spacing: 30

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: T.ink
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: "TODAY'S PLAN"
                                color: T.muted
                                font.family: T.fontEN
                                font.pixelSize: 10
                                font.letterSpacing: 2.2
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Item { Layout.preferredHeight: 12 }

                        Text {
                            Layout.fillWidth: true
                            text: "I think, therefore I am."
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 32
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            text: "我思故我在。"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            AppButton {
                                text: "开始学习"
                                shortcut: "Ctrl+Enter"
                                primary: true
                                restoreStyle: true
                                implicitHeight: 44
                                fontSize: 14
                                radiusValue: 10
                                onClicked: page.studyWizardRequested("")
                            }
                            AppButton {
                                text: "继续学习"
                                shortcut: "Ctrl+Shift+Enter"
                                restoreStyle: true
                                implicitHeight: 44
                                fontSize: 13
                                radiusValue: 10
                                onClicked: backend.continueStudy()
                            }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 5
                                Repeater {
                                    model: [
                                        { label: "拼写", id: "spelling" },
                                        { label: "选择", id: "choice" },
                                        { label: "听写", id: "dictation" }
                                    ]
                                    delegate: Rectangle {
                                        readonly property bool selected: backend.mode === modelData.id
                                        implicitWidth: 50
                                        implicitHeight: 30
                                        radius: 8
                                        color: selected ? T.ink : "transparent"
                                        border.width: 1
                                        border.color: selected ? T.ink : T.line
                                        Layout.alignment: Qt.AlignVCenter
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: backend.setMode(String(modelData.id)) }
                                        Text {
                                            anchors.centerIn: parent
                                            text: String(modelData.label)
                                            color: selected ? T.white : T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                            font.bold: selected
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                id: scopePill
                                implicitHeight: 30
                                implicitWidth: scopeText.implicitWidth + 34
                                Layout.alignment: Qt.AlignVCenter
                                radius: 8
                                color: T.neutralPale
                                border.width: 1
                                border.color: T.line
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: page.openScopePicker() }

                                Row {
                                    id: scopeText
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "范围"
                                        color: T.muted
                                        font.family: T.fontCN
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: page.scopeLabel()
                                        color: T.ink
                                        font.family: T.fontCN
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Chevron {
                                        color: T.faint
                                        anchors.verticalCenter: parent.verticalCenter
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

                    ColumnLayout {
                        Layout.preferredWidth: 218
                        Layout.fillHeight: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "今日新词"
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 13
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "待复习 " + String(backend.dueCount || 0)
                                color: T.faint
                                font.family: T.fontCN
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.preferredHeight: 4 }

                        RowLayout {
                            spacing: 6
                            AnimatedNumber {
                                value: backend.todayNew
                                active: page.reveal
                                color: T.ink
                                font.family: T.fontEN
                                font.pixelSize: 54
                                font.bold: true
                            }
                            Text {
                                text: "词"
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 12
                            }
                        }

                        Item { Layout.preferredHeight: 10 }

                        AccentBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            value: backend.dailyGoal > 0
                                   ? Math.min(1, Number(backend.todayNew || 0) / Number(backend.dailyGoal))
                                   : 0
                            color1: T.accent
                        }

                        Item { Layout.preferredHeight: 9 }

                        Text {
                            text: String(backend.todayNew || 0) + " / " + String(backend.dailyGoal || 0)
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 12
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // -------------------------------------------------------------
            // Weekly chart
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 330
                radius: 16
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "本周新词"
                                color: T.ink
                                font.family: T.fontCN
                                font.pixelSize: 21
                                font.bold: true
                            }
                            Text {
                                text: "全部词书的单词与词组，按首次学习日计数。"
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: 68
                            radius: 7
                            color: T.neutralPale
                            Text {
                                anchors.centerIn: parent
                                text: "近 7 天"
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 24
                            anchors.bottomMargin: 22
                            color: "transparent"

                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 1
                                    y: (parent.height / 3) * index
                                    color: T.line
                                    opacity: 0.7
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            Repeater {
                                model: (backend.stats && backend.stats.week) || [0, 0, 0, 0, 0, 0, 0]
                                delegate: Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property real maxValue: T.weekMax((backend.stats && backend.stats.week) || [1])
                                    readonly property real ratio: Number(modelData) / maxValue

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 22
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(42, parent.width - 14)
                                        height: page.reveal ? Math.max(6, (parent.height - 52) * ratio) : 6
                                        radius: 4
                                        color: T.accent
                                        Behavior on height { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: 5
                                            text: String(modelData)
                                            color: T.muted
                                            font.family: T.fontEN
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: T.weekLabel(index)
                                        color: index === 6 ? T.ink : T.faint
                                        font.family: T.fontCN
                                        font.pixelSize: 12
                                        font.bold: index === 6
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: scopePicker
        parent: page
        width: 220
        height: 154
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10
            color: T.white
            border.width: 1
            border.color: T.lineStrong
        }

        contentItem: Column {
            width: scopePicker.availableWidth

            Repeater {
                model: [
                    { label: "新词 + 复习", value: "mix" },
                    { label: "只学新词", value: "new" },
                    { label: "只复习", value: "review" }
                ]
                delegate: Rectangle {
                    width: parent.width
                    height: 46
                    radius: 8
                    color: scopeRowHover.hovered ? T.neutralPale : "transparent"
                    HoverHandler { id: scopeRowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            backend.setStudyScope(modelData.value)
                            scopePicker.close()
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.label)
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: backend.studyScope === modelData.value
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

}
