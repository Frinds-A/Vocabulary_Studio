import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: dialog
    objectName: "settingsDialog"
    signal closed()
    signal importRequested()
    signal exportBackupRequested()
    signal importBackupRequested()
    signal formatted()
    signal updateRequested()

    property int section: 0
    property int goalValue: 20
    property bool resetConfirmOpen: false

    readonly property var wordDeckOptions: {
        var result = [{ id: "", name: "不选单词书" }]
        var decks = backend.decks || []
        for (var i = 0; i < decks.length; ++i)
            if (decks[i].type !== "phrases")
                result.push({ id: decks[i].id, name: decks[i].name })
        return result
    }
    readonly property var phraseDeckOptions: {
        var result = [{ id: "", name: "不选词组" }]
        var decks = backend.decks || []
        for (var i = 0; i < decks.length; ++i)
            if (decks[i].type === "phrases")
                result.push({ id: decks[i].id, name: decks[i].name })
        return result
    }

    anchors.fill: parent
    visible: false
    z: 200

    function shortName(deck) {
        var name = String((deck && deck.name) || "")
        return name.replace("核心单词", "单词").replace("精选词组", "词组")
                   .replace("常用词组", "词组").replace("考研", "考研")
    }

    function syncGoal() {
        goalValue = Number(backend.goalPerDeck || 20)
    }

    function clampGoal(value) {
        return Math.max(5, Math.min(200, Math.round(value / 5) * 5))
    }

    function applyGoal(value) {
        var next = clampGoal(value)
        goalValue = next
        backend.setSelectedGoals(next)
    }

    function close() {
        closed()
    }

    function openGuide(index) {
        section = 2
        guidePanel.open(index || 0)
    }

    onVisibleChanged: {
        if (visible) {
            section = 0
            syncGoal()
        } else {
            resetConfirmOpen = false
        }
    }

    Connections {
        target: backend
        function onStateChanged() { dialog.syncGoal() }
        function onGoalsChanged() { dialog.syncGoal() }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 12
        color: "#5A000000"
        MouseArea {
            anchors.fill: parent
            onClicked: dialog.close()
        }
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width - 48, 1000)
        height: Math.min(parent.height - 40, 740)
        anchors.centerIn: parent
        radius: 14
        color: T.white
        border.width: 1
        border.color: T.lineStrong
        antialiasing: true

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Text {
                    text: "设置"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 22
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                TextButton {
                    text: "关闭"
                    shortcut: "Esc"
                    bordered: true
                    onClicked: dialog.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                ColumnLayout {
                    Layout.preferredWidth: 140
                    Layout.fillHeight: true
                    spacing: 4

                    Repeater {
                        model: [["通用", "GENERAL"], ["数据", "DATA"], ["使用说明", "GUIDE"]]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            radius: 9
                            color: dialog.section === index ? T.neutralPale : "transparent"
                            border.width: navHover.hovered && dialog.section !== index ? 1 : 0
                            border.color: T.lineStrong

                            HoverHandler {
                                id: navHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler { onTapped: dialog.section = index }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: modelData[0]
                                    color: dialog.section === index ? T.ink : T.inkSoft
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: dialog.section === index
                                }
                                Text {
                                    text: modelData[1]
                                    color: T.faint
                                    font.family: T.fontEN
                                    font.pixelSize: 8
                                    font.letterSpacing: 1.2
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "所有设置自动保存"
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 10
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 760
                    clip: true

                    Item {
                        anchors.fill: parent
                        visible: dialog.section === 0
                        Flickable {
                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: generalColumn.implicitHeight + 16
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                            ColumnLayout {
                                id: generalColumn
                                width: parent.width - 8
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 252
                                    radius: 12
                                    color: T.white
                                    border.width: 1
                                    border.color: T.line

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 10

                                        Text {
                                            text: "学习内容与每日目标"
                                            color: T.ink
                                            font.family: T.fontCN
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                        Text {
                                            text: "单词书和词组各选一本；也可以只选其中一类。"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            DeckSelect {
                                                Layout.fillWidth: true
                                                label: "单词书"
                                                options: dialog.wordDeckOptions
                                                currentId: backend.selectedWordDeckId
                                                onSelected: function(deckId) { backend.setWordDeck(deckId) }
                                            }
                                            DeckSelect {
                                                Layout.fillWidth: true
                                                label: "词组"
                                                options: dialog.phraseDeckOptions
                                                currentId: backend.selectedPhraseDeckId
                                                onSelected: function(deckId) { backend.setPhraseDeck(deckId) }
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: T.line
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "每本词书每天学"
                                                color: T.muted
                                                font.family: T.fontCN
                                                font.pixelSize: 12
                                            }
                                            Item { Layout.fillWidth: true }
                                            StepButton {
                                                glyph: "−"
                                                onClicked: dialog.applyGoal(dialog.goalValue - 5)
                                            }
                                            Item {
                                                width: 44
                                                height: 30
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(dialog.goalValue)
                                                    color: T.ink
                                                    font.family: T.fontEN
                                                    font.pixelSize: 22
                                                    font.bold: true
                                                }
                                            }
                                            StepButton {
                                                glyph: "＋"
                                                onClicked: dialog.applyGoal(dialog.goalValue + 5)
                                            }
                                            Text {
                                                text: "合计 " + String(backend.dailyGoal || 0)
                                                color: T.muted
                                                font.family: T.fontCN
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 112
                                    radius: 12
                                    color: T.white
                                    border.width: 1
                                    border.color: T.line
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 7
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "发音口音"
                                                color: T.ink
                                                font.family: T.fontCN
                                                font.pixelSize: 14
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }
                                            Row {
                                                spacing: 6
                                                Repeater {
                                                    model: [["us", "美式"], ["uk", "英式"]]
                                                    delegate: Rectangle {
                                                        width: 58
                                                        height: 30
                                                        radius: 7
                                                        color: backend.voiceAccent === modelData[0] ? T.ink : T.white
                                                        border.width: 1
                                                        border.color: backend.voiceAccent === modelData[0] ? T.ink : T.lineStrong
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData[1]
                                                            color: backend.voiceAccent === modelData[0] ? T.white : T.inkSoft
                                                            font.family: T.fontCN
                                                            font.pixelSize: 11
                                                        }
                                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                                        TapHandler { onTapped: backend.setVoiceAccent(modelData[0]) }
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            text: "影响自动朗读和听音拼写的发音。"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: backend.voiceAccentStatus
                                            color: backend.voiceAccent === "uk" && !backend.britishVoiceAvailable ? T.red : T.faint
                                            font.family: T.fontCN
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "自动检查更新"
                                    subtitle: "启动时检测新版本；关闭后仍可手动检查"
                                    glyph: "↓"
                                    checked: !backend.settings || backend.settings.autoCheckUpdates !== false
                                    onToggled: backend.saveSetting("autoCheckUpdates", !checked)
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "章节练习"
                                    subtitle: "把每日学习拆成小段，完成一章再继续"
                                    glyph: "▤"
                                    checked: backend.chapterMode
                                    onToggled: backend.saveSetting("chapterMode", !checked)
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 18
                                    Layout.rightMargin: 18
                                    visible: backend.chapterMode
                                    spacing: 8
                                    Text {
                                        text: "每章词数"
                                        color: T.muted
                                        font.family: T.fontCN
                                        font.pixelSize: 11
                                    }
                                    Repeater {
                                        model: [10, 20, 30, 50]
                                        delegate: Chip {
                                            label: String(modelData)
                                            selected: backend.chapterSize === modelData
                                            onClicked: backend.setChapterSize(modelData)
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "输入音效"
                                    subtitle: "敲击键盘时播放轻微按键声"
                                    glyph: "⌨"
                                    checked: backend.inputSound
                                    onToggled: backend.saveSetting("inputSound", !checked)
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 18
                                    Layout.rightMargin: 18
                                    spacing: 8
                                    Text {
                                        text: "发音语速"
                                        color: T.muted
                                        font.family: T.fontCN
                                        font.pixelSize: 11
                                    }
                                    Chip {
                                        label: "慢"
                                        selected: backend.speechRate < -0.1
                                        onClicked: backend.setSpeechRate(-0.25)
                                    }
                                    Chip {
                                        label: "正常"
                                        selected: Math.abs(backend.speechRate) <= 0.1
                                        onClicked: backend.setSpeechRate(0.0)
                                    }
                                    Chip {
                                        label: "快"
                                        selected: backend.speechRate > 0.1
                                        onClicked: backend.setSpeechRate(0.25)
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "自动备份学习记录"
                                    subtitle: "每天保留一份快照，最多 7 份"
                                    glyph: "◷"
                                    checked: !backend.settings || backend.settings.autoBackup !== false
                                    onToggled: backend.saveSetting("autoBackup", !checked)
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "答题后自动播放发音"
                                    subtitle: "提交后播放单词读音"
                                    glyph: "♫"
                                    checked: !backend.settings || backend.settings.autoSpeak !== false
                                    onToggled: backend.saveSetting("autoSpeak", !checked)
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    title: "间隔复习计划"
                                    subtitle: "1 天 → 2 天 → 4 天 → 7 天 → 15 天 → 30 天"
                                    glyph: "↻"
                                    checked: !backend.settings || backend.settings.spacedRepetition !== false
                                    onToggled: backend.saveSetting("spacedRepetition", !checked)
                                }
                                SettingToggle {
                                    Layout.fillWidth: true
                                    visible: backend.selectedWordDeckId !== "" && backend.selectedPhraseDeckId !== ""
                                    title: "生词本加入今日计划"
                                    subtitle: "单词书 + 词组模式下可叠加生词本"
                                    glyph: "▤"
                                    checked: backend.settings && backend.settings.includeNotebook === true
                                    onToggled: backend.saveSetting("includeNotebook", !checked)
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: dialog.section === 1
                        Flickable {
                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: dataColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                            ColumnLayout {
                                id: dataColumn
                                width: parent.width - 8
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 178
                                    radius: 12
                                    color: T.white
                                    border.width: 1
                                    border.color: T.line
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 10
                                        Text {
                                            text: "数据与备份"
                                            color: T.ink
                                            font.family: T.fontCN
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                        Text {
                                            text: "学习记录保存在本机；支持导入 PDF / Word(.docx) / TXT / CSV / JSON 词书。"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            AppButton {
                                                text: "导入单词书"
                                                shortcut: "Ctrl+I"
                                                showBorder: true
                                                implicitHeight: 38
                                                fontSize: 12
                                                onClicked: dialog.importRequested()
                                            }
                                            AppButton {
                                                text: "导出备份"
                                                shortcut: "Ctrl+E"
                                                showBorder: true
                                                implicitHeight: 38
                                                fontSize: 12
                                                onClicked: dialog.exportBackupRequested()
                                            }
                                            AppButton {
                                                text: "导入备份"
                                                shortcut: "Ctrl+Shift+I"
                                                showBorder: true
                                                implicitHeight: 38
                                                fontSize: 12
                                                onClicked: dialog.importBackupRequested()
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        Text {
                                            text: "开发者：Petrichor"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 126
                                    radius: 12
                                    color: T.white
                                    border.width: 1
                                    border.color: T.line
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 8
                                        Text {
                                            text: "格式化学习记录"
                                            color: T.ink
                                            font.family: T.fontCN
                                            font.pixelSize: 15
                                            font.bold: true
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "清除全部学习进度、错词、生词、统计和学习时间；词书、每日目标和个人设置会保留。此操作不可恢复。"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.45
                                        }
                                        AppButton {
                                            text: "一键格式化"
                                            shortcut: "Ctrl+Shift+Delete"
                                            showBorder: true
                                            implicitHeight: 34
                                            fontSize: 12
                                            onClicked: dialog.resetConfirmOpen = true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 112
                                    radius: 12
                                    color: T.white
                                    border.width: 1
                                    border.color: T.line
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 12
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text {
                                                text: "词序 · Vocabulary Studio"
                                                color: T.ink
                                                font.family: T.fontCN
                                                font.pixelSize: 15
                                                font.bold: true
                                            }
                                            Text {
                                                text: "Version " + updater.currentVersion + " · 离线运行 · 无需注册"
                                                color: T.muted
                                                font.family: T.fontCN
                                                font.pixelSize: 11
                                            }
                                            Text {
                                                visible: updater.state === "latest" || updater.state === "error"
                                                text: updater.statusText
                                                color: updater.state === "error" ? T.red : T.faint
                                                font.family: T.fontCN
                                                font.pixelSize: 10
                                            }
                                        }
                                        TextButton {
                                            text: "检查更新"
                                            bordered: true
                                            onClicked: {
                                                updater.checkForUpdates()
                                                dialog.updateRequested()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    GuidePanel {
                        id: guidePanel
                        anchors.fill: parent
                        visible: dialog.section === 2
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 400
        visible: dialog.resetConfirmOpen
        color: "#66000000"

        MouseArea {
            anchors.fill: parent
            onClicked: dialog.resetConfirmOpen = false
        }

        Rectangle {
            width: Math.min(parent.width - 48, 440)
            height: 228
            anchors.centerIn: parent
            radius: 14
            color: T.white
            border.width: 1
            border.color: T.lineStrong

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                Text {
                    text: "确认清除所有学习记录？"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "所有学习进度、错词、生词、学习统计和累计学习时间都会被清空，且无法恢复。词书、每日目标和个人设置会保留。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    lineHeight: 1.55
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    AppButton {
                        text: "取消"
                        showBorder: true
                        implicitHeight: 36
                        fontSize: 12
                        onClicked: dialog.resetConfirmOpen = false
                    }
                    TextButton {
                        text: "确认清除"
                        bordered: true
                        contentColor: T.red
                        onClicked: {
                            backend.resetAllProgress()
                            dialog.resetConfirmOpen = false
                            dialog.formatted()
                        }
                    }
                }
            }
        }
    }
}
