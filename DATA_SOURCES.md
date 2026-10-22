# 词库来源与许可说明

应用在本地读取内置的 `desktop/data/vocabulary.json`，并把它打包进 `词序.exe`。练习时不调用在线翻译服务，也不需要联网。

## 数据范围

| 集合 | 数量 | 内容 |
| --- | ---: | --- |
| `cet46Phrases` | 2,023 | 刘晓艳老师版四六级常用词组 PDF |
| `cet4Outline` | 4,424 | 烤鸭TV《大学英语四级词汇-乱序版》答案页，去重后 4,424 条 |
| `cet6Words` | 2,178 | 刘晓艳老师版六级核心词表 |
| `cet6Outline` | 5,523 | 刘晓艳老师版《大学英语六级词汇-乱序版》答案页 |
| `kaoyaCET4` | 1,491 | 烤鸭TV Zoey 老师四级核心词 14 天冲刺打卡表 |
| `kaoyaCET6` | 1,500 | 烤鸭TV Zoey 老师六级核心词 14 天冲刺打卡表 |
| `postgradWords` | 3,728 | GPT 搜集整理的考研核心词 |
| `postgradPhrases` | 1,200 | GPT 搜集整理的考研常用词组 |

| `qwerty*`（40 本） | 108,632 | 用户提供的 qwerty-learner CSV，按考研 / 出国 / 国内考试 / 通用 / 专业 / AI 分类；去掉重复文件与词条后导入 |

合计 **130,699** 条学习记录：前 8 本原生词书 22,067 条，新增 40 本 qwerty-learner CSV 词书 108,632 条。

四级/六级乱序版各有“汉译英 / 答案 / 英译汉”三份 PDF，词表相同；只取包含完整单词、音标和释义的答案页导入一次，避免重复词书。四级答案页原有 4,428 条，去重后 4,424 条；六级答案页的 5,523 条与已有六级大纲词表一致，因此不再重复新增。烤鸭TV 两份 Excel 原表各 1,500 条，四级表内重复词去重后 1,491 条。

## 上游来源

1. 用户本地文件：`大学英语四六级常用词组.pdf`，刘晓艳老师版；中文释义直接来自 PDF，未另行生成。
2. 用户本地文件：`大学英语四级词汇-乱序版-答案.pdf`（烤鸭TV）、`大学英语六级词汇-乱序版-答案.pdf`（刘晓艳老师版）。只取答案页，音标和释义直接来自 PDF。
3. 用户本地文件：烤鸭TV《四级核心词14天冲刺打卡表.xlsx》《六级核心词14天冲刺打卡表.xlsx》，Zoey 老师制作；取 Day1–Day14 的词汇、音标、核心释义。
4. [kajweb/dict](https://github.com/kajweb/dict)：[KaoYan_3 压缩包](https://raw.githubusercontent.com/kajweb/dict/master/book/1521164658897_KaoYan_3.zip)。其 `.json` 文件实际为逐行 JSON。使用其中中文释义、词性、音标、示例和搭配；该仓库说明数据采集自词典应用，未提供明确的 LICENSE；此处保留来源说明，不将其内容重新声明为自有或 MIT 授权。
5. [skywind3000/ECDICT](https://github.com/skywind3000/ECDICT)：[ecdict.csv](https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv)，用于补充部分本地词表释义。该仓库采用 [MIT License](https://github.com/skywind3000/ECDICT/blob/master/LICENSE)，完整许可文本保存在 `desktop/data/LICENSE-ECDICT.txt`。

应用内的「导入词书 → PDF」使用 [pypdf](https://github.com/py-pdf/pypdf) 读取 PDF 文本层，不调用外部 PDF SDK；pypdf 使用 BSD-3-Clause 许可，完整许可见 `desktop/data/LICENSE-pypdf.txt`。扫描版 PDF 没有文本层，应用会提示先 OCR，或改用 TXT / CSV。

生成前检查：所有集合中文释义非空；词组规范化去重；集合内 ID 唯一；无尾部英文占位符。缺失释义会中止生成，避免交付占位符。

## JSON 格式

顶层键为 8 本原生词书与 40 本 `qwerty*` 词书，每个值为记录数组。单条记录格式：

```json
{
  "id": "cet46-phrase-0001",
  "word": "a bill of fare",
  "meaning": "菜单；节目单",
  "pos": "词组",
  "senses": [
    {"pos": "词组", "meanings": ["菜单；节目单"]}
  ],
  "phonetic": "",
  "example": "",
  "exampleZh": "",
  "phrase": true
}
```

所有字段均存在；`phrase` 为布尔值，`senses` 为按来源词性分组的数组，组内 `meanings` 保存原词条的翻译文本及标点，其余顶层字段为字符串。数据格式版本为 2。ID 以集合类型为前缀，适合本地学习记录和生词本长期引用。
