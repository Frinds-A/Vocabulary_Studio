import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T
import "../components"

Item {
    id: page
    property bool reveal: false
    property bool hadResult: false
    readonly property string currentWord: backend.current ? String(backend.current.word || "") : ""
    property real promptOpacity: 1

    function durationText(seconds) {
        var s = Math.max(0, Number(seconds || 0))
        var m = Math.floor(s / 60)
        return m > 0 ? (m + " 分 " + (s % 60) + " 秒") : (s + " 秒")
    }
    property real promptScale: 1
    property real contentOpacity: 1
    property real contentShift: 0
    property string lastEntryId: ""
    property string lastDictationId: ""
    property bool inputHandledEnter: false
    property bool immersiveMode: false
    readonly property bool answerFocused: answerInput.activeFocus
    readonly property bool hasRetryResult: backend.retryResult !== null
                                            && backend.retryResult !== undefined

    signal requestImmersive()
    signal focusFullscreenRequested()
    signal hintRequested()

    function focusAnswer() {
        if (!page.immersiveMode && !page.hasRetryResult && backend.page === "practice"
                && backend.hasSession && backend.currentMode !== "choice" && !backend.result)
            Qt.callLater(function() { answerInput.forceActiveFocus() })
    }

    onVisibleChanged: {
        if (visible)
            focusAnswer()
    }

    function selectedDeck() {
        var all = backend.decks || []
        for (var i = 0; i < all.length; ++i)
            if (all[i].id === backend.selectedDeckId)
                return all[i]
        return null
    }

    function openDeckPicker() {
        deckPicker.open()
    }

    function syncEntry() {
        var entry = backend.current
        var id = entry ? String(entry.id || "") : ""
        if (id !== page.lastEntryId) {
            page.lastEntryId = id
            page.promptOpacity = 0.25
            page.promptScale = 0.975
            page.contentOpacity = 0
            page.contentShift = 10
            promptIn.restart()
            wordIn.restart()
            if (id && backend.currentMode === "dictation"
                    && (!backend.settings || backend.settings.autoSpeak !== false)) {
                page.lastDictationId = id
                Qt.callLater(function() { backend.speak(page.currentWord) })
            }
        }
    }

    function enter() {
        reveal = false
        replayTimer.restart()
        syncEntry()
        if (backend.hasSession && backend.currentMode !== "choice")
            Qt.callLater(function() { answerInput.forceActiveFocus() })
    }

    Timer {
        id: replayTimer
        interval: 40
        onTriggered: page.reveal = true
    }

    SequentialAnimation {
        id: promptIn
        NumberAnimation { target: page; property: "promptOpacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: page; property: "promptScale"; to: 1; duration: 360; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: wordIn
        NumberAnimation { target: page; property: "contentOpacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: page; property: "contentShift"; to: 0; duration: 360; easing.type: Easing.OutCubic }
    }

    Connections {
        target: backend
        function onAnswerChanged() {
            if (answerInput && answerInput.text !== String(backend.answer || ""))
                answerInput.text = String(backend.answer || "")
        }
        function onStateChanged() {
            page.syncEntry()
            if (answerInput && answerInput.text !== String(backend.answer || ""))
                answerInput.text = String(backend.answer || "")
            if (backend.result && !page.hadResult) {
                page.hadResult = true
                Qt.callLater(function() {
                    if (backend.result && backend.result.revealed && backend.currentMode !== "choice")
                        practiceScroll.contentY = 0
                    else
                        practiceScroll.contentY = Math.max(0, practiceScroll.contentHeight - practiceScroll.height)
                    if (backend.currentMode !== "choice")
                        answerInput.forceActiveFocus()
                })
            } else if (!backend.result && page.hadResult) {
                page.hadResult = false
                practiceScroll.contentY = 0
                if (backend.currentMode !== "choice")
                    Qt.callLater(function() { answerInput.forceActiveFocus() })
            }
            if (!backend.result && backend.hasSession && backend.currentMode !== "choice")
                page.focusAnswer()
        }
    }

    Flickable {
        id: practiceScroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: practiceColumn.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: practiceColumn
            x: 40
            width: parent.width - 80
            anchors.top: parent.top
            spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: !backend.hasSession || backend.sessionComplete

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "选择练习方式"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 21
                    font.bold: true
                }
                Text {
                    text: "按自己的节奏，把每一个词记得更久。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 38
                implicitWidth: deckLabel.implicitWidth + 34
                radius: 19
                color: T.paleViolet
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: deckPicker.open() }
                Row {
                    id: deckLabel
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        text: "▤"
                        color: T.violet
                        font.family: T.fontCN
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: page.selectedDeck() ? page.selectedDeck().name : "未选择词库"
                        color: T.violet
                        font.family: T.fontCN
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            TextButton {
                text: "更换词库"
                onClicked: deckPicker.open()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            visible: !backend.hasSession || backend.sessionComplete

            Text {
                text: "范围"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
            }
            Chip {
                label: "新词 + 复习"
                selected: backend.studyScope === "mix"
                onClicked: backend.setStudyScope("mix")
            }
            Chip {
                label: "只学新词"
                selected: backend.studyScope === "new"
                onClicked: backend.setStudyScope("new")
            }
            Chip {
                label: "只复习"
                selected: backend.studyScope === "review"
                onClicked: backend.setStudyScope("review")
            }
            Text {
                text: "每章 " + String(backend.chapterSize) + " 词"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
                visible: backend.chapterMode
            }
            Item { Layout.fillWidth: true }
            TextButton {
                text: "随机混合"
                onClicked: backend.startRandom()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: !backend.hasSession || backend.sessionComplete

            ModeCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                mode: "spelling"
                title: "拼写练习"
                subtitle: "看中文，写出英文"
                glyph: "✎"
                shortcut: "1"
                selected: backend.currentMode === "spelling"
                onClicked: backend.setMode("spelling")
            }
            ModeCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                mode: "choice"
                title: "选择题"
                subtitle: "看英文，选择正确的中文释义"
                glyph: "◉"
                shortcut: "2"
                selected: backend.currentMode === "choice"
                onClicked: backend.setMode("choice")
            }
            ModeCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                mode: "dictation"
                title: "听音拼写"
                subtitle: "听发音，写出单词或词组"
                glyph: "♫"
                shortcut: "3"
                selected: backend.currentMode === "dictation"
                onClicked: backend.setMode("dictation")
            }
        }

        // -------------------------------------------------------------
        // Question card
        // -------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: backend.hasSession && !backend.sessionComplete ? 620 : 520
            radius: 12
            color: T.white
            border.width: 1
            border.color: T.line
            clip: true

            // ---------------------------------------------------------
            // Empty state
            // ---------------------------------------------------------
            Column {
                anchors.centerIn: parent
                spacing: 14
                visible: !backend.hasSession && !backend.sessionComplete

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84
                    height: 84
                    radius: 12
                    color: T.accent
                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: T.white
                        font.family: T.fontEN
                        font.pixelSize: 46
                        font.italic: true
                        font.bold: true
                    }
                }
                Item { width: 1; height: 4 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "准备好开始了吗？"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 26
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "先选词库，再选择练习方式。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 14
                }
                Item { width: 1; height: 6 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    AppButton {
                        text: "开始今日计划"
                        primary: true
                        onClicked: backend.startPlan("today")
                    }
                    AppButton {
                        text: "选择词库"
                        onClicked: deckPicker.open()
                    }
                }
            }

            // ---------------------------------------------------------
            // Session complete
            // ---------------------------------------------------------
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: backend.sessionComplete

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96
                    height: 96
                    Rectangle {
                        anchors.fill: parent
                        radius: 48
                        color: T.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: T.white
                        font.family: T.fontCN
                        font.pixelSize: 44
                        font.bold: true
                    }
                }
                Item { width: 1; height: 2 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "本轮完成，做得很好。"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 28
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "答对 " + T.displayStat(backend.sessionRight, 0) + " / "
                          + T.displayStat(backend.sessionTotal, 0) + " 题 · 记忆正在慢慢变牢。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 14
                }
                Item { width: 1; height: 2 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 28
                    Column {
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(backend.sessionAccuracy) + "%"
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "正确率"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                    }
                    Column {
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(backend.sessionWpm)
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "WPM"
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 10
                        }
                    }
                    Column {
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.durationText(backend.sessionElapsed)
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "用时"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                    }
                    Column {
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(backend.wrongCount)
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "错题"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                        }
                    }
                }
                Item { width: 1; height: 6 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    AppButton {
                        text: "返回今日计划"
                        primary: true
                        onClicked: backend.exitPractice()
                    }
                    AppButton {
                        text: "下一章"
                        onClicked: backend.startNextChapter()
                    }
                    AppButton {
                        text: "默写本章"
                        onClicked: backend.startChapterDictation()
                    }
                    AppButton {
                        text: "练错题 (" + String(backend.wrongCount) + ")"
                        visible: backend.wrongCount > 0
                        onClicked: backend.startWrongReview()
                    }
                }
            }

            // ---------------------------------------------------------
            // Active question
            // ---------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                anchors.topMargin: 24
                anchors.bottomMargin: 20
                spacing: 0
                visible: backend.hasSession && !backend.sessionComplete

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: "QUESTION " + String(backend.queuePosition || 0)
                              + " / " + String(backend.queueTotal || 0)
                        color: T.faint
                        font.family: T.fontEN
                        font.pixelSize: 10
                        font.letterSpacing: 1.6
                    }

                    OccurrenceBadge {
                        occurrence: backend.currentOccurrence
                        Layout.alignment: Qt.AlignVCenter
                    }

                    AccentBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        value: Number(backend.queueTotal || 0) > 0
                               ? Number(backend.queuePosition || 0) / Number(backend.queueTotal)
                               : 0
                    }

                    Text {
                        text: backend.currentMode === "choice" ? "选择释义"
                              : backend.currentMode === "dictation" ? "听音拼写" : "拼写练习"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 12
                    }

                    TextButton {
                        text: "提示"
                        shortcut: "Alt+K"
                        visible: backend.currentMode === "spelling" && !backend.result && !page.hasRetryResult
                        enabled: String(backend.answer || "").length === 0
                        onClicked: {
                            backend.hintFirstLetter()
                            Qt.callLater(function() { answerInput.forceActiveFocus() })
                        }
                    }
                    TextButton {
                        text: "显示答案"
                        shortcut: "Alt+A"
                        visible: backend.hasSession && !backend.result && !backend.retrying && !page.hasRetryResult
                        onClicked: backend.revealAnswer()
                    }
                    TextButton {
                        text: "重新拼写"
                        shortcut: "Alt+R"
                        visible: backend.result !== null && backend.result !== undefined
                                 && backend.result.revealed === true && backend.currentMode !== "choice"
                        onClicked: {
                            backend.startRetry()
                            Qt.callLater(function() { answerInput.forceActiveFocus() })
                        }
                    }
                    TextButton {
                        text: "上一词"
                        shortcut: "←"
                        visible: backend.canGoPrevious
                        onClicked: {
                            backend.previous()
                            page.focusAnswer()
                        }
                    }
                    TextButton {
                        text: "全屏专注"
                        shortcut: "F11"
                        visible: backend.currentMode === "spelling"
                        onClicked: page.requestImmersive()
                    }
                    TextButton {
                        text: "跳过"
                        shortcut: "Alt+S"
                        visible: !backend.retrying && !page.hasRetryResult
                        onClicked: backend.skip()
                    }
                    TextButton {
                        text: "退出"
                        shortcut: "Esc"
                        visible: backend.hasSession
                        onClicked: backend.exitPractice()
                    }
                }

                Item { Layout.fillHeight: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    opacity: page.contentOpacity * page.promptOpacity
                    scale: page.promptScale
                    transform: Translate { y: page.contentShift }

                    // Choice prompt
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.currentMode === "choice"
                        text: backend.current ? String(backend.current.word || "") : ""
                        color: T.ink
                        font.family: T.fontEN
                        font.pixelSize: 56
                        font.bold: true
                        font.letterSpacing: 0.2
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.currentMode === "choice" && backend.current !== null && backend.current !== undefined
                                 && String(backend.current.phonetic || "").length > 0
                        text: backend.current ? "/" + String(backend.current.phonetic || "") + "/" : ""
                        color: T.muted
                        font.family: T.fontEN
                        font.pixelSize: 15
                    }

                    // Dictation prompt
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.currentMode === "dictation"
                        width: 112
                        height: 112

                        Rectangle {
                            anchors.fill: parent
                            radius: 56
                            color: T.ink
                            scale: playHover.hovered ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "♫"
                            color: T.white
                            font.family: T.fontCN
                            font.pixelSize: 40
                        }
                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: backend.speak(page.currentWord) }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.currentMode === "dictation"
                        text: "点击播放，听写这个单词"
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 14
                    }

                    // Meanings for spelling
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 780
                        Layout.fillWidth: true
                        spacing: 12
                        visible: backend.currentMode === "spelling"
                        Repeater {
                            model: T.senseRows(backend.current || ({}))
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: T.posLabel(modelData.pos)
                                    color: T.rose
                                    font.family: T.fontEN
                                    font.pixelSize: 16
                                    font.italic: true
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: T.rowMeaning(modelData)
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 25
                                    lineHeight: 1.3
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // Choice options
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: 660
                        spacing: 9
                        visible: backend.currentMode === "choice"
                        Repeater {
                            model: backend.choices || []
                            delegate: Rectangle {
                                id: choiceRow
                                readonly property bool isCorrect: backend.result !== null
                                                                  && backend.result !== undefined
                                                                  && modelData.correct
                                readonly property bool isWrongPick: backend.result !== null
                                                                    && backend.result !== undefined
                                                                    && !backend.result.correct
                                                                    && String(modelData.id) === String(backend.answer)
                                Layout.fillWidth: true
                                implicitHeight: 54
                                radius: 10
                                color: isCorrect ? T.greenPale
                                                 : (isWrongPick ? T.redPale
                                                    : (choiceHover.hovered ? T.neutralSoft : T.white))
                                border.width: 1
                                border.color: isCorrect ? T.green
                                             : (isWrongPick ? T.red
                                                : (choiceHover.hovered ? T.lineStrong : T.line))
                                scale: choiceTap.pressed ? 0.988 : 1
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on border.color { ColorAnimation { duration: 180 } }
                                Behavior on scale { NumberAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 15
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 6
                                        color: choiceRow.isCorrect ? T.green
                                               : (choiceRow.isWrongPick ? T.red : T.neutralPale)
                                        Text {
                                            anchors.centerIn: parent
                                            text: String.fromCharCode(65 + index)
                                            color: (choiceRow.isCorrect || choiceRow.isWrongPick) ? T.white : T.muted
                                            font.family: T.fontEN
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.text || modelData.meaning || ""
                                        color: T.ink
                                        font.family: T.fontCN
                                        font.pixelSize: 15
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: choiceRow.isCorrect
                                        text: "✓"
                                        color: T.green
                                        font.family: T.fontCN
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }

                                HoverHandler { id: choiceHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: choiceTap; onTapped: backend.choose(modelData.id) }
                            }
                        }
                    }

                    // Input — short letter dashes, matching the focus screen
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.currentMode !== "choice" && !page.hasRetryResult
                        spacing: 14

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4
                            visible: backend.retrying
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: backend.retryWrong ? "再试一次" : "重新默写一次"
                                color: backend.retryWrong ? T.red : T.ink
                                font.family: T.fontCN
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: practiceSlots.implicitWidth
                            implicitHeight: 68

                            Row {
                                id: practiceSlots
                                anchors.centerIn: parent
                                spacing: 9
                                readonly property string word: page.currentWord
                                readonly property int letterCount: T.wordLetterCount(word)
                                readonly property real slotWidth: Math.max(20, Math.min(46,
                                    (620 - Math.max(0, letterCount - 1) * 9) / Math.max(1, letterCount)))

                                Repeater {
                                    model: practiceSlots.word.length
                                    delegate: Item {
                                        readonly property string ch: practiceSlots.word.charAt(index)
                                        readonly property bool isLetter: T.isLetterAt(practiceSlots.word, index)
                                        readonly property int slotNumber: T.slotIndexAt(practiceSlots.word, index)
                                        readonly property string typed: String(backend.answer || "")
                                        readonly property var answerMark: (backend.result && backend.result.answerMarks
                                                                           && slotNumber < backend.result.answerMarks.length)
                                                                          ? backend.result.answerMarks[slotNumber] : null
                                        readonly property bool wrongLetter: answerMark !== null
                                                                            && answerMark.wrong === true
                                        readonly property bool isCurrent: isLetter && !backend.result
                                                                         && slotNumber === typed.length
                                        width: isLetter ? practiceSlots.slotWidth : (ch === " " ? 12 : 16)
                                        height: 68

                                        Rectangle {
                                            id: practiceDash
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: isCurrent ? 3 : 2
                                            radius: 1.5
                                            color: backend.result
                                                   ? (backend.result.correct ? T.green
                                                      : (wrongLetter ? T.mistakeLine : T.lineStrong))
                                                   : (isCurrent ? T.accent
                                                      : (slotNumber < typed.length ? T.inkSoft : T.lineStrong))
                                        }

                                        Rectangle {
                                            visible: parent.wrongLetter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: practiceDash.top
                                            anchors.bottomMargin: 4
                                            width: parent.width
                                            height: 40
                                            radius: 7
                                            color: T.mistakePale
                                        }

                                        Text {
                                            anchors.bottom: practiceDash.top
                                            anchors.bottomMargin: 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: parent.isLetter && parent.slotNumber < parent.typed.length
                                                  ? parent.typed.charAt(parent.slotNumber) : ""
                                            color: backend.result
                                                   ? (backend.result.correct ? T.green
                                                      : (wrongLetter ? T.mistakeInk : T.muted))
                                                   : T.ink
                                            font.family: T.fontEN
                                            font.pixelSize: 34
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: answerInput.forceActiveFocus() }
                        }

                        AppButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: backend.retrying ? "提交重写" : "检查"
                            shortcut: "Enter"
                            primary: true
                            implicitHeight: 44
                            implicitWidth: 108
                            fontSize: 14
                            radiusValue: 10
                            visible: !backend.result
                            enabled: String(backend.answer || "").trim().length > 0
                            onClicked: backend.retrying ? backend.submitRetry() : backend.submit()
                        }
                        TextButton {
                            Layout.alignment: Qt.AlignHCenter
                            visible: backend.retrying
                            text: "忘记了"
                            onClicked: backend.forgotAnswer()
                        }
                    }

                    Item { Layout.preferredHeight: 2 }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 640
                        Layout.fillWidth: true
                        spacing: 10
                        visible: page.hasRetryResult

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "正确拼写"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 11
                            font.letterSpacing: 1.2
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: backend.retryResult ? String(backend.retryResult.expected || "") : ""
                            color: T.ink
                            font.family: T.fontEN
                            font.pixelSize: 34
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            visible: String((backend.current && backend.current.example) || "").length > 0
                            text: String((backend.current && backend.current.example) || "")
                            color: T.muted
                            font.family: T.fontEN
                            font.pixelSize: 15
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.35
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: String((backend.current && backend.current.exampleZh) || "").length > 0
                            text: String((backend.current && backend.current.exampleZh) || "")
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.35
                        }
                        AppButton {
                            objectName: "retryNextButton"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 42
                            Layout.preferredWidth: 112
                            text: "下一题"
                            primary: true
                            implicitHeight: 42
                            implicitWidth: 112
                            fontSize: 13
                            focus: page.hasRetryResult
                            Keys.onReturnPressed: function(event) {
                                backend.next()
                                event.accepted = true
                            }
                            Keys.onEnterPressed: function(event) {
                                backend.next()
                                event.accepted = true
                            }
                            onClicked: backend.next()
                        }
                    }

                    // Feedback
                    FeedbackPanel {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 900
                        Layout.alignment: Qt.AlignHCenter
                        onNextRequested: backend.next()
                        onRetryRequested: backend.startRetry()
                        onCollectRequested: backend.toggleNotebook()
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
    }
    TextInput {
        id: answerInput
        objectName: "practiceAnswerInput"
        width: 2
        height: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        opacity: 0.01
        color: "transparent"
        selectionColor: "transparent"
        cursorVisible: false
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhLatinOnly
        validator: RegularExpressionValidator {
            regularExpression: /[A-Za-zÀ-ÿ .,'’()?…\/-]*/
        }
        focus: !page.immersiveMode && backend.page === "practice" && backend.hasSession
               && backend.currentMode !== "choice" && !backend.result
               && !page.hasRetryResult
        maximumLength: page.currentWord.length
        text: backend.answer || ""
        onTextEdited: {
            backend.playInputSound()
            backend.setAnswer(text)
        }
        onAccepted: {
            page.inputHandledEnter = true
            if (backend.retryResult !== null && backend.retryResult !== undefined)
                backend.next()
            else if (backend.retrying)
                backend.submitRetry()
            else if (backend.result) {
                if (!backend.result.correct && !backend.result.skipped)
                    backend.startRetry()
                else
                    backend.next()
            } else {
                backend.submit()
            }
            Qt.callLater(function() { page.inputHandledEnter = false })
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_F11) {
                page.focusFullscreenRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_K && (event.modifiers & Qt.AltModifier)) {
                page.hintRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_A && (event.modifiers & Qt.AltModifier)) {
                backend.revealAnswer()
                event.accepted = true
            } else if (event.key === Qt.Key_R && (event.modifiers & Qt.AltModifier)) {
                backend.startRetry()
                event.accepted = true
            } else if (event.key === Qt.Key_S && (event.modifiers & Qt.AltModifier)) {
                backend.skip()
                event.accepted = true
            }
        }
        Keys.onLeftPressed: function(event) {
            if (backend.page === "practice" && backend.hasSession)
                backend.previous()
            event.accepted = true
        }
        Keys.onRightPressed: function(event) {
            if (backend.page === "practice" && backend.hasSession) {
                if (backend.retryResult !== null && backend.retryResult !== undefined)
                    backend.next()
                else if (backend.result)
                    backend.next()
            }
            event.accepted = true
        }
    }

    Popup {
        id: deckPicker
        objectName: "deckPicker"
        parent: page
        width: 340
        height: Math.min(390, 52 + Math.max(1, (backend.decks || []).length) * 46)
        x: Math.max(20, page.width - width - 40)
        y: 154
        padding: 6
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: T.white
            border.width: 1
            border.color: T.lineStrong
        }

        contentItem: Column {
            width: deckPicker.availableWidth
            spacing: 4

            Text {
                width: parent.width
                height: 30
                leftPadding: 10
                text: "选择词库"
                color: T.muted
                font.family: T.fontCN
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }

            ListView {
                id: deckList
                width: parent.width
                height: Math.min(330, Math.max(1, (backend.decks || []).length) * 44)
                clip: true
                model: backend.decks || []
                spacing: 1
                ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: deckList.width
                    height: 44
                    radius: 8
                    color: deckHover.hovered ? T.neutralPale : "transparent"

                    HoverHandler { id: deckHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            backend.selectDeck(String(modelData.id))
                            deckPicker.close()
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: deckType.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.name || "")
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        id: deckType
                        anchors.right: deckCheck.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.type === "phrases" ? "词组" : "单词"
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 10
                    }
                    Text {
                        id: deckCheck
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: String(modelData.id) === String(backend.selectedDeckId)
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
