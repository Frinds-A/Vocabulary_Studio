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

                    Item {
                        anchors.fill: parent
                        visible: dialog.section === 2
                        Flickable {
                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: guideColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                            ColumnLayout {
                                id: guideColumn
                                width: parent.width - 20
                                spacing: 14

                                Text {
                                    text: "使用说明"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 96
                                    radius: 12
                                    color: T.neutralPale
                                    border.width: 1
                                    border.color: T.lineStrong

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Rectangle {
                                            width: 34
                                            height: 34
                                            radius: 17
                                            color: T.ink
                                            Text {
                                                anchors.centerIn: parent
                                                text: "★"
                                                color: T.white
                                                font.family: T.fontEN
                                                font.pixelSize: 16
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Text {
                                                Layout.fillWidth: true
                                                text: "这个词序是我一个人独立开发的，没有团队，也没有广告。"
                                                color: T.ink
                                                font.family: T.fontCN
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: "源码在 GitHub 上；如果它帮你多记住了一个词，欢迎去点一颗 Star，喵！QAQ"
                                                color: T.inkSoft
                                                font.family: T.fontCN
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                                lineHeight: 1.45
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: "github.com/Frinds-A/Vocabulary_Studio"
                                                color: T.accent
                                                font.family: T.fontEN
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Qt.openUrlExternally("https://github.com/Frinds-A/Vocabulary_Studio")
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "推荐使用顺序"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "每天先点「今日计划」，先复习到期词，再学新词。建议每次 15–30 分钟，连续学习比一次背很多更有效；每个词会过两遍，不用追求一次就记住。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "三种练习怎么选"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "拼写：默认模式，最扎实，适合第一次学新词；选择题：从中文释义中选答案，适合词组和快速复习；听音拼写：练辨音和听力，适合复习已经见过的词。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "卡住时怎么用"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "先自己想；实在记不起再点「提示」看首字母，仍不会再点「显示答案」。显示答案会把答案填在短横线上并进入复习；建议随后点「重新拼写」再写一遍，不要直接下一题。拼错后可以点「忘记了」直接看答案。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "复习、生词本与数据"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "到期词会按 1、2、4、7、15、30 天安排复习；不熟的词可以放进生词本，熟词页也可以重新标为生词。学习记录只保存在本机，建议定期在「数据」里导出备份；「一键格式化」不可恢复。发音可在「通用」里切换美式 / 英式。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: T.line
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 6
                                    color: T.neutralPale
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Text {
                                            Layout.fillWidth: true
                                            text: "功能"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        Text {
                                            text: "快捷键"
                                            color: T.muted
                                            font.family: T.fontCN
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                }
                                Repeater {
                                    model: [
                                        { feature: "返回 / 退出全屏", key: "Esc" },
                                        { feature: "上一词 / 下一词", key: "← / →" },
                                        { feature: "判定 / 下一题", key: "Enter" },
                                        { feature: "全屏", key: "F11" },
                                        { feature: "提示首字母", key: "Alt + K" },
                                        { feature: "显示答案", key: "Alt + A" },
                                        { feature: "重新拼写", key: "Alt + R" },
                                        { feature: "跳过", key: "Alt + S" },
                                        { feature: "切换练习模式", key: "1 / 2 / 3" },
                                        { feature: "更换词库", key: "Ctrl + K" },
                                        { feature: "开始学习", key: "Ctrl + Enter" },
                                        { feature: "选择 A–D", key: "1–4" },
                                        { feature: "切换页面", key: "Ctrl + H/L/P/B/T/," },
                                        { feature: "朗读当前单词", key: "Ctrl + R" },
                                        { feature: "收藏当前单词", key: "Ctrl + D" }
                                    ]
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.feature
                                                color: T.inkSoft
                                                font.family: T.fontCN
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                text: modelData.key
                                                color: T.muted
                                                font.family: T.fontCN
                                                font.pixelSize: 12
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: T.line
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "每个单词一轮中会学习两遍；拼错时先看正确答案和例句，再反复重写直到正确；重写时可点「忘记了」自动补全；拼写、选择题和听音界面都可点「显示答案」，拼写答案会直接填在短横线上，随后可点「重新拼写」，且不计入正确次数。待复习按 1、2、4、7、15、30 天安排。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.5
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: 4
                                    color: T.line
                                }
                                Text {
                                    text: "分享包使用说明"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "运行环境：Windows 10 / Windows 11，64 位；无需安装、联网或注册。解压后双击「词序.exe」即可。若出现 SmartScreen 提示，点「更多信息」→「仍要运行」。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "数据位置：%LOCALAPPDATA%\\词序桌面版\\state.json。学习记录只保存在本机，不会上传。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "迁移进度：在「数据与备份」中导出 JSON，发给对方后由对方导入备份即可；只发 state.json 不能替代程序。"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.55
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: 8
                                    color: T.line
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    text: "致使用词序的你："
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "欢迎使用词序。愿这里安静的每一页，都能陪你多记住一个词，也多靠近一点想去的地方。"
                                    color: T.inkSoft
                                    font.family: T.fontCN
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.6
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    text: "—— Petrichor"
                                    color: T.muted
                                    font.family: T.fontEN
                                    font.pixelSize: 13
                                    font.italic: true
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
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
