import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: dialog
    signal closed()

    anchors.fill: parent
    visible: false
    z: 320

    readonly property bool hasNotes: updater.state === "available"
    readonly property bool busy: updater.state === "downloading"
                                || updater.state === "ready"
                                || updater.state === "installing"

    Shortcut {
        sequence: "Escape"
        enabled: dialog.visible && updater.state !== "installing" && !dialog.busy
        onActivated: dialog.closed()
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width - 72, 500)
        height: Math.min(parent.height - 80, dialog.hasNotes ? 500 : (dialog.busy ? 300 : 230))
        anchors.centerIn: parent
        radius: 14
        color: T.white
        border.width: 1
        border.color: T.lineStrong
        antialiasing: true
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.topMargin: 24
            anchors.bottomMargin: 22
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    Layout.fillWidth: true
                    text: updater.state === "latest" ? "已是最新版本"
                          : (updater.state === "checking" ? "正在检查更新" : "发现新版本")
                    color: T.ink
                    font.family: T.fontCN
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    visible: updater.latestVersion.length > 0
                    text: "当前 v" + updater.currentVersion + "  →  最新 v" + updater.latestVersion
                    color: T.muted
                    font.family: T.fontCN
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.line
            }

            Text {
                Layout.fillWidth: true
                visible: updater.state !== "latest"
                text: updater.statusText
                color: updater.state === "error" ? T.red : T.inkSoft
                font.family: T.fontCN
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dialog.hasNotes ? 170 : 0
                visible: dialog.hasNotes
                radius: 9
                color: T.neutralPale
                border.width: 1
                border.color: T.line

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    contentWidth: width
                    contentHeight: notes.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

                    Text {
                        id: notes
                        width: parent.width
                        text: updater.releaseNotes.length > 0
                              ? updater.releaseNotes
                              : "本次更新包含问题修复与体验改进。"
                        color: T.inkSoft
                        font.family: T.fontCN
                        font.pixelSize: 12
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                        textFormat: Text.MarkdownText
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: dialog.busy
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: T.neutralPale
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, updater.progress)) / 100
                        height: parent.height
                        radius: 3
                        color: T.ink
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    text: String(Math.max(0, Math.min(100, updater.progress))) + "%"
                    color: T.muted
                    font.family: T.fontEN
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                TextButton {
                    text: "稍后"
                    shortcut: "Esc"
                    visible: updater.state === "available"
                    onClicked: dialog.closed()
                }

                AppButton {
                    text: updater.state === "downloading" ? "正在下载…"
                          : (updater.state === "ready" || updater.state === "installing" ? "正在安装…" : "下载并安装")
                    shortcut: "Enter"
                    primary: true
                    visible: dialog.hasNotes || dialog.busy
                    enabled: updater.state === "available" && updater.available
                    onClicked: updater.downloadAndInstall()
                }

                AppButton {
                    text: "关闭"
                    shortcut: "Enter"
                    primary: true
                    visible: updater.state === "latest" || updater.state === "error"
                             || updater.state === "checking"
                    onClicked: dialog.closed()
                }
            }
        }
    }
}
