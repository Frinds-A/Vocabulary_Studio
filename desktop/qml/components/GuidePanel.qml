import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as T

Item {
    id: guide
    property int current: 0
    readonly property var chapters: ["开始使用", "三种练习", "章节与生词本", "复习与统计", "快捷键", "发音与音效", "数据与更新"]

    function open(index) {
        guide.current = Math.max(0, Math.min(guide.chapters.length - 1, index))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 4
        anchors.bottomMargin: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "使用说明"
                color: T.ink
                font.family: T.fontCN
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "按章节查看 · 点击上方索引切换"
                color: T.faint
                font.family: T.fontCN
                font.pixelSize: 11
            }
        }

        Row {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: guide.chapters
                delegate: Rectangle {
                    width: chapterLabel.implicitWidth + 20
                    height: 28
                    radius: 6
                    color: guide.current === index ? T.neutralPale : "transparent"
                    border.width: guide.current === index ? 1 : 0
                    border.color: T.lineStrong
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: guide.current = index }
                    Text {
                        id: chapterLabel
                        anchors.centerIn: parent
                        text: String(modelData)
                        color: guide.current === index ? T.ink : T.muted
                        font.family: T.fontCN
                        font.pixelSize: 10
                        font.bold: guide.current === index
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: T.line
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: body
                width: parent.width - 12
                spacing: 10

                // 1. 开始使用
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 0
                    Text { text: "从一本词书开始"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "词序内置 48 本词书、130,699 条词汇，按考研、出国考试、国内考试、通用词汇、专业英语、人工智能分类。在「我的词库」中可按分类筛选、搜索名称，词书左上角的星标用于收藏。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "从首页点「开始学习」，先选一本词书，再进入词书页选择章节，点「学习本章」进入拼写；点「继续学习」直接回到上次进度。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "每章默认 20 词，可以在设置里改成 10、20、30 或 50 词。首页可选择「范围」，再进入词书选章节。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "学习记录保存在本机，不需要账号，也不会上传。第一次打开会自动显示公告；在设置里可以重新查看本说明。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                }

                // 2. 三种练习
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 1
                    Text { text: "三种练习怎么选"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "拼写：看中文写英文，最扎实，适合第一次学新词。选择题：看英文选中文释义，适合词组和快速复习。听音拼写：听发音写单词，适合练辨音和复习已经见过的词。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "每个词在一轮里会过两遍；拼错后先在原地重写，再在后续再次出现。重写不会计入正确次数，也不会降低掌握度。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "若无法回忆，可按 Alt+K 或使用「提示」查看首字母；仍无法作答时，可显示答案并重新拼写。显示答案后建议再写一遍，而不是直接进入下一题。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "练习页顶部可以快速切换「默写 / 拼写」、美音 / 英音，也可以开启「单词循环」。完成页会显示本轮正确率、WPM 和用时。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                }

                // 3. 章节与生词本
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 2
                    Text { text: "章节与生词本"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "每章是一小段学习任务。完成一章后可以点「下一章」继续，或点「默写本章」把这一章的单词再听写一遍。章节大小在「设置 → 通用 → 章节练习」中调整。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "答错的词会自动加入生词本，方便之后集中复习；生词本中的词可以随时移除或重新学习。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "生词本是手动收藏的词；「熟词」是累计答对 2 次的词，也可以把熟词重新标为生词。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "学习范围在首页右上角选择；开启「单词循环」后，本轮结束后会自动从本轮第一个词重新开始。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                }

                // 4. 复习与统计
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 3
                    Text { text: "复习节奏与统计"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "到期复习按 1、2、4、7、15、30 天安排。每天先清掉「待复习」，再学新词。统计页可以看到本周学习、综合正确率和各词库掌握度。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "一个词累计答对 2 次才算「已掌握」；「连续学习」按有学习记录的连续天数计算。建议每次 15–30 分钟，比一次背很多更容易坚持。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                }

                // 5. 快捷键
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: guide.current === 4
                    Text { text: "常用快捷键"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Repeater {
                        model: [
                            ["Esc", "返回上一页 / 退出全屏"],
                            ["← / →", "上一词 / 下一词"],
                            ["Enter", "判定 / 下一题"],
                            ["F11", "进入 / 退出全屏专注"],
                            ["Alt + K", "提示第一个字母"],
                            ["Alt + A", "显示答案"],
                            ["Alt + R", "重新拼写"],
                            ["Alt + S", "跳过"],
                            ["Ctrl + 1 / 2 / 3", "选择题中切换模式"],
                            ["1 / 2 / 3", "切换模式"],
                            ["1–4", "选择题 A–D"],
                            ["Ctrl + K", "更换词库"],
                            ["Ctrl + Enter", "开始 / 继续学习"],
                            ["Ctrl + H/L/P/B/T/,", "切换页面"],
                            ["Ctrl + R", "朗读当前单词"],
                            ["Ctrl + D", "收藏到生词本"]
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            Rectangle {
                                Layout.preferredWidth: 142
                                Layout.fillHeight: true
                                radius: 6
                                color: T.neutralPale
                                Text { anchors.centerIn: parent; text: String(modelData[0]); color: T.inkSoft; font.family: T.fontEN; font.pixelSize: 11 }
                            }
                            Text { Layout.fillWidth: true; text: String(modelData[1]); color: T.muted; font.family: T.fontCN; font.pixelSize: 12 }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "鼠标悬停在按钮上也会显示对应快捷键。"; color: T.faint; font.family: T.fontCN; font.pixelSize: 11 }
                }

                // 6. 发音与音效
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 5
                    Text { text: "发音、语速与输入音效"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "在「设置 → 通用 → 发音口音」中切换美式 / 英式。系统缺少对应口音时，会自动使用可用的英语语音；安装英语（英国）语音后重启软件即可。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "发音语速有慢、正常、快三档；输入音效可以在设置中关闭。答错和完成时也会自动播放当前单词。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                }

                // 7. 数据与更新
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: guide.current === 6
                    Text { text: "数据、备份与更新"; color: T.ink; font.family: T.fontCN; font.pixelSize: 15; font.bold: true }
                    Text { Layout.fillWidth: true; text: "学习记录默认保存在本机：%LOCALAPPDATA%\\词序桌面版\\state.json。开启自动备份后，每天会在同目录的 backups 文件夹保留一份快照，最多 7 份。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "「设置 → 数据」可以导入单词书、导出/导入备份、一键格式化。格式化会清除全部学习进度、生词、统计和时间，但保留词书、目标和设置，操作不可恢复。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "软件启动后会自动检查新版本；检查和下载需要联网，学习和发音不需要。更新会在软件内完成，不需要打开 GitHub。"; color: T.muted; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.55 }
                    Text { Layout.fillWidth: true; text: "源码：https://github.com/Frinds-A/Vocabulary_Studio"; color: T.accent; font.family: T.fontEN; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://github.com/Frinds-A/Vocabulary_Studio") } }
                    Text { Layout.fillWidth: true; text: "如果它帮你多记住了一个词，欢迎点一颗 Star 喵！QAQ"; color: T.inkSoft; font.family: T.fontCN; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
