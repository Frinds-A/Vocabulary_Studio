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
    property string lastDictationMode: ""
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

    function notebookContainsCurrent() {
        var list = backend.notebook || []
        var id = backend.current ? String(backend.current.id || "") : ""
        for (var i = 0; i < list.length; ++i)
            if (String(list[i].id) === id)
                return true
        return false
    }

    function selectedDeck() {
        var all = backend.decks || []
        for (var i = 0; i < all.length; ++i)
            if (all[i].id === backend.selectedDeckId)
                return all[i]
        return null
    }

    function scopeName() {
        if (backend.studyScope === "new")
            return "只学新词"
        if (backend.studyScope === "review")
            return "只复习"
        return "新词 + 复习"
    }

    function openRangePicker() {
        var point = rangePill.mapToItem(page, 0, rangePill.height + 6)
        rangePicker.x = Math.max(20, Math.min(page.width - rangePicker.width - 20, point.x))
        rangePicker.y = Math.max(20, Math.min(page.height - rangePicker.height - 20, point.y))
        rangePicker.open()
    }

    function openChapterPicker() {
        chapterPicker.open()
    }

    function openDeckPicker() {
        var point = deckPill.mapToItem(page, 0, deckPill.height + 6)
        deckPicker.x = Math.max(20, Math.min(page.width - deckPicker.width - 20, point.x))
        deckPicker.y = Math.max(20, Math.min(page.height - deckPicker.height - 20, point.y))
        deckPicker.open()
    }

    function maybeSpeakDictation(force) {
        if (backend.page !== "practice" || !backend.hasSession)
            return
        if (backend.currentMode !== "dictation") {
            page.lastDictationMode = backend.currentMode
            return
        }
        var id = backend.current ? String(backend.current.id || "") : ""
        if (!id)
            return
        var modeChanged = page.lastDictationMode !== "dictation"
        page.lastDictationMode = "dictation"
        if (force || modeChanged || page.lastDictationId !== id) {
            page.lastDictationId = id
            Qt.callLater(function() { backend.speak(page.currentWord) })
        }
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
        }
        page.maybeSpeakDictation(false)
    }

    function enter() {
        reveal = false
        replayTimer.restart()
        syncEntry()
        page.maybeSpeakDictation(true)
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
            page.maybeSpeakDictation(false)
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

    Rectangle {
        anchors.fill: parent
        z: -1
        color: backend.hasSession ? T.canvas : "transparent"
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
            spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 10
            visible: false

            Rectangle {
                id: deckPill
                implicitHeight: 40
                implicitWidth: deckLabel.implicitWidth + 32
                radius: 10
                color: T.white
                border.width: 1
                border.color: T.line
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.openDeckPicker() }

                Row {
                    id: deckLabel
                    anchors.centerIn: parent
                    spacing: 7
                    BookGlyph {
                        width: 16
                        height: 16
                        color: T.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: page.selectedDeck() ? page.selectedDeck().name : "选择词库"
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Chevron {
                        color: T.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                id: rangePill
                implicitHeight: 40
                implicitWidth: rangeLabel.implicitWidth + 30
                radius: 10
                color: T.white
                border.width: 1
                border.color: T.line
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.openRangePicker() }

                Row {
                    id: rangeLabel
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "范围"
                        color: T.inkSoft
                        font.family: T.fontCN
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: page.scopeName()
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Chevron {
                        color: T.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: false

            ModeCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
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
                Layout.preferredHeight: 96
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
                Layout.preferredHeight: 96
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
            id: questionCard
            readonly property bool activeSession: backend.hasSession && !backend.sessionComplete
            Layout.fillWidth: true
            Layout.preferredHeight: activeSession ? Math.max(600, practiceScroll.height - 24)
                                                   : (backend.hasSession ? 620 : Math.max(320, practiceScroll.height - 190))
            radius: activeSession ? 0 : 12
            color: activeSession ? T.canvas : T.white
            border.width: activeSession ? 0 : 1
            border.color: T.line
            clip: true

            // ---------------------------------------------------------
            // Empty state
            // ---------------------------------------------------------
            Column {
                anchors.centerIn: parent
                spacing: 14
                visible: !backend.hasSession && !backend.sessionComplete

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
                    text: "词书和练习方式已就绪，直接开始即可。"
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 14
                }
                Item { width: 1; height: 6 }
                AppButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "开始今日计划"
                    shortcut: "Ctrl+Enter"
                    primary: true
                    onClicked: backend.startPlan("today")
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
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "答错的词已自动加入生词本"
                    color: T.faint
                    font.family: T.fontCN
                    font.pixelSize: 10
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    color: "transparent"
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        spacing: 8

                        Text {
                            text: backend.selectedDeckName || "今日计划"
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.maximumWidth: 180
                        }
                        Rectangle { width: 1; height: 18; color: T.line }
                        TextButton {
                            text: backend.sessionChapter >= 0
                                  ? "第 " + String(backend.sessionChapter + 1) + " 章" : ""
                            visible: backend.sessionChapter >= 0
                            onClicked: chapterPicker.open()
                        }
                        OccurrenceBadge {
                            occurrence: backend.currentOccurrence
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "QUESTION " + String(backend.queuePosition || 0) + " / " + String(backend.queueTotal || 0)
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 10
                            font.letterSpacing: 1.4
                        }

                        AccentBar {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 5
                            value: Number(backend.queueTotal || 0) > 0
                                   ? Number(backend.queuePosition || 0) / Number(backend.queueTotal)
                                   : 0
                        }

                        TextButton {
                            text: backend.loopSession ? "循环中" : "循环"
                            contentColor: backend.loopSession ? T.ink : T.muted
                            onClicked: backend.toggleLoop()
                        }
                        TextButton {
                            text: backend.voiceAccent === "uk" ? "英音" : "美音"
                            onClicked: backend.setVoiceAccent(backend.voiceAccent === "uk" ? "us" : "uk")
                        }
                        TextButton {
                            text: "发音"
                            onClicked: backend.speak(page.currentWord)
                        }
                        TextButton {
                            text: backend.currentMode === "dictation" ? "切回拼写" : "默写"
                            visible: backend.currentMode !== "choice"
                            onClicked: backend.setMode(backend.currentMode === "dictation" ? "spelling" : "dictation")
                        }
                        Text {
                            visible: backend.currentMode === "choice"
                            text: "选择释义"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 11
                        }
                        TextButton {
                            text: "跳过"
                            shortcut: "Alt+S"
                            visible: !backend.retrying && !page.hasRetryResult
                            onClicked: backend.skip()
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
                            text: "下一题"
                            shortcut: "Enter"
                            visible: backend.result !== null && backend.result !== undefined
                                     && backend.result.revealed === true
                            onClicked: backend.next()
                        }
                        TextButton {
                            text: page.notebookContainsCurrent() ? "✓ 已收录" : "生词"
                            shortcut: "Ctrl+D"
                            contentColor: page.notebookContainsCurrent() ? T.green : T.ink
                            onClicked: {
                                backend.toggleNotebook()
                                page.focusAnswer()
                            }
                        }
                        TextButton {
                            text: "×"
                            shortcut: "Esc"
                            visible: backend.hasSession
                            onClicked: backend.exitPractice()
                        }
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
                                text: backend.retryWrong ? "再试一次"
                                      : (String(backend.revealRetryHint || "").length > 0
                                         ? "照着答案重新拼写一次" : "重新默写一次")
                                color: backend.retryWrong ? T.red : T.ink
                                font.family: T.fontCN
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: String(backend.revealRetryHint || "").length > 0
                                text: "正确拼写  " + String(backend.revealRetryHint || "")
                                color: T.inkSoft
                                font.family: T.fontCN
                                font.pixelSize: 14
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
                                        readonly property bool revealedResult: backend.result !== null
                                                                            && backend.result !== undefined
                                                                            && backend.result.revealed === true
                                        readonly property var answerMark: (backend.result && backend.result.answerMarks
                                                                           && slotNumber < backend.result.answerMarks.length)
                                                                          ? backend.result.answerMarks[slotNumber] : null
                                        readonly property bool wrongLetter: answerMark !== null
                                                                            && answerMark.wrong === true
                                        readonly property bool wrongResult: backend.result !== null
                                                                            && backend.result !== undefined
                                                                            && backend.result.correct === false
                                                                            && backend.result.skipped !== true
                                                                            && !revealedResult
                                        readonly property bool slotWrong: wrongResult && isLetter
                                                                         && (slotNumber >= typed.length
                                                                             || typed.charAt(slotNumber).toLowerCase() !== ch.toLowerCase())
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
                                            visible: parent.slotWrong
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: practiceDash.top
                                            anchors.bottomMargin: 4
                                            width: parent.width
                                            height: 40
                                            radius: 7
                                            color: T.mistakePale
                                            opacity: 0.82
                                        }

                                        Text {
                                            anchors.bottom: practiceDash.top
                                            anchors.bottomMargin: 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: parent.isLetter
                                                  ? (parent.revealedResult ? parent.ch
                                                     : (parent.slotNumber < parent.typed.length
                                                        ? parent.typed.charAt(parent.slotNumber) : ""))
                                                  : ""
                                            color: parent.revealedResult ? T.rose
                                                   : (backend.result
                                                      ? (backend.result.correct ? T.green
                                                         : (wrongLetter ? T.mistakeInk : T.muted))
                                                      : T.ink)
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
                            visible: backend.retrying && String(backend.revealRetryHint || "").length === 0
                            text: "忘记了"
                            shortcut: backend.forgotShortcut
                            focusPolicy: Qt.NoFocus
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
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    color: "transparent"
                    border.width: 0

                    Row {
                        id: statsRow
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2

                        Repeater {
                            model: [
                                { label: "输入数", value: String(backend.sessionTyped) },
                                { label: "WPM", value: String(backend.sessionWpm) },
                                { label: "正确数", value: String(backend.sessionRight) },
                                { label: "正确率", value: String(backend.sessionAccuracy) + "%" }
                            ]
                            delegate: Item {
                                width: statsRow.width / 4
                                height: statsRow.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: String(modelData.value)
                                        color: T.ink
                                        font.family: T.fontEN
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: String(modelData.label)
                                        color: T.faint
                                        font.family: T.fontCN
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                    }
                }
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
                if (!backend.result.correct && !backend.result.skipped && !backend.result.revealed)
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
        id: rangePicker
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
            width: rangePicker.availableWidth

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
                    color: optionHover.hovered ? T.neutralPale : "transparent"
                    HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            backend.setStudyScope(modelData.value)
                            rangePicker.close()
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

    Popup {
        id: chapterPicker
        parent: page
        width: Math.min(460, page.width - 48)
        height: Math.min(430, page.height - 80)
        x: (page.width - width) / 2
        y: 92
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: T.white
            border.width: 1
            border.color: T.lineStrong
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "章节切换"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 15
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                TextButton {
                    text: "关闭"
                    onClicked: chapterPicker.close()
                }
            }

            GridView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 100
                cellHeight: 54
                model: backend.chapterRows || []
                ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: 94
                    height: 48
                    radius: 8
                    color: modelData.current ? T.neutralPale : T.white
                    border.width: 1
                    border.color: modelData.current ? T.ink : T.line
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.startChapter(Number(modelData.index))
                            chapterPicker.close()
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(modelData.label)
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 11
                            font.bold: modelData.current
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.status === "done" ? "已完成"
                                  : (modelData.status === "active" ? "学习中" : "未开始")
                            color: modelData.status === "done" ? T.green : T.faint
                            font.family: T.fontCN
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deckPicker
        objectName: "deckPicker"
        parent: page
        width: 340
        height: Math.min(390, 52 + Math.max(1, (backend.decks || []).length) * 46)
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
