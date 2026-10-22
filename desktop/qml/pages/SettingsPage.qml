import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    signal importRequested()
    signal exportBackupRequested()
    signal importBackupRequested()
    property bool reveal: false
    property int goalValue: 20

    function shortName(deck) {
        var name = String((deck && deck.name) || "")
        return name.replace("核心单词", "单词").replace("精选词组", "词组")
                   .replace("常用词组", "词组").replace("考研", "考研")
    }

    function syncGoal() {
        page.goalValue = Number(backend.goalPerDeck || 20)
    }

    function clampGoal(value) {
        return Math.max(5, Math.min(200, Math.round(value / 5) * 5))
    }

    function applyGoal(value) {
        var next = clampGoal(value)
        page.goalValue = next
        backend.setSelectedGoals(next)
    }

    function enter() {
        reveal = false
        replayTimer.restart()
        syncGoal()
    }

    Timer {
        id: replayTimer
        interval: 40
        onTriggered: page.reveal = true
    }

    Connections {
        target: backend
        function onStateChanged() { page.syncGoal() }
        function onGoalsChanged() { page.syncGoal() }
    }

    Component.onCompleted: syncGoal()

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: settingsColumn
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 14

            // ---------------------------------------------------------
            // Daily goal
            // ---------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 188
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "每日新词目标"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: "可同时选择多本；今日目标为所选词书之和"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "PLAN"
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 10
                            font.letterSpacing: 1.7
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9
                        Repeater {
                            model: backend.decks || []
                            delegate: Chip {
                                label: page.shortName(modelData)
                                selected: (backend.selectedDeckIds || []).indexOf(modelData.id) >= 0
                                onClicked: backend.toggleDeckSelection(modelData.id)
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: T.line
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "每本词书每天学"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 13
                        }
                        Item { Layout.fillWidth: true }
                        StepButton {
                            glyph: "−"
                            onClicked: page.applyGoal(page.goalValue - 5)
                        }
                        Item {
                            width: 66
                            height: 40
                            Text {
                                anchors.centerIn: parent
                                text: String(page.goalValue)
                                color: T.ink
                                font.family: T.fontEN
                                font.pixelSize: 30
                                font.bold: true
                            }
                        }
                        StepButton {
                            glyph: "＋"
                            onClicked: page.applyGoal(page.goalValue + 5)
                        }
                        Text {
                            text: "个 / 本 · 合计 " + String(backend.dailyGoal || 0) + " 词"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // ---------------------------------------------------------
            // Toggles
            // ---------------------------------------------------------
            SettingToggle {
                Layout.fillWidth: true
                title: "答题后自动播放发音"
                subtitle: "无论回答是否正确，提交后播放单词读音"
                glyph: "♫"
                checked: !backend.settings || backend.settings.autoSpeak !== false
                onToggled: backend.saveSetting("autoSpeak", !checked)
            }

            SettingToggle {
                Layout.fillWidth: true
                title: "间隔复习计划"
                subtitle: "按记忆间隔安排到期复习：10 分钟 → 1 天 → 2 天 → 4 天…"
                glyph: "↻"
                checked: !backend.settings || backend.settings.spacedRepetition !== false
                onToggled: backend.saveSetting("spacedRepetition", !checked)
            }

            SettingToggle {
                Layout.fillWidth: true
                title: "生词本加入今日计划"
                subtitle: "开启后先复习生词本，再学新词"
                glyph: "▤"
                checked: backend.settings && backend.settings.includeNotebook === true
                onToggled: backend.saveSetting("includeNotebook", !checked)
            }

            // ---------------------------------------------------------
            // Usage
            // ---------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: usageColumn.implicitHeight + 44
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    id: usageColumn
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 8

                    Text {
                        text: "使用说明"
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 17
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Esc 返回上一页或退出全屏/专注；← → 上一词 / 下一词；Enter 判定或下一题。"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        lineHeight: 1.45
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "F11 全屏；Alt+K 提示首字母；1–4 选择 A–D（仅词组选择题）；Ctrl+H/L/P/B/T 和 Ctrl+, 切换页面；Ctrl+R 发音；Ctrl+D 收藏。"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        lineHeight: 1.45
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "拼错时先看正确答案和例句，再重写一次；重写不计入掌握。每次提交、切题、退出都会自动保存。"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        lineHeight: 1.45
                    }
                }
            }

            // ---------------------------------------------------------
            // Data
            // ---------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "数据与备份"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: "学习记录保存在本机，换电脑时可导出备份继续。"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LOCAL · OFFLINE"
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        AppButton {
                            text: "导入单词书"
                            shortcut: "Ctrl+I"
                            implicitHeight: 40
                            fontSize: 13
                            radiusValue: 10
                            onClicked: page.importRequested()
                        }
                        AppButton {
                            text: "导出备份"
                            shortcut: "Ctrl+E"
                            implicitHeight: 40
                            fontSize: 13
                            radiusValue: 10
                            onClicked: page.exportBackupRequested()
                        }
                        AppButton {
                            text: "导入备份"
                            shortcut: "Ctrl+Shift+I"
                            implicitHeight: 40
                            fontSize: 13
                            radiusValue: 10
                            onClicked: page.importBackupRequested()
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "支持 PDF / TXT / CSV / JSON"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // ---------------------------------------------------------
            // About
            // ---------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                radius: 12
                color: T.white
                border.width: 1
                border.color: T.line

                Item {
                    anchors.fill: parent
                    anchors.margins: 22

                    Rectangle {
                        id: aboutLogo
                        width: 44
                        height: 44
                        radius: 10
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: T.ink
                        Text {
                            anchors.centerIn: parent
                            text: "词"
                            color: T.white
                            font.family: T.fontCN
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    Column {
                        anchors.left: aboutLogo.right
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "词序 · Vocabulary Studio"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            text: "Version " + updater.currentVersion + " · 离线运行 · 无需注册"
                            color: T.muted
                            font.family: T.fontCN
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: 150
                            height: 1
                            color: T.line
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "MADE FOR\nYOUR GROWTH"
                        color: T.faint
                        font.family: T.fontEN
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        horizontalAlignment: Text.AlignRight
                        lineHeight: 1.5
                    }
                }
            }
        }
    }
}
