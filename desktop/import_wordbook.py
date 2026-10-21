"""Import user supplied wordbooks into Lexicon's normalized entry format.

The module has no Qt dependency so it can be used by both the QML application
and its unit tests.  Public API: :func:`import_wordbook`.
"""

from __future__ import annotations

import csv
import io
import json
import re
import uuid
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable


PLACEHOLDER_MEANING = "请回忆这个词的中文释义"

FIELD_ALIASES = {
    "word": {"word", "english", "英文", "单词", "單詞", "词汇", "词條", "词条"},
    "meaning": {"meaning", "translation", "chinese", "中文", "释义", "翻译", "意思"},
    "pos": {"pos", "part of speech", "partofspeech", "词性"},
    "phonetic": {"phonetic", "音标", "发音"},
    "example": {"example", "sentence", "例句"},
    "exampleZh": {"examplezh", "example_zh", "example zh", "例句翻译", "例句中文"},
}

POS_ALIASES = {
    "noun": "n", "名词": "n", "n.": "n",
    "verb": "v", "动词": "v", "v.": "v",
    "adjective": "adj", "形容词": "adj", "a": "adj", "a.": "adj", "adj.": "adj",
    "adverb": "adv", "副词": "adv", "adv.": "adv",
    "pronoun": "pron", "代词": "pron", "pron.": "pron",
    "preposition": "prep", "介词": "prep", "prep.": "prep",
    "conjunction": "conj", "连词": "conj", "conj.": "conj",
    "determiner": "det", "限定词": "det", "det.": "det",
    "numeral": "num", "数词": "num", "num.": "num",
    "interjection": "excl", "exclamation": "excl", "感叹词": "excl", "excl.": "excl",
    "auxiliary verb": "aux.v", "助动词": "aux.v", "aux.v.": "aux.v", "aux. v.": "aux.v",
    "modal verb": "modal v", "情态动词": "modal v",
    "plural": "pl", "复数": "pl", "phrase": "词组", "词组": "词组",
    "meaning": "词义", "词义": "词义",
}
POS_SPLIT = re.compile(r"\s*(?:/|、|,|，|;|；|\||\band\b|和)\s*", re.IGNORECASE)


def _decode(path: Path) -> str:
    data = path.read_bytes()
    if not data.strip():
        raise ValueError("词书文件为空")
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        try:
            return data.decode("utf-16")
        except UnicodeDecodeError as error:
            raise ValueError("UTF-16 文件编码错误") from error
    for encoding in ("utf-8-sig", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError("文件编码无法识别，请使用 UTF-8 或 GB18030 编码")


def _field_name(value: Any) -> str | None:
    key = re.sub(r"[\s_-]+", " ", str(value or "").strip().casefold())
    compact = key.replace(" ", "")
    for field, aliases in FIELD_ALIASES.items():
        if key in aliases or compact in {re.sub(r"[\s_-]+", "", alias.casefold()) for alias in aliases}:
            return field
    return None


def _pos_list(value: Any) -> list[str]:
    if isinstance(value, (list, tuple)):
        parts = [str(item).strip() for item in value if str(item).strip()]
    else:
        text = str(value or "").strip()
        parts = [part for part in POS_SPLIT.split(text) if part] if text else []
    result: list[str] = []
    for part in parts:
        raw = part.strip().rstrip(".").strip()
        normalized = POS_ALIASES.get(raw.casefold(), POS_ALIASES.get(raw, raw))
        if normalized and normalized not in result:
            result.append(normalized)
    return result


def _as_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return "；".join(text for item in value if (text := _as_text(item)))
    if isinstance(value, dict):
        return ""
    return str(value).strip()


def _sense_rows(raw: Any, fallback_pos: Any, fallback_meaning: Any) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    if isinstance(raw, list):
        for sense in raw:
            if not isinstance(sense, dict):
                continue
            positions = _pos_list(sense.get("pos")) or _pos_list(fallback_pos)
            meanings = sense.get("meanings", sense.get("meaning", ""))
            meaning = _as_text(meanings)
            for pos in positions or ["词义"]:
                if meaning:
                    pairs.append((pos, meaning))
    if not pairs:
        positions = _pos_list(fallback_pos)
        meaning = _as_text(fallback_meaning)
        if meaning:
            for pos in positions or ["词义"]:
                pairs.append((pos, meaning))
    return pairs


def _normalise_rows(rows: Iterable[dict[str, Any]], skipped: int = 0) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    by_word: dict[str, dict[str, Any]] = {}

    for raw in rows:
        if not isinstance(raw, dict):
            skipped += 1
            continue
        fields: dict[str, Any] = {}
        for key, value in raw.items():
            field = _field_name(key)
            if field and field not in fields:
                fields[field] = value
        word = _as_text(fields.get("word", raw.get("word", "")))
        if not word or not re.search(r"[A-Za-z]", word):
            skipped += 1
            continue

        meaning = _as_text(fields.get("meaning", raw.get("meaning", "")))
        pos_value = fields.get("pos", raw.get("pos", ""))
        is_phrase = bool(raw.get("phrase", False)) or bool(re.search(r"\s", word))
        if not meaning:
            meaning = PLACEHOLDER_MEANING
            pos_value = "词组" if is_phrase else "词义"
        elif is_phrase and not pos_value:
            pos_value = "词组"

        key = re.sub(r"\s+", " ", word.casefold()).strip()
        entry = by_word.get(key)
        if entry is None:
            entry = {
                "id": f"wordbook-{uuid.uuid4().hex}",
                "word": word,
                "meaning": "",
                "pos": "",
                "senses": [],
                "phonetic": _as_text(fields.get("phonetic", raw.get("phonetic", ""))),
                "example": _as_text(fields.get("example", raw.get("example", ""))),
                "exampleZh": _as_text(fields.get("exampleZh", raw.get("exampleZh", raw.get("example_zh", "")))),
                "phrase": is_phrase,
            }
            by_word[key] = entry
            entries.append(entry)
        else:
            entry["phrase"] = entry["phrase"] or is_phrase
            for field in ("phonetic", "example", "exampleZh"):
                incoming = _as_text(fields.get(field, raw.get(field, raw.get("example_zh", "") if field == "exampleZh" else "")))
                if not entry[field] and incoming:
                    entry[field] = incoming

        pairs = _sense_rows(raw.get("senses"), pos_value, meaning)
        for pos, sense_meaning in pairs:
            group = next((item for item in entry["senses"] if item["pos"].casefold() == pos.casefold()), None)
            if group is None:
                group = {"pos": pos, "meanings": []}
                entry["senses"].append(group)
            if sense_meaning not in group["meanings"]:
                group["meanings"].append(sense_meaning)
        if not pairs:
            # Every usable entry has a displayable sense, even for unusual JSON shapes.
            entry["senses"] = [{"pos": "词义", "meanings": [PLACEHOLDER_MEANING]}]
        all_meanings = list(dict.fromkeys(
            value for sense in entry["senses"] for value in sense["meanings"]
        ))
        entry["meaning"] = "；".join(all_meanings)
        entry["pos"] = " / ".join(sense["pos"] for sense in entry["senses"])
        entry["phrase"] = bool(entry["phrase"] or any(sense["pos"] == "词组" for sense in entry["senses"]))

    if not entries:
        raise ValueError("文件中没有可导入的英文词条")
    return {"entries": entries, "imported": len(entries), "skipped": skipped}


def _looks_like_header(row: list[str]) -> bool:
    return any(_field_name(cell) == "word" for cell in row)


def _rows_from_delimited(text: str, delimiter: str | None = None) -> tuple[list[dict[str, Any]], int]:
    sample = "\n".join(text.splitlines()[:12])
    if delimiter is None:
        try:
            delimiter = csv.Sniffer().sniff(sample, delimiters="\t,;").delimiter
        except csv.Error:
            delimiter = "\t" if "\t" in sample else ","
    records = list(csv.reader(io.StringIO(text), delimiter=delimiter))
    records = [row for row in records if any(cell.strip() for cell in row)]
    if not records:
        raise ValueError("词书文件为空")
    header = records[0] if _looks_like_header(records[0]) else None
    if header:
        columns = [_field_name(cell) for cell in header]
        data = records[1:]
        rows = [{columns[index]: cell.strip() for index, cell in enumerate(row[:len(columns)]) if index < len(columns) and columns[index]} for row in data]
    else:
        rows = []
        for row in records:
            if len(row) == 1:
                rows.append({"word": row[0].strip()})
            elif len(row) >= 2:
                rows.append({"word": row[0].strip(), "meaning": row[1].strip()})
    return rows, 0


def _extract_json_rows(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if not isinstance(value, dict):
        return []

    # The web app's full backup stores learning state under data and words in notebook.
    if value.get("app") == "lexicon-study" and isinstance(value.get("data"), dict):
        notebook = value["data"].get("notebook", [])
        return notebook if isinstance(notebook, list) else []

    for key in ("entries", "words", "items", "vocabulary", "wordbook", "notebook"):
        if isinstance(value.get(key), list):
            return value[key]

    # App vocabulary bundle: four named decks containing arrays of word objects.
    deck_arrays = [
        item for item in value.values()
        if isinstance(item, list) and any(isinstance(row, dict) and "word" in row for row in item)
    ]
    if deck_arrays:
        return [item for deck in deck_arrays for item in deck]

    # Simple JSON dictionary: {"apple": "苹果", ...}.
    if value and all(isinstance(word, str) and isinstance(meaning, (str, list)) for word, meaning in value.items()):
        return [{"word": word, "meaning": meaning} for word, meaning in value.items()]

    # Some exporters wrap custom data one level deeper.
    for key in ("data", "book", "result"):
        if isinstance(value.get(key), (dict, list)):
            rows = _extract_json_rows(value[key])
            if rows:
                return rows
    return []


def _docx_blocks(path: Path) -> tuple[str, str]:
    """Extract table rows and ordinary paragraphs from a .docx file.

    Reading ``word/document.xml`` directly keeps DOCX support dependency-free
    (no python-docx/lxml), which matters for the single-file Windows build.
    """
    namespace = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    try:
        with zipfile.ZipFile(path) as archive:
            xml = archive.read("word/document.xml")
    except (OSError, KeyError, zipfile.BadZipFile) as error:
        raise ValueError("Word 文档无法读取，请确认是有效的 .docx 文件") from error
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        raise ValueError("Word 文档内容无法解析") from error

    table_lines: list[str] = []
    paragraph_lines: list[str] = []

    def paragraph_text(paragraph: ET.Element) -> str:
        return "".join(node.text or "" for node in paragraph.iter(namespace + "t")).strip()

    body = root.find(namespace + "body")
    if body is None:
        return "", ""
    for block in list(body):
        if block.tag == namespace + "p":
            text = paragraph_text(block)
            if text:
                paragraph_lines.append(text)
        elif block.tag == namespace + "tbl":
            for row in block.findall(namespace + "tr"):
                cells = []
                for cell in row.findall(namespace + "tc"):
                    chunks = [paragraph_text(item) for item in cell.findall(namespace + "p")]
                    cells.append(" ".join(chunk for chunk in chunks if chunk))
                if any(cells):
                    table_lines.append("\t".join(cells))
    return "\n".join(table_lines), "\n".join(paragraph_lines)


def _rows_from_word_text(text: str) -> tuple[list[dict[str, Any]], int]:
    rows: list[dict[str, Any]] = []
    skipped = 0
    for line in (item.strip() for item in text.splitlines()):
        if not line:
            continue
        match = re.match(
            r"^([A-Za-z][A-Za-z'’\-.]*(?:\s+[A-Za-z][A-Za-z'’\-.]*){0,4})\s+(.+)$",
            line,
        )
        if not match or not re.search(r"[\u4e00-\u9fff]", match.group(2)):
            skipped += 1
            continue
        word, rest = match.group(1).strip(), match.group(2).strip()
        senses = _pdf_senses(rest)
        pos = senses[0]["pos"] if senses and senses[0]["pos"] else "词义"
        rows.append({"word": word, "meaning": rest, "pos": pos})
    if len(rows) < 3:
        raise ValueError("Word 文档中没有识别到词条；请使用表格或每行「单词 释义」格式")
    return rows, skipped


PDF_ENTRY_START = re.compile(r"^\s*(\d{1,6})[.、]?\s+(.+?)\s*$")
PDF_WORD = re.compile(
    r"^([A-Za-z][A-Za-z'’\-.]*(?:\s+[A-Za-z][A-Za-z'’\-.]*)*?)"
    r"(?=\s+(?:[/\[]|(?:n|v|vt|vi|adj|adv|prep|conj|pron|num|art|interj|aux|modal\s+v)\.)|$)"
)
PDF_POS = re.compile(r"(?<![A-Za-z])(n|v|vt|vi|adj|adv|prep|conj|pron|num|art|interj|aux|modal\s+v)\.")
PDF_EMBEDDED_POS = re.compile(r"(n|v|vt|vi|adj|adv|prep|conj|pron|num|art|interj|aux|modal\s+v)\.(?=\s|[\u4e00-\u9fff])")
PDF_HEADER = re.compile(r"^(?:序号\s*单词|单词\s*音标|word\s+phonetic|序号|音标|释义)\s*$", re.IGNORECASE)


def _pdf_text(path: Path) -> str:
    """Read the text layer of a PDF.

    PDFs are intentionally parsed with pypdf (pure Python) so the frozen app
    does not need a platform PDF SDK.  Scanned/image-only PDFs still need OCR.
    """
    try:
        from pypdf import PdfReader
    except ImportError as error:  # pragma: no cover - build includes pypdf
        raise ValueError("当前版本缺少 PDF 解析组件，请使用 TXT、CSV 或 JSON") from error
    try:
        reader = PdfReader(str(path))
        if reader.is_encrypted:
            try:
                reader.decrypt("")
            except Exception as error:
                raise ValueError("PDF 已加密，无法读取") from error
        chunks = []
        for page in reader.pages:
            try:
                chunks.append(page.extract_text() or "")
            except Exception:
                continue
    except ValueError:
        raise
    except Exception as error:
        raise ValueError(f"PDF 无法读取：{error}") from error
    text = "\n".join(chunks)
    if len(re.findall(r"[A-Za-z]", text)) < 30:
        raise ValueError("PDF 没有可提取的文本层；扫描版 PDF 请先 OCR，或改用 TXT / CSV")
    return text


def _split_pdf_phonetic(text: str) -> tuple[str, str]:
    text = text.strip()
    if not text or text[0] not in "/[":
        return "", text
    close = text.find("/" if text[0] == "/" else "]", 1)
    if close > 0:
        return text[1:close].strip(), text[close + 1:].strip()
    match = PDF_EMBEDDED_POS.search(text)
    if match and match.start() > 1:
        return text[1:match.start()].strip(), text[match.start():].strip()
    return text[1:].strip(), ""


def _split_pdf_word(rest: str) -> tuple[str, str] | None:
    match = PDF_WORD.match(rest)
    if not match:
        # Some PDFs omit the phonetic and POS, e.g. "abandon 遗弃；放弃".
        match = re.match(r"^([A-Za-z][A-Za-z'’\-.]*(?:\s+[A-Za-z][A-Za-z'’\-.]*)?)\s+(.+)$", rest)
    if not match:
        return None
    word = match.group(1).strip()
    if not re.search(r"[A-Za-z]", word):
        return None
    return word, rest[match.end():].strip()


def _pdf_senses(meaning: str) -> list[dict[str, Any]]:
    matches = list(PDF_POS.finditer(meaning))
    if not matches:
        return []
    senses: list[dict[str, Any]] = []
    if matches[0].start() > 0:
        head = meaning[:matches[0].start()].strip(" ；;，,。")
        if head:
            senses.append({"pos": "", "meanings": [head]})
    for index, match in enumerate(matches):
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(meaning)
        text = meaning[start:end].strip(" ；;，,。")
        if text:
            senses.append({"pos": match.group(1).replace(" ", ""), "meanings": [text]})
    return senses


def _rows_from_pdf_text(text: str) -> tuple[list[dict[str, Any]], int]:
    """Parse common numbered vocabulary PDFs.

    Handles both one-line entries (``1 abandon /.../ v. 放弃``) and entries
    whose word, phonetic and gloss are split across lines.  Non-numbered PDFs
    still get a best-effort line parse at the end.
    """
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    blocks: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    skipped = 0
    for line in lines:
        if PDF_HEADER.match(line):
            continue
        entry = PDF_ENTRY_START.match(line)
        if entry:
            parsed = _split_pdf_word(entry.group(2).strip())
            if parsed:
                word, tail = parsed
                current = {"word": word, "parts": [tail] if tail else []}
                blocks.append(current)
                continue
        if current is not None:
            current["parts"].append(line)

    rows: list[dict[str, Any]] = []
    for block in blocks:
        parts = [part for part in block["parts"] if part.strip()]
        phonetic = ""
        if parts and (parts[0].startswith("/") or parts[0].startswith("[")):
            phonetic, first = _split_pdf_phonetic(parts[0])
            parts = ([first] if first else []) + parts[1:]
        meaning = " ".join(parts)
        meaning = re.sub(r"\s+", " ", meaning).strip(" ；;，,。")
        if not meaning:
            skipped += 1
            continue
        senses = _pdf_senses(meaning)
        pos = senses[0]["pos"] if senses and senses[0]["pos"] else "词义"
        rows.append({
            "word": block["word"],
            "meaning": meaning,
            "pos": pos,
            "senses": senses,
            "phonetic": phonetic,
        })

    if rows:
        return rows, skipped

    # Fallback for unnumbered PDFs: one entry per line, e.g.
    # "abandon /əˈbændən/ v. 放弃".  Only accept lines with a clear word/phonetic
    # or a pair of columns; otherwise the PDF is too free-form to import.
    fallback: list[dict[str, Any]] = []
    for line in lines:
        if PDF_HEADER.match(line):
            continue
        match = re.match(r"^([A-Za-z][A-Za-z'’\-.]*(?:\s+[A-Za-z][A-Za-z'’\-.]*)*?)\s+(/.+|\[.+)$", line)
        if not match:
            continue
        word, rest = match.group(1).strip(), match.group(2).strip()
        phonetic, meaning = _split_pdf_phonetic(rest)
        if not meaning:
            continue
        senses = _pdf_senses(meaning)
        fallback.append({
            "word": word,
            "meaning": meaning,
            "pos": senses[0]["pos"] if senses and senses[0]["pos"] else "词义",
            "senses": senses,
            "phonetic": phonetic,
        })
    if len(fallback) < 3:
        raise ValueError("PDF 中没有识别到词条；请确认 PDF 含文本层，或改用 TXT / CSV")
    return fallback, skipped


def import_wordbook(path: str | Path) -> dict[str, Any]:
    """Read a wordbook and return normalized entries plus import statistics.

    The result contains ``entries``, ``imported`` (unique words), ``skipped``
    (malformed delimited rows), and ``source`` (the input file name).
    """
    source_path = Path(path)
    suffix = source_path.suffix.casefold()
    if suffix not in {".csv", ".tsv", ".txt", ".json", ".pdf", ".docx"}:
        raise ValueError("仅支持 CSV、TSV、TXT、PDF、Word(.docx) 或 JSON 词书")
    if suffix == ".docx":
        table_text, paragraph_text = _docx_blocks(source_path)
        rows: list[dict[str, Any]] = []
        skipped = 0
        if table_text.strip():
            try:
                rows, skipped = _rows_from_delimited(table_text, "\t")
            except ValueError:
                rows = []
        if len(rows) < 3:
            rows, skipped = _rows_from_word_text(paragraph_text or table_text)
        result = _normalise_rows(rows, skipped)
        result["source"] = source_path.name
        return result
    if suffix == ".pdf":
        rows, skipped = _rows_from_pdf_text(_pdf_text(source_path))
        result = _normalise_rows(rows, skipped)
        result["source"] = source_path.name
        return result
    text = _decode(source_path)
    if suffix == ".json":
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as error:
            raise ValueError(f"JSON 格式错误：{error.msg}") from error
        rows = _extract_json_rows(parsed)
        if not rows:
            raise ValueError("JSON 中没有可识别的词条")
        result = _normalise_rows(rows)
    else:
        delimiter = "\t" if suffix == ".tsv" else None
        rows, skipped = _rows_from_delimited(text, delimiter)
        result = _normalise_rows(rows, skipped)
    result["source"] = source_path.name
    return result


__all__ = ["import_wordbook", "PLACEHOLDER_MEANING"]
