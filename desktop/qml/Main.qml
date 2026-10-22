import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QtQuick.Dialogs
import "Theme.js" as T
import "pages"
import "components"

ApplicationWindow {
    id: root
    width: 1440
    height: 920
    minimumWidth: 1120
    minimumHeight: 660
    visible: true
    title: "词序 · Vocabulary Studio"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint
    onClosing: backend.flushStudyTime()
    font.family: T.fontCN
    font.pixelSize: 15

    property bool immersive: false
    property bool settingsOpen: false
    property bool welcomeOpen: false
    property bool updateOpen: false
    readonly property bool modalOpen: root.settingsOpen || root.welcomeOpen || root.updateOpen
    property double lastFocusToggle: 0
    property string toastMessage: ""
    property real promptOpacity: 1
    property real promptScale: 1
    property int visibilityBeforeFullscreen: Window.Windowed

    readonly property var dailyNote: T.dailyQuote(dailyTick)
    property int dailyTick: 0
    property string dailyKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property var currentEntry: backend.current || ({})
    readonly property string currentWord: String(currentEntry.word || "")
    readonly property bool hasResult: backend.result !== null && backend.result !== undefined
    readonly property bool hasRetryResult: backend.retryResult !== null
                                          && backend.retryResult !== undefined
    readonly property bool resultCorrect: hasResult && backend.result.correct
    readonly property bool resultRevealed: hasResult && backend.result.revealed === true
    readonly property bool immersiveSpelling: root.immersive
                                             && backend.page === "practice"
                                             && backend.currentMode === "spelling"
                                             && backend.hasSession
                                             && !backend.sessionComplete
                                             && root.currentWord.length > 0

    function pageNumber() {
        switch (backend.page) {
        case "library": return 1
        case "practice": return 2
        case "notebook": return 3
        case "stats": return 4
        case "settings": return 5
        case "deck": return 6
        default: return 0
        }
    }

    function pageTitle() {
        switch (backend.page) {
        case "library": return "我的词库"
        case "deck": return backend.deckName || "词库详情"
        case "practice": return "专注练习"
        case "notebook": return "生词本"
        case "stats": return "学习轨迹"
        case "settings": return "偏好设置"
        default: return "今日计划"
        }
    }

    function pageSubtitle() {
        switch (backend.page) {
        case "library": return "选择一本词书，按自己的节奏学习。"
        case "deck": return String(backend.deckCount || 0) + " 个词条 · "
                           + String(backend.chapterCount || 0) + " 章"
        case "practice": return "一次一个词，慢慢来。"
        case "notebook": return "想记的词，都在这里。"
        case "stats": return "每天一点点，积累成线。"
        case "settings": return "目标可以调整，节奏由你决定。"
        default: return "先复习，再学新词。"
        }
    }

    function toggleMaximize() {
        if (visibility === Window.Maximized)
            showNormal()
        else
            showMaximized()
    }

    function toggleFullscreen() {
        if (visibility === Window.FullScreen) {
            if (visibilityBeforeFullscreen === Window.Maximized)
                showMaximized()
            else
                showNormal()
        } else {
            visibilityBeforeFullscreen = visibility
            showFullScreen()
        }
    }

    function toggleFocusFullscreen() {
        var now = Date.now()
        if (now - root.lastFocusToggle < 250)
            return
        root.lastFocusToggle = now
        backend.validateCurrentResult()
        if (visibility === Window.FullScreen) {
            root.immersive = false
            root.toggleFullscreen()
            return
        }
        if (backend.page === "practice" && !backend.hasSession)
            backend.startPlan("today")
        if (backend.page === "practice" && backend.hasSession) {
            root.immersive = true
            root.lastImmersiveId = String(root.currentEntry.id || "")
            root.promptOpacity = 0.25
            root.promptScale = 0.975
            promptEntrance.restart()
        }
        root.toggleFullscreen()
    }

    function exitStudy() {
        if (root.immersive)
            root.immersive = false
        if (visibility === Window.FullScreen)
            root.toggleFullscreen()
        backend.exitPractice()
    }

    function handleEscapeKey() {
        if (root.welcomeOpen) {
            root.welcomeOpen = false
            return
        }
        if (root.settingsOpen) {
            root.settingsOpen = false
            return
        }
        if (root.immersive) {
            root.immersive = false
            if (visibility === Window.FullScreen)
                root.toggleFullscreen()
            return
        }
        if (visibility === Window.FullScreen) {
            root.toggleFullscreen()
            return
        }
        if (backend.page === "deck") {
            backend.openPage("library")
            return
        }
        if (backend.page === "practice") {
            backend.exitPractice()
            return
        }
        if (backend.page !== "home")
            backend.openPage("home")
    }

    function handlePreviousWord() {
        if (backend.page === "practice" && backend.hasSession)
            backend.previous()
    }

    function handleNextWord() {
        if (backend.page !== "practice" || !backend.hasSession)
            return
        if (backend.retryResult !== null && backend.retryResult !== undefined)
            backend.next()
        else if (backend.result)
            backend.next()
    }

    function handleChoice(index) {
        if (backend.page !== "practice" || backend.currentMode !== "choice" || backend.result)
            return
        var choices = backend.choices || []
        if (index >= 0 && index < choices.length)
            backend.choose(choices[index].id)
    }

    function openPracticeShortcut() {
        if (backend.hasSession)
            backend.continueStudy()
        else
            backend.openPage("library")
    }

    function speakCurrent() {
        if (backend.current && backend.current.word)
            backend.speak(String(backend.current.word))
    }

    function collectCurrent() {
        if (backend.page === "practice" && backend.hasSession)
            backend.toggleNotebook()
    }

    function openSettings() {
        root.settingsOpen = true
    }

    function openWordbookDialog() {
        wordbookDialog.open()
    }

    function startShortcut() {
        if (backend.page === "deck")
            backend.startStudyChapter(backend.currentChapter)
        else if (backend.hasSession && backend.page !== "practice")
            backend.continueStudy()
        else
            backend.openPage("library")
    }

    function openExportBackupDialog() {
        exportBackupDialog.open()
    }

    function openImportBackupDialog() {
        importBackupDialog.open()
    }

    FileDialog {
        id: wordbookDialog
        title: "导入单词书"
        nameFilters: [
            "单词书 (*.pdf *.docx *.csv *.tsv *.txt *.json)",
            "所有文件 (*.*)"
        ]
        onAccepted: backend.importWordbookPath(selectedFile.toString())
    }

    FileDialog {
        id: exportBackupDialog
        title: "导出学习备份"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: ["JSON 备份 (*.json)"]
        onAccepted: backend.exportBackupPath(selectedFile.toString())
    }

    FileDialog {
        id: importBackupDialog
        title: "导入学习备份"
        nameFilters: ["JSON 备份 (*.json)"]
        onAccepted: backend.importBackupPath(selectedFile.toString())
    }

    Shortcut { sequence: "Escape"; onActivated: root.handleEscapeKey() }
    Shortcut { sequence: "Ctrl+M"; enabled: !root.modalOpen; onActivated: root.showMinimized() }
    Shortcut { sequence: "Ctrl+Shift+M"; enabled: !root.modalOpen; onActivated: root.toggleMaximize() }
    Shortcut {
        sequence: "1"
        enabled: backend.page === "practice" && backend.hasSession && backend.currentMode === "choice" && !backend.result && !root.modalOpen
        onActivated: root.handleChoice(0)
    }
    Shortcut {
        sequence: "2"
        enabled: backend.page === "practice" && backend.hasSession && backend.currentMode === "choice" && !backend.result && !root.modalOpen
        onActivated: root.handleChoice(1)
    }
    Shortcut {
        sequence: "3"
        enabled: backend.page === "practice" && backend.hasSession && backend.currentMode === "choice" && !backend.result && !root.modalOpen
        onActivated: root.handleChoice(2)
    }
    Shortcut {
        sequence: "4"
        enabled: backend.page === "practice" && backend.hasSession && backend.currentMode === "choice" && !backend.result && !root.modalOpen
        onActivated: root.handleChoice(3)
    }
    Shortcut {
        sequence: "Ctrl+1"
        enabled: !root.modalOpen && backend.page === "home"
        onActivated: backend.setMode("spelling")
    }
    Shortcut {
        sequence: "Ctrl+2"
        enabled: !root.modalOpen && backend.page === "home"
        onActivated: backend.setMode("choice")
    }
    Shortcut {
        sequence: "Ctrl+3"
        enabled: !root.modalOpen && backend.page === "home"
        onActivated: backend.setMode("dictation")
    }
    Shortcut { sequence: "Ctrl+H"; enabled: !root.modalOpen; onActivated: backend.openPage("home") }
    Shortcut { sequence: "Ctrl+L"; enabled: !root.modalOpen; onActivated: backend.openPage("library") }
    Shortcut { sequence: "Ctrl+P"; enabled: !root.modalOpen; onActivated: root.openPracticeShortcut() }
    Shortcut { sequence: "Ctrl+B"; enabled: !root.modalOpen; onActivated: backend.openPage("notebook") }
    Shortcut { sequence: "Ctrl+T"; enabled: !root.modalOpen; onActivated: backend.openPage("stats") }
    Shortcut { sequence: "Ctrl+,"; enabled: !root.modalOpen; onActivated: root.openSettings() }
    Shortcut { sequence: "Ctrl+R"; enabled: !root.modalOpen; onActivated: root.speakCurrent() }
    Shortcut {
        sequence: "Ctrl+D"
        enabled: backend.page === "practice" && !root.modalOpen
        onActivated: root.collectCurrent()
    }

    function pageCode() {
        switch (backend.page) {
        case "library": return "LIBRARY"
        case "deck": return "LEXICON"
        case "practice": return "PRACTICE"
        case "notebook": return "NOTEBOOK"
        case "stats": return "INSIGHTS"
        case "settings": return "SETTINGS"
        default: return "TODAY"
        }
    }

    function selectedDeckName() {
        var decks = backend.decks || []
        for (var i = 0; i < decks.length; ++i)
            if (decks[i].id === backend.selectedDeckId)
                return String(decks[i].name || "")
        return "未选择词库"
    }

    function enterCurrentPage() {
        if (backend.page === "practice" && !backend.hasSession) {
            backend.openPage("library")
            return
        }
        var current = pages.children[pages.currentIndex]
        if (current && current.enter)
            current.enter()
    }

    function handlePracticeEnter() {
        if (backend.page !== "practice" || !backend.hasSession || root.immersiveSpelling
                || backend.currentMode === "choice")
            return false
        if (practicePage.answerFocused || practicePage.inputHandledEnter)
            return false
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
        return true
    }

    function handleImmersiveEnter() {
        if (!root.immersiveSpelling)
            return
        if (backend.retryResult !== null && backend.retryResult !== undefined)
            root.advanceImmersive()
        else if (backend.retrying)
            backend.submitRetry()
        else if (backend.result) {
            if (!backend.result.correct && !backend.result.skipped && !backend.result.revealed) {
                backend.startRetry()
                Qt.callLater(function() { answerInputImmersive.forceActiveFocus() })
            } else {
                root.advanceImmersive()
            }
        } else {
            backend.submit()
        }
    }

    function advanceImmersive() {
        backend.next()
        Qt.callLater(function() {
            if (root.immersiveSpelling)
                answerInputImmersive.forceActiveFocus()
        })
    }

    function notebookContainsCurrent() {
        var list = backend.notebook || []
        for (var i = 0; i < list.length; ++i)
            if (list[i].id === root.currentEntry.id)
                return true
        return false
    }

    SequentialAnimation {
        id: promptEntrance
        NumberAnimation { target: root; property: "promptOpacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "promptScale"; to: 1; duration: 380; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: pageIn
        NumberAnimation { target: pages; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageShift; property: "y"; to: 0; duration: 240; easing.type: Easing.OutCubic }
    }

    Connections {
        target: backend
        function onAnswerChanged() {
            if (answerInputImmersive && answerInputImmersive.text !== String(backend.answer || ""))
                answerInputImmersive.text = String(backend.answer || "")
        }
        function onStateChanged() {
            if (root.immersiveSpelling)
                root.syncImmersivePrompt()
        }
        function onStatusMessageChanged() {
            root.toastMessage = backend.statusMessage || ""
            if (root.toastMessage.length)
                toastTimer.restart()
        }
    }

    property string lastImmersiveId: ""

    function syncImmersivePrompt() {
        var id = String(root.currentEntry.id || "")
        if (id !== root.lastImmersiveId) {
            root.lastImmersiveId = id
            if (root.immersiveSpelling) {
                root.promptOpacity = 0.25
                root.promptScale = 0.975
                promptEntrance.restart()
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 3400
        onTriggered: root.toastMessage = ""
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            var key = Qt.formatDate(new Date(), "yyyy-MM-dd")
            if (key !== root.dailyKey) {
                root.dailyKey = key
                root.dailyTick++
            }
        }
    }

    Timer {
        interval: 1000
        running: backend.page === "practice" && backend.hasSession && !backend.sessionComplete
        repeat: true
        onTriggered: backend.addStudyTime(1)
    }

    onCurrentWordChanged: {
        if (root.immersiveSpelling)
            root.syncImmersivePrompt()
    }

    Component.onCompleted: {
        root.width = Math.min(1440, Math.max(root.minimumWidth, Screen.desktopAvailableWidth - 60))
        root.height = Math.min(920, Math.max(root.minimumHeight, Screen.desktopAvailableHeight - 40))
        root.enterCurrentPage()
        root.welcomeOpen = backend.welcomePending
    }

    // -----------------------------------------------------------------
    // Background
    // -----------------------------------------------------------------
    Item {
        id: appSurface
        anchors.fill: parent
        clip: true
        layer.enabled: root.visibility === Window.Windowed
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundMask
        }

        Keys.onReturnPressed: function(event) {
            if (root.handlePracticeEnter())
                event.accepted = true
        }
        Keys.onEnterPressed: function(event) {
            if (root.handlePracticeEnter())
                event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            color: T.white
        }

        // -------------------------------------------------------------
        // Title bar
        // -------------------------------------------------------------
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 42
            color: T.white

            MouseArea {
                anchors.fill: parent
                z: 0
                onPressed: if (root.visibility === Window.Windowed) root.startSystemMove()
                onDoubleClicked: {
                    if (root.visibility === Window.Maximized)
                        root.showNormal()
                    else
                        root.showMaximized()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 6
                spacing: 9
                z: 1

                Rectangle {
                    width: 22
                    height: 22
                    radius: 6
                    color: T.accent
                    Text {
                        anchors.centerIn: parent
                        text: "词"
                        color: T.white
                        font.family: T.fontCN
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
                Text {
                    text: "词序"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "VOCABULARY STUDIO"
                    color: T.faint
                    font.family: T.fontEN
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }
                Item { Layout.fillWidth: true }

                WindowButton {
                    kind: "minimize"
                    shortcut: "Ctrl+M"
                    onClicked: root.showMinimized()
                }
                WindowButton {
                    kind: root.visibility === Window.Maximized ? "restore" : "maximize"
                    shortcut: "Ctrl+Shift+M"
                    onClicked: root.toggleMaximize()
                }
                WindowButton {
                    kind: "close"
                    danger: true
                    shortcut: "Alt+F4"
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: T.line
            }
        }

        Rectangle {
            id: updateBanner
            property bool dismissed: false
            visible: updater.available && !root.updateOpen && !root.welcomeOpen && !dismissed
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 24
            anchors.bottomMargin: 24
            width: updateRow.implicitWidth + 26
            height: 44
            radius: 22
            color: T.ink
            z: 55
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#22000000"
                shadowBlur: 0.4
                shadowVerticalOffset: 4
                blurMax: 18
            }

            Row {
                id: updateRow
                anchors.centerIn: parent
                spacing: 10
                z: 1
                Text {
                    text: "发现新版本 v" + updater.latestVersion
                    color: T.white
                    font.family: T.fontCN
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: "#55FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "查看更新"
                    color: T.white
                    font.family: T.fontCN
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "×"
                    color: "#AAFFFFFF"
                    font.family: T.fontEN
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: updateBanner.dismissed = true
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 22
                cursorShape: Qt.PointingHandCursor
                onClicked: root.updateOpen = true
            }
        }

        // -------------------------------------------------------------
        // Shell
        // -------------------------------------------------------------
        RowLayout {
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 0

            // ---------------------------------------------------------
            // Sidebar
            // ---------------------------------------------------------
            Rectangle {
                Layout.preferredWidth: 264
                Layout.fillHeight: true
                visible: backend.page !== "practice" || !backend.hasSession
                color: T.sidebar
                border.width: 0

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: T.line
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 22
                    anchors.bottomMargin: 18
                    spacing: 3

                    Item { Layout.preferredHeight: 8 }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.bottomMargin: 9
                        Text {
                            text: "学习空间"
                            color: T.faint
                            font.family: T.fontCN
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "PERSONAL"
                            color: T.faint
                            font.family: T.fontEN
                            font.pixelSize: 8
                            font.letterSpacing: 1.4
                        }
                    }

                    NavButton {
                        label: "今日计划"
                        icon: "home"
                        shortcut: "Ctrl+H"
                        active: backend.page === "home"
                        onClicked: backend.openPage("home")
                    }
                    NavButton {
                        label: "我的词库"
                        icon: "library"
                        shortcut: "Ctrl+L"
                        active: backend.page === "library" || backend.page === "deck"
                        onClicked: backend.openPage("library")
                    }
                    NavButton {
                        label: "生词本"
                        icon: "notebook"
                        shortcut: "Ctrl+B"
                        active: backend.page === "notebook"
                        onClicked: backend.openPage("notebook")
                    }
                    NavButton {
                        label: "学习统计"
                        icon: "stats"
                        shortcut: "Ctrl+T"
                        active: backend.page === "stats"
                        onClicked: backend.openPage("stats")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 132
                        Layout.topMargin: 14
                        visible: root.height >= 840
                        radius: 12
                        color: T.white
                        border.width: 1
                        border.color: T.line

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 7

                            Text {
                                text: "TODAY'S NOTE"
                                color: T.faint
                                font.family: T.fontEN
                                font.pixelSize: 8
                                font.letterSpacing: 1.7
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.dailyNote.en
                                color: T.inkSoft
                                font.family: T.fontEN
                                font.pixelSize: 16
                                font.italic: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.25
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.dailyNote.zh
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        Layout.bottomMargin: 12
                        radius: 12
                        color: T.white
                        border.width: 1
                        border.color: T.line

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Item {
                                width: 54
                                height: 54
                                RingProgress {
                                    anchors.fill: parent
                                    thickness: 6
                                    progress: Number(backend.dailyGoal || 0) > 0
                                              ? Number(backend.todayNew || 0) / Number(backend.dailyGoal)
                                              : 0
                                    color1: T.accent
                                    trackColor: "#F1F3F5"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: String(backend.todayNew || 0)
                                    color: T.ink
                                    font.family: T.fontEN
                                    font.pixelSize: 17
                                    font.bold: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "今日新词"
                                    color: T.ink
                                    font.family: T.fontCN
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: String(backend.todayNew || 0) + " / "
                                          + String(backend.dailyGoal || 20) + " 词"
                                    color: T.muted
                                    font.family: T.fontCN
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: "A LITTLE EVERY DAY"
                                    color: T.faint
                                    font.family: T.fontEN
                                    font.pixelSize: 8
                                    font.letterSpacing: 1.2
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: T.line
                        Layout.topMargin: 12
                        Layout.bottomMargin: 10
                    }

                    NavButton {
                        label: "偏好设置"
                        icon: "settings"
                        shortcut: "Ctrl+,"
                        active: root.settingsOpen
                        onClicked: root.openSettings()
                    }
                }
            }

            // ---------------------------------------------------------
            // Main area
            // ---------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? (backend.page === "deck" ? 92 : 104) : 0
                    visible: !(backend.page === "practice" && backend.hasSession && !backend.sessionComplete)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 40
                        anchors.rightMargin: 40
                        anchors.topMargin: 16
                        anchors.bottomMargin: 12
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                visible: backend.page !== "deck"
                                spacing: 7
                                Text {
                                    text: "LEARNING SPACE"
                                    color: T.faint
                                    font.family: T.fontEN
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.8
                                }
                                Text {
                                    text: "/"
                                    color: T.lineStrong
                                    font.family: T.fontEN
                                    font.pixelSize: 10
                                }
                                Text {
                                    text: root.pageCode()
                                    color: T.violet
                                    font.family: T.fontEN
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.8
                                    font.bold: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.pageTitle()
                                color: T.ink
                                font.family: T.fontCN
                                font.pixelSize: 26
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.pageSubtitle()
                                color: T.muted
                                font.family: T.fontCN
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            spacing: 10
                            TextButton {
                                visible: backend.page === "deck"
                                text: "返回词库"
                                shortcut: "Esc"
                                bordered: false
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: backend.openPage("library")
                            }
                            Rectangle {
                                id: duePill
                                visible: backend.page !== "deck"
                                implicitHeight: 34
                                implicitWidth: 124
                                radius: 9
                                color: T.white
                                border.width: 1
                                border.color: dueHover.hovered ? T.lineStrong : T.line
                                Behavior on border.color { ColorAnimation { duration: 140 } }
                                HoverHandler {
                                    id: dueHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler { onTapped: backend.startReview() }
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Text {
                                        text: "☼"
                                        color: T.accent
                                        font.family: T.fontCN
                                        font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "待复习"
                                        color: T.inkSoft
                                        font.family: T.fontCN
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: T.displayStat(backend.dueCount, 0)
                                        color: T.violet
                                        font.family: T.fontEN
                                        font.pixelSize: 17
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }




                        }
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    StackLayout {
                        id: pages
                        objectName: "pagesStack"
                        anchors.fill: parent
                        currentIndex: root.pageNumber()
                        transform: Translate { id: pageShift; y: 0 }

                        onCurrentIndexChanged: {
                            pages.opacity = 0.35
                            pageShift.y = 10
                            pageIn.restart()
                            if (backend.page !== "practice")
                                root.immersive = false
                            root.enterCurrentPage()
                        }

                        HomePage {
                            id: homePage
                            onStudyWizardRequested: studyWizardDialog.openWizard(deckId)
                        }
                        LibraryPage {
                            id: libraryPage
                            onImportRequested: root.openWordbookDialog()
                        }
                        PracticePage {
                            id: practicePage
                            immersiveMode: root.immersive
                            onRequestImmersive: root.toggleFocusFullscreen()
                            onFocusFullscreenRequested: root.toggleFocusFullscreen()
                            onHintRequested: {
                                backend.hintFirstLetter()
                                practicePage.focusAnswer()
                            }
                        }
                        NotebookPage { id: notebookPage }
                        StatsPage { id: statsPage }
                        SettingsPage {
                            id: settingsPage
                            onImportRequested: root.openWordbookDialog()
                            onExportBackupRequested: root.openExportBackupDialog()
                            onImportBackupRequested: root.openImportBackupDialog()
                        }
                        DeckDetailPage { id: deckDetailPage }
                    }
                }
            }
        }

    StudyWizardDialog {
        id: studyWizardDialog
        parent: root.contentItem
    }


    SettingsDialog {
        id: settingsDialog
        anchors.fill: parent
        visible: root.settingsOpen
        onClosed: root.settingsOpen = false
        onImportRequested: root.openWordbookDialog()
        onExportBackupRequested: root.openExportBackupDialog()
        onImportBackupRequested: root.openImportBackupDialog()
        onFormatted: {
            root.settingsOpen = false
            root.welcomeOpen = true
        }
        onUpdateRequested: root.updateOpen = true
    }

    UpdateDialog {
        anchors.fill: parent
        visible: root.updateOpen
        onClosed: root.updateOpen = false
    }

    WelcomeDialog {
        anchors.fill: parent
        z: 300
        visible: root.welcomeOpen
        onClosed: root.welcomeOpen = false
        onGuideRequested: {
            root.welcomeOpen = false
            root.settingsOpen = true
            settingsDialog.openGuide(0)
        }
    }
    // -----------------------------------------------------------------
    Rectangle {
        id: immersiveLayer
        anchors.fill: parent
        z: 60
        visible: root.immersiveSpelling
        color: T.canvas


        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 26
            spacing: 12

            Rectangle {
                width: 36
                height: 36
                radius: 8
                color: T.accent
                Text {
                    anchors.centerIn: parent
                    text: "词"
                    color: T.white
                    font.family: T.fontCN
                    font.pixelSize: 18
                    font.bold: true
                }
            }
            ColumnLayout {
                spacing: 1
                Text {
                    text: "专注拼写"
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: root.selectedDeckName()
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "QUESTION " + String(backend.queuePosition || 0) + " / " + String(backend.queueTotal || 0)
                color: T.faint
                font.family: T.fontEN
                font.pixelSize: 10
                font.letterSpacing: 1.8
            }

            AccentBar {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 6
                value: Number(backend.queueTotal || 0) > 0
                       ? Number(backend.queuePosition || 0) / Number(backend.queueTotal)
                       : 0
            }

            TextButton {
                text: backend.sessionChapter >= 0
                      ? "第 " + String(backend.sessionChapter + 1) + " 章" : ""
                visible: backend.sessionChapter >= 0
                onClicked: practicePage.openChapterPicker()
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
                onClicked: backend.speak(root.currentWord)
            }
            TextButton {
                text: "默写"
                visible: backend.currentMode === "spelling" && !backend.result && !root.hasRetryResult
                onClicked: backend.setMode("dictation")
            }
            TextButton {
                text: "跳过"
                shortcut: "Alt+S"
                visible: !backend.retrying && !root.hasRetryResult
                onClicked: backend.skip()
            }

            TextButton {
                text: "上一词"
                shortcut: "←"
                visible: backend.canGoPrevious
                onClicked: {
                    backend.previous()
                    Qt.callLater(function() {
                        if (root.immersiveSpelling)
                            answerInputImmersive.forceActiveFocus()
                    })
                }
            }
            TextButton {
                text: "提示"
                shortcut: "Alt+K"
                visible: backend.currentMode === "spelling" && !backend.result && !root.hasRetryResult
                enabled: String(backend.answer || "").length === 0
                onClicked: {
                    backend.hintFirstLetter()
                    Qt.callLater(function() { answerInputImmersive.forceActiveFocus() })
                }
            }
            TextButton {
                text: "忘记了"
                shortcut: "Enter"
                visible: backend.retrying
                onClicked: backend.forgotAnswer()
            }
            TextButton {
                text: "显示答案"
                shortcut: "Alt+A"
                visible: backend.hasSession && !backend.result && !backend.retrying && !root.hasRetryResult
                onClicked: backend.revealAnswer()
            }
            TextButton {
                text: "下一题"
                shortcut: "Enter"
                visible: root.resultRevealed
                onClicked: root.advanceImmersive()
            }
            TextButton {
                text: root.notebookContainsCurrent() ? "✓ 已收录" : "生词"
                shortcut: "Ctrl+D"
                contentColor: root.notebookContainsCurrent() ? T.green : T.ink
                onClicked: {
                    backend.toggleNotebook()
                    Qt.callLater(function() { answerInputImmersive.forceActiveFocus() })
                }
            }
            TextButton {
                text: "×"
                shortcut: "Esc"
                onClicked: root.exitStudy()
            }
        }

        Item {
            id: focusStage
            anchors.centerIn: parent
            width: Math.min(parent.width - 160, 900)
            height: Math.min(parent.height - 180, 540)
            opacity: root.promptOpacity
            scale: root.promptScale

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "SPELLING FOCUS"
                        color: T.violet
                        font.family: T.fontEN
                        font.pixelSize: 10
                        font.letterSpacing: 2.2
                        font.bold: true
                    }
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 3
                        color: T.rose
                    }
                    Text {
                        text: "根据释义，写出完整的英文"
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 12
                    }
                    Item { Layout.fillWidth: true }
                    OccurrenceBadge {
                        occurrence: backend.currentOccurrence
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: String(T.wordLetterCount(root.currentWord)) + " 个字母"
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillHeight: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        Repeater {
                            model: T.senseRows(root.currentEntry)
                            delegate: Text {
                                text: T.posLabel(modelData.pos)
                                color: T.rose
                                font.family: T.fontEN
                                font.pixelSize: 17
                                font.italic: true
                                font.bold: true
                            }
                        }
                    }

                    Repeater {
                        model: T.senseRows(root.currentEntry)
                        delegate: Text {
                            Layout.fillWidth: true
                            text: T.rowMeaning(modelData)
                            color: T.ink
                            font.family: T.fontCN
                            font.pixelSize: 34
                            font.weight: Font.Medium
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: backend.retrying
                    text: backend.retryWrong ? "再试一次" : "重新默写一次"
                    color: backend.retryWrong ? T.red : T.ink
                    font.family: T.fontCN
                    font.pixelSize: 18
                    font.bold: true
                }

                Item {
                    Layout.preferredHeight: 26
                    visible: !root.hasRetryResult
                }

                Row {
                    id: slotRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 9
                    visible: !root.hasRetryResult

                    readonly property int letters: T.wordLetterCount(root.currentWord)
                    readonly property real slotWidth: Math.max(34, Math.min(62,
                        (focusStage.width - 96 - Math.max(0, root.currentWord.length - 1) * 9)
                        / Math.max(1, root.currentWord.length)))

                    Repeater {
                        model: root.currentWord.length
                        delegate: Item {
                            readonly property string character: root.currentWord.charAt(index)
                            readonly property bool isLetter: T.isLetterAt(root.currentWord, index)
                            readonly property int slotNumber: T.slotIndexAt(root.currentWord, index)
                            readonly property string typed: String(backend.answer || "")
                            readonly property var answerMark: (backend.result && backend.result.answerMarks
                                                               && slotNumber < backend.result.answerMarks.length)
                                                              ? backend.result.answerMarks[slotNumber] : null
                            readonly property bool wrongLetter: answerMark !== null
                                                                && answerMark.wrong === true
                            readonly property bool isCurrent: isLetter && !root.hasResult
                                                             && slotNumber === typed.length
                            width: isLetter ? slotRow.slotWidth : (character === " " ? 16 : 20)
                            height: 86

                            Rectangle {
                                id: slotDash
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: parent.isCurrent ? 3 : 2
                                radius: 1.5
                                visible: parent.isLetter
                                color: root.resultRevealed ? T.lineStrong
                                       : (root.hasResult
                                          ? (parent.slotNumber < parent.typed.length
                                             ? (root.resultCorrect ? T.green
                                                : (parent.wrongLetter ? T.mistakeLine : T.lineStrong))
                                             : T.line)
                                          : (parent.isCurrent ? T.accent
                                             : (parent.slotNumber < parent.typed.length ? T.inkSoft : T.lineStrong)))
                            }

                            Rectangle {
                                visible: parent.isLetter && parent.wrongLetter
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: slotDash.top
                                anchors.bottomMargin: 4
                                width: parent.width
                                height: 54
                                radius: 8
                                color: T.mistakePale
                            }

                            Text {
                                anchors.bottom: slotDash.top
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !parent.isLetter && parent.character !== " "
                                text: parent.character
                                color: T.faint
                                font.family: T.fontEN
                                font.pixelSize: 26
                            }

                            Text {
                                anchors.bottom: slotDash.top
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: parent.isLetter
                                         && (root.resultRevealed || parent.slotNumber < parent.typed.length)
                                text: root.resultRevealed ? parent.character
                                                          : (parent.typed.charAt(parent.slotNumber) || "")
                                color: root.resultRevealed ? T.rose
                                       : (root.hasResult
                                          ? (root.resultCorrect ? T.green
                                             : (parent.wrongLetter ? T.mistakeInk : T.muted))
                                          : T.ink)
                                font.family: T.fontEN
                                font.pixelSize: 42
                                font.bold: true
                            }

                            Rectangle {
                                visible: parent.isCurrent
                                width: 2
                                height: 27
                                radius: 1
                                color: T.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: slotDash.top
                                anchors.bottomMargin: 10
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.15; duration: 620; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: 30
                    visible: !root.hasRetryResult
                }

                FeedbackPanel {
                    Layout.fillWidth: true
                    Layout.maximumWidth: backend.result && backend.result.correct ? 560 : 900
                    Layout.alignment: Qt.AlignHCenter
                    onNextRequested: root.advanceImmersive()
                    onRetryRequested: {
                        backend.startRetry()
                        Qt.callLater(function() { answerInputImmersive.forceActiveFocus() })
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 640
                    Layout.fillWidth: true
                    spacing: 10
                    visible: backend.retryResult !== null && backend.retryResult !== undefined

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
                        visible: String(root.currentEntry.example || "").length > 0
                        text: String(root.currentEntry.example || "")
                        color: T.muted
                        font.family: T.fontEN
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.35
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: String(root.currentEntry.exampleZh || "").length > 0
                        text: String(root.currentEntry.exampleZh || "")
                        color: T.faint
                        font.family: T.fontCN
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.35
                    }
                    AppButton {
                        objectName: "retryNextImmersive"
                        Layout.alignment: Qt.AlignHCenter
                        text: "下一题"
                        primary: true
                        implicitHeight: 42
                        implicitWidth: 112
                        fontSize: 13
                        focus: root.hasRetryResult
                        Keys.onReturnPressed: function(event) {
                            root.advanceImmersive()
                            event.accepted = true
                        }
                        Keys.onEnterPressed: function(event) {
                            root.advanceImmersive()
                            event.accepted = true
                        }
                        onClicked: root.advanceImmersive()
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        TextInput {
            id: answerInputImmersive
            objectName: "answerInputImmersive"
            width: 2
            height: 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            opacity: 0.01
            color: "transparent"
            selectionColor: "transparent"
            cursorVisible: false
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhLatinOnly
            validator: RegularExpressionValidator {
                regularExpression: /[A-Za-zÀ-ÿ .,'’()?…\/-]*/
            }
            maximumLength: root.currentWord.length
            text: backend.answer || ""
            onTextEdited: {
                backend.playInputSound()
                backend.setAnswer(text)
            }
            onAccepted: root.handleImmersiveEnter()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_F11) {
                    root.toggleFocusFullscreen()
                    event.accepted = true
                } else if (event.key === Qt.Key_K && (event.modifiers & Qt.AltModifier)) {
                    backend.hintFirstLetter()
                    answerInputImmersive.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_A && (event.modifiers & Qt.AltModifier)) {
                    backend.revealAnswer()
                    event.accepted = true
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.AltModifier)) {
                    backend.startRetry()
                    answerInputImmersive.forceActiveFocus()
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
                        root.advanceImmersive()
                }
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                if (backend.result)
                    root.advanceImmersive()
                else
                    answerInputImmersive.forceActiveFocus()
            }
        }

        onVisibleChanged: {
            if (visible) {
                root.lastImmersiveId = String(root.currentEntry.id || "")
                root.promptOpacity = 0.25
                root.promptScale = 0.975
                promptEntrance.restart()
                Qt.callLater(function() { answerInputImmersive.forceActiveFocus() })
            }
        }
    }

    // -----------------------------------------------------------------
    // Toast
    // -----------------------------------------------------------------
    Rectangle {
        id: toast
        z: 120
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 + (1 - opacity) * 10
        width: Math.min(parent.width - 80, Math.max(240, toastText.implicitWidth + 64))
        height: 46
        radius: 23
        color: T.ink
        opacity: root.toastMessage.length > 0 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: T.white
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: toastText
                text: root.toastMessage
                color: "#FFFFFF"
                font.family: T.fontCN
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // -----------------------------------------------------------------
    // Window resize grips
    // -----------------------------------------------------------------
    MouseArea {
        visible: root.visibility === Window.Windowed && !root.immersiveSpelling
        z: 90
        width: 6
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.LeftEdge)
    }
    MouseArea {
        visible: root.visibility === Window.Windowed && !root.immersiveSpelling
        z: 90
        width: 6
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.RightEdge)
    }
    MouseArea {
        visible: root.visibility === Window.Windowed && !root.immersiveSpelling
        z: 90
        height: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        cursorShape: Qt.SizeVerCursor
        onPressed: root.startSystemResize(Qt.TopEdge)
    }
    MouseArea {
        visible: root.visibility === Window.Windowed && !root.immersiveSpelling
        z: 90
        height: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeVerCursor
        onPressed: root.startSystemResize(Qt.BottomEdge)
    }

    Rectangle {
        id: roundMask
        anchors.fill: parent
        radius: root.visibility === Window.Windowed ? 12 : 0
        color: T.white
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.visibility === Window.Windowed ? 11 : 0
        color: "transparent"
        border.width: 1
        border.color: T.lineStrong
        antialiasing: true
        z: 95
    }
}
}

