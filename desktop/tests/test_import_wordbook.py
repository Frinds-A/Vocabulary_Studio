import json
import tempfile
import unittest
from pathlib import Path

from desktop.import_wordbook import PLACEHOLDER_MEANING, _rows_from_pdf_text, import_wordbook


class ImportWordbookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, name, content, encoding="utf-8"):
        path = self.root / name
        path.write_text(content, encoding=encoding, newline="")
        return path

    def test_csv_chinese_headers_and_same_pos_meanings_are_grouped(self):
        path = self.write(
            "words.csv",
            "單詞,中文,词性,音标,例句,例句翻译\n"
            'fish,"鱼，鱼肉",名词,/fɪʃ/,The fish swims.,鱼在游。\n'
            'FISH,捕鱼,vi.,,,\n'
            'fish,捕捉；搜寻,动词,,,\n',
        )
        result = import_wordbook(path)
        self.assertEqual((result["imported"], result["skipped"], result["source"]), (1, 0, "words.csv"))
        entry = result["entries"][0]
        self.assertEqual(entry["word"], "fish")
        self.assertEqual([(sense["pos"], sense["meanings"]) for sense in entry["senses"]], [
            ("n", ["鱼，鱼肉"]), ("vi", ["捕鱼"]), ("v", ["捕捉；搜寻"]),
        ])
        self.assertEqual(entry["phonetic"], "/fɪʃ/")
        self.assertEqual(entry["exampleZh"], "鱼在游。")
        self.assertEqual(set(entry), {"id", "word", "meaning", "pos", "senses", "phonetic", "example", "exampleZh", "phrase"})
        self.assertTrue(entry["id"].startswith("wordbook-") and len(entry["id"]) == 41)

    def test_csv_bom_quoted_comma_and_malformed_row_count(self):
        path = self.write("quoted.csv", '\ufeffword,meaning,pos\r\napple,"苹果, 苹果树",n\r\n,没有英文\r\n')
        result = import_wordbook(path)
        self.assertEqual(result["entries"][0]["meaning"], "苹果, 苹果树")
        self.assertEqual(result["skipped"], 1)

    def test_headerless_tsv_pairs_and_missing_meaning_placeholder(self):
        path = self.write("simple.tsv", "look after\t照顾\nresilient\n")
        result = import_wordbook(path)
        self.assertEqual(result["imported"], 2)
        phrase, word = result["entries"]
        self.assertTrue(phrase["phrase"])
        self.assertEqual(phrase["senses"][0]["pos"], "词组")
        self.assertEqual(word["meaning"], PLACEHOLDER_MEANING)
        self.assertEqual(word["pos"], "词义")
        self.assertEqual(word["senses"], [{"pos": "词义", "meanings": [PLACEHOLDER_MEANING]}])

    def test_txt_one_english_word_per_line_and_csv_pairs(self):
        path = self.write("list.txt", "  courage  \r\nset up,建立；安排\n,没有英文\n")
        result = import_wordbook(path)
        self.assertEqual(result["imported"], 2)
        self.assertEqual(result["skipped"], 1)
        self.assertEqual(result["entries"][0]["word"], "courage")
        self.assertEqual(result["entries"][0]["meaning"], PLACEHOLDER_MEANING)
        self.assertEqual(result["entries"][1]["meaning"], "建立；安排")

    def test_json_custom_senses_normalize_pos_and_merge_duplicate_words(self):
        path = self.write("custom.json", json.dumps({"words": [
            {"word": "light", "senses": [{"pos": "noun", "meanings": ["光；光线"]}, {"pos": "v.", "meanings": ["点燃"]}]},
            {"word": "LIGHT", "pos": "n.", "meaning": "灯；浅色"},
        ]}, ensure_ascii=False))
        result = import_wordbook(path)
        entry = result["entries"][0]
        self.assertEqual(result["imported"], 1)
        self.assertEqual(entry["pos"], "n / v")
        self.assertEqual(entry["senses"], [
            {"pos": "n", "meanings": ["光；光线", "灯；浅色"]},
            {"pos": "v", "meanings": ["点燃"]},
        ])

    def test_web_app_full_backup_imports_notebook_entries(self):
        backup = {
            "app": "lexicon-study", "version": 2,
            "data": {"notebook": [{"id": "old-id", "word": "take off", "meaning": "起飞；脱下", "pos": "词组", "phrase": True}]},
        }
        path = self.write("backup.json", json.dumps(backup, ensure_ascii=False))
        result = import_wordbook(path)
        self.assertEqual(result["imported"], 1)
        self.assertTrue(result["entries"][0]["phrase"])
        self.assertEqual(result["entries"][0]["senses"], [{"pos": "词组", "meanings": ["起飞；脱下"]}])

    def test_dictionary_json_and_builtin_bundle_json(self):
        dictionary = self.write("dict.json", '{"apple":"苹果","book":"书"}')
        self.assertEqual(import_wordbook(dictionary)["imported"], 2)
        bundle = self.write("bundle.json", json.dumps({"cet6Words": [{"word": "apple", "meaning": "苹果", "pos": "n"}], "postgradPhrases": [{"word": "look up", "meaning": "查阅", "pos": "词组", "phrase": True}]}))
        result = import_wordbook(bundle)
        self.assertEqual(result["imported"], 2)
        self.assertEqual(result["entries"][1]["pos"], "词组")

    def test_empty_malformed_json_and_unsupported_extension_are_rejected(self):
        empty = self.write("empty.csv", " \n\t\n")
        bad_json = self.write("bad.json", "{" )
        unsupported = self.write("book.xlsx", "data")
        for path, message in ((empty, "为空"), (bad_json, "JSON"), (unsupported, "仅支持")):
            with self.subTest(path=path.name), self.assertRaisesRegex(ValueError, message):
                import_wordbook(path)

    def test_pdf_numbered_one_line_entries_and_continuations(self):
        text = (
            "序号 单词 音标 释义\n"
            "1 abandon /əˈbændən/ v. 遗弃；放弃n. 放任，狂热\n"
            "2 ability /əˈbɪləti/ n. 能力，能耐；才能\n"
            "(英)埃布尔\n"
        )
        rows, skipped = _rows_from_pdf_text(text)
        self.assertEqual((len(rows), skipped), (2, 0))
        self.assertEqual(rows[0]["word"], "abandon")
        self.assertEqual(rows[0]["phonetic"], "əˈbændən")
        self.assertEqual([(s["pos"], s["meanings"]) for s in rows[0]["senses"]], [
            ("v", ["遗弃；放弃"]), ("n", ["放任，狂热"]),
        ])
        self.assertIn("埃布尔", rows[1]["meaning"])

    def test_pdf_split_lines_and_missing_closing_phonetic_slash(self):
        text = (
            "1 abandon\n/əˈbændən/\nv. 遗弃；放弃\n"
            "2 suggestion\n/s ə...ʃənn. 建议；示意\n"
        )
        rows, skipped = _rows_from_pdf_text(text)
        self.assertEqual((len(rows), skipped), (2, 0))
        self.assertEqual(rows[0]["word"], "abandon")
        self.assertEqual(rows[0]["senses"], [{"pos": "v", "meanings": ["遗弃；放弃"]}])
        self.assertEqual(rows[1]["word"], "suggestion")
        self.assertEqual(rows[1]["senses"], [{"pos": "n", "meanings": ["建议；示意"]}])

    def test_utf16_excel_tsv_is_read(self):
        path = self.write("excel.tsv", "单词\t释义\r\nresilient\t有韧性的\r\n", encoding="utf-16")
        self.assertEqual(import_wordbook(path)["entries"][0]["meaning"], "有韧性的")


if __name__ == "__main__":
    unittest.main()
