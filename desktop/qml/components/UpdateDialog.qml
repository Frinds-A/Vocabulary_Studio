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

    Shortcut {
        sequence: "Escape"
        enabled: dialog.visible && updater.state !== "installing"
        onActivated: dialog.closed()
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width - 72, 560)
        height: Math.min(parent.height - 72, 548)
        anchors.centerIn: parent
        radius: 16
        color: T.white
        border.width: 1
        border.color: T.lineStrong
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 4
                    Text {
                        text: updater.state === "latest" ? "已是最新版本"
                              : (updater.state === "checking" ? "正在检查更新" : "发现新版本")
                        color: T.ink
                        font.family: T.fontCN
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        visible: updater.latestVersion.length > 0
                        text: "当前 v" + updater.currentVersion + "  →  最新 v" + updater.latestVersion
                        color: T.muted
                        font.family: T.fontCN
                        font.pixelSize: 11
                    }
                }
                Item { Layout.fillWidth: true }
                TextButton {
                    text: "×"
                    shortcut: "Esc"
                    enabled: updater.state !== "installing"
                    onClicked: dialog.closed()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.line
            }

            Text {
                Layout.fillWidth: true
                text: updater.statusText
                color: updater.state === "error" ? T.red : T.inkSoft
                font.family: T.fontCN
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                visible: updater.state === "available" || updater.state === "downloading"
                text: "更新内容"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 140
                visible: updater.state === "available" || updater.state === "downloading"
                radius: 10
                color: T.neutralPale
                border.width: 1
                border.color: T.line

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
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
                        lineHeight: 1.5
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                visible: updater.state === "downloading" || updater.state === "ready"
                         || updater.state === "installing"
                radius: 4
                color: T.neutralPale
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, updater.progress)) / 100
                    height: parent.height
                    radius: 4
                    color: T.ink
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Item { Layout.fillWidth: true }
                TextButton {
                    text: updater.state === "installing" ? "正在安装…" : "稍后"
                    shortcut: "Esc"
                    enabled: updater.state !== "installing" && updater.state !== "downloading"
                    onClicked: dialog.closed()
                }
                AppButton {
                    text: updater.state === "downloading" ? "正在下载…"
                          : (updater.state === "ready" || updater.state === "installing" ? "正在安装…" : "下载并安装")
                    shortcut: "Enter"
                    primary: true
                    enabled: updater.state === "available" && updater.available
                    visible: updater.state === "available" || updater.state === "downloading"
                             || updater.state === "ready" || updater.state === "installing"
                    onClicked: updater.downloadAndInstall()
                }
                AppButton {
                    text: "关闭"
                    shortcut: "Enter"
                    primary: true
                    visible: updater.state === "latest" || updater.state === "error"
                    onClicked: dialog.closed()
                }
            }
        }
    }
}
