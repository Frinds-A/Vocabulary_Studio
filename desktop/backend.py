"""QML-facing study backend for the Vocabulary Studio desktop app."""

from __future__ import annotations

import base64
import copy
import difflib
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

try:
    from .version import APP_VERSION
except ImportError:  # pragma: no cover
    from version import APP_VERSION

try:
    from .qwerty_decks import QWERTY_DECK_META, QWERTY_DEFAULT_DAILY_GOALS
except ImportError:  # pragma: no cover
    from qwerty_decks import QWERTY_DECK_META, QWERTY_DEFAULT_DAILY_GOALS


REVIEW_INTERVALS = (24 * 60 * 60_000, 2 * 24 * 60 * 60_000,
                    4 * 24 * 60 * 60_000, 7 * 24 * 60 * 60_000,
                    15 * 24 * 60 * 60_000, 30 * 24 * 60 * 60_000)
DEFAULT_DAILY_GOALS = {
    "cet46Phrases": 20,
    "cet4Outline": 20,
    "cet6Words": 20, "cet6Outline": 20,
    "kaoyaCET4": 20, "kaoyaCET6": 20,
    "postgradWords": 20, "postgradPhrases": 10,
}
# A word only counts as mastered after this many correct answers. Missing a
# spelling no longer resets the accumulated count; it just schedules a retry.
MASTERY_TARGET = 2
DECK_META = {
    "cet46Phrases": {"name": "四六级常用词组（刘晓艳）", "exam": "cet", "type": "phrases", "short": "CET-4/6", "tag": "刘晓艳", "color": "sand", "description": "刘晓艳老师版四六级常用搭配。"},
    "cet4Outline": {"name": "四级大纲词汇（烤鸭TV）", "exam": "cet4", "type": "words", "short": "CET-4", "tag": "烤鸭TV", "color": "sand", "description": "烤鸭TV 四级乱序大纲词汇，按 PDF 答案页整理。"},
    "cet6Words": {"name": "六级核心单词（刘晓艳）", "exam": "cet6", "type": "words", "short": "CET-6", "tag": "刘晓艳", "color": "green", "description": "刘晓艳老师版六级核心词表。"},
    "cet6Outline": {"name": "六级大纲词汇（刘晓艳）", "exam": "cet6", "type": "words", "short": "CET-6", "tag": "刘晓艳", "color": "green", "description": "刘晓艳老师版六级乱序大纲词汇。"},
    "kaoyaCET4": {"name": "四级核心词（烤鸭TV）", "exam": "cet4", "type": "words", "short": "烤鸭TV", "tag": "14天冲刺", "color": "sand", "description": "烤鸭TV Zoey 老师四级核心词 14 天冲刺打卡表。"},
    "kaoyaCET6": {"name": "六级核心词（烤鸭TV）", "exam": "cet6", "type": "words", "short": "烤鸭TV", "tag": "14天冲刺", "color": "sand", "description": "烤鸭TV Zoey 老师六级核心词 14 天冲刺打卡表。"},
    "postgradWords": {"name": "考研核心单词（GPT）", "exam": "postgrad", "type": "words", "short": "NPEE", "tag": "GPT整理", "color": "blue", "description": "GPT 搜集整理的考研核心词。"},
    "postgradPhrases": {"name": "考研常用词组（GPT）", "exam": "postgrad", "type": "phrases", "short": "NPEE", "tag": "GPT整理", "color": "rose", "description": "GPT 搜集整理的考研常用词组。"},
}
DECK_META.update(QWERTY_DECK_META)
DEFAULT_DAILY_GOALS.update(QWERTY_DEFAULT_DAILY_GOALS)


def _now_ms() -> int:
    return int(datetime.now().timestamp() * 1000)


def _day_key(timestamp: int | float | None = None) -> str:
    if timestamp is None:
        return date.today().isoformat()
    return datetime.fromtimestamp(float(timestamp) / 1000).date().isoformat()


def _normalise_answer(value: Any) -> str:
    text = str(value or "").strip().casefold()
    text = text.translate(str.maketrans({"’": "'", "‘": "'", "‐": "-", "‑": "-", "–": "-", "—": "-"}))
    return re.sub(r"\s+", " ", text)


def _spelling_key(value: Any) -> str:
    """Compare spellings without requiring spaces inside phrases."""
    return re.sub(r"\s+", "", _normalise_answer(value))


def _spell_marks(typed: Any, expected: Any) -> list[dict[str, Any]]:
    """Per-letter comparison for a misspelled answer.

    Returns one entry per typed letter; ``wrong`` is true when that letter is
    not part of the best alignment with the expected word.  Punctuation and
    spaces are ignored so the result maps directly onto the QML letter slots.
    """
    typed_letters = [char for char in str(typed or "") if char.isalpha()]
    expected_letters = [char for char in str(expected or "") if char.isalpha()]
    marks = [{"ch": char, "wrong": False} for char in typed_letters]
    if not typed_letters or not expected_letters:
        return marks
    matcher = difflib.SequenceMatcher(
        None,
        [char.casefold() for char in typed_letters],
        [char.casefold() for char in expected_letters],
        autojunk=False,
    )
    for tag, i1, i2, _j1, _j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        for index in range(i1, i2):
            marks[index]["wrong"] = True
    return marks


def _safe_int(value: Any, default: int, low: int, high: int) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    return min(high, max(low, number))


def _is_mastered(record: Any) -> bool:
    return isinstance(record, dict) and _safe_int(record.get("correctCount"), 0, 0, 1_000_000) >= MASTERY_TARGET


def _default_state() -> dict[str, Any]:
    return {
        "version": 1,
        "selectedDeckId": "cet6Words",
        "selectedDeckIds": ["cet6Words", "cet46Phrases"],
        "mode": "spelling",
        "dailyGoals": dict(DEFAULT_DAILY_GOALS),
        "customGoals": {},
        "settings": {"autoSpeak": True, "spacedRepetition": True, "includeNotebook": False,
                     "voiceAccent": "us", "autoCheckUpdates": True,
                     "chapterMode": True, "chapterSize": 20, "studyScope": "mix",
                     "inputSound": True, "inputSoundStyle": "click",
                     "speechRate": 0.0, "autoBackup": True,
                     "forgotShortcut": "Alt+F", "loopSession": False,
                     "welcomeSeen": False, "welcomeVersion": ""},
        "progress": {},
        "attempts": [],
        "studySeconds": 0,
        "notebook": [],
        "favoriteDecks": [],
        "recentDecks": [],
        "statsDeckIds": [],
        "lastChapters": {},
        "customBooks": [],
        "session": None,
    }


class StudyBackend(QObject):
    """Persistent study state and slots consumed by ``desktop/qml/Main.qml``."""

    stateChanged = Signal()
    answerChanged = Signal()
    goalsChanged = Signal()
    studyTimeChanged = Signal()
    statusMessageChanged = Signal()

    def __init__(self, data_path: str | Path | None = None, state_path: str | Path | None = None, parent: QObject | None = None):
        super().__init__(parent)
        if getattr(sys, "frozen", False):
            # PyInstaller's one-file bundle unpacks qml/ and data/ into _MEIPASS.
            self._app_dir = Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent))
        else:
            self._app_dir = Path(__file__).resolve().parent
        self._data_path = Path(data_path) if data_path else self._app_dir / "data" / "vocabulary.json"
        if not self._data_path.exists():
            self._data_path = self._app_dir.parent / "public" / "data" / "vocabulary.json"
        self._state_path = Path(state_path) if state_path else self._default_state_path()
        self._state_path.parent.mkdir(parents=True, exist_ok=True)
        self._page = "home"
        self._status_message = ""
        self._vocabulary = self._load_vocabulary()
        self._state = self._read_state()
        self._cache: dict[str, Any] = {}
        self._study_pending = 0
        self._qt_voice_ready = False
        self._speech_token = 0
        self._audio_dir = self._state_path.parent / "audio"
        self._audio_manager = None
        self._audio_player = None
        self._audio_output = None
        self._audio_pending: set[str] = set()
        self._entries_by_id: dict[str, dict[str, Any]] = {}
        self._ids_by_word: dict[str, list[str]] = {}
        self._history: list[dict[str, Any]] = []
        self._refresh_index()
        self._sanitize_deck_selection()
        self._sanitize_stats_decks()
        self._sanitize_session()
        self._tts = None
        self._input_sound = None
        self._sound_pool: dict[str, list[Any]] = {}
        self._sound_index = 0
        self._prepare_input_sounds()
        self._emit_changed(save=False)

    @staticmethod
    def _default_state_path() -> Path:
        if os.name == "nt":
            base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
            return Path(base) / "词序桌面版" / "state.json"
        base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
        return Path(base) / "词序桌面版" / "state.json"

    def _load_vocabulary(self) -> dict[str, list[dict[str, Any]]]:
        try:
            parsed = json.loads(self._data_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            parsed = {}
        return {key: value for key, value in parsed.items() if key in DECK_META and isinstance(value, list)} if isinstance(parsed, dict) else {}

    def _read_state(self) -> dict[str, Any]:
        state = _default_state()
        try:
            saved = json.loads(self._state_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return state
        if not isinstance(saved, dict):
            return state
        state["selectedDeckId"] = str(saved.get("selectedDeckId") or state["selectedDeckId"])
        selected_ids = saved.get("selectedDeckIds")
        if not isinstance(selected_ids, list) or not selected_ids:
            selected_ids = [state["selectedDeckId"]]
        selected_ids = [str(item) for item in selected_ids if isinstance(item, str) and item]
        state["selectedDeckIds"] = selected_ids or [state["selectedDeckId"]]
        state["selectedDeckId"] = state["selectedDeckIds"][0]
        stats_ids = saved.get("statsDeckIds")
        if isinstance(stats_ids, list):
            state["statsDeckIds"] = [str(item) for item in stats_ids if isinstance(item, str) and item][:5]
        state["mode"] = saved.get("mode") if saved.get("mode") in {"spelling", "choice", "dictation"} else "spelling"
        if isinstance(saved.get("dailyGoals"), dict):
            state["dailyGoals"].update({key: _safe_int(value, DEFAULT_DAILY_GOALS[key], 1, 200)
                                        for key, value in saved["dailyGoals"].items() if key in DEFAULT_DAILY_GOALS})
        if isinstance(saved.get("customGoals"), dict):
            state["customGoals"] = {str(key): _safe_int(value, 20, 1, 200) for key, value in saved["customGoals"].items()}
        if isinstance(saved.get("settings"), dict):
            state["settings"].update({key: bool(saved["settings"][key])
                                      for key in ("autoSpeak", "spacedRepetition", "includeNotebook",
                                                  "autoCheckUpdates", "chapterMode", "inputSound",
                                                  "autoBackup", "loopSession", "welcomeSeen")
                                      if key in saved["settings"]})
            if isinstance(saved["settings"].get("welcomeVersion"), str):
                state["settings"]["welcomeVersion"] = saved["settings"]["welcomeVersion"]
            if saved["settings"].get("inputSoundStyle") in {"click", "bubble"}:
                state["settings"]["inputSoundStyle"] = saved["settings"]["inputSoundStyle"]
            if saved["settings"].get("voiceAccent") in {"us", "uk"}:
                state["settings"]["voiceAccent"] = saved["settings"]["voiceAccent"]
            if saved["settings"].get("studyScope") in {"mix", "new", "review"}:
                state["settings"]["studyScope"] = saved["settings"]["studyScope"]
            state["settings"]["chapterSize"] = _safe_int(saved["settings"].get("chapterSize"), 20, 5, 100)
            state["settings"]["speechRate"] = max(-0.4, min(0.4, float(saved["settings"].get("speechRate", 0.0) or 0.0)))
            if isinstance(saved["settings"].get("forgotShortcut"), str):
                state["settings"]["forgotShortcut"] = self._normalise_shortcut(saved["settings"]["forgotShortcut"])
        if isinstance(saved.get("progress"), dict):
            state["progress"] = {str(key): value for key, value in saved["progress"].items()
                                  if isinstance(value, dict) and isinstance(value.get("lastSeenAt"), (int, float))}
            for record in state["progress"].values():
                if isinstance(record, dict):
                    record["correctCount"] = max(
                        _safe_int(record.get("correctCount"), 0, 0, 1_000_000),
                        _safe_int(record.get("correctStreak"), 0, 0, 1_000_000),
                    )
        if isinstance(saved.get("attempts"), list):
            state["attempts"] = [item for item in saved["attempts"] if self._valid_attempt(item)][-10000:]
        state["studySeconds"] = _safe_int(saved.get("studySeconds"), 0, 0, 10**12)
        if isinstance(saved.get("notebook"), list):
            state["notebook"] = [item for item in saved["notebook"] if isinstance(item, dict) and isinstance(item.get("word"), str) and isinstance(item.get("id"), str)]
        if isinstance(saved.get("favoriteDecks"), list):
            state["favoriteDecks"] = [str(item) for item in saved["favoriteDecks"] if isinstance(item, str)]
        if isinstance(saved.get("recentDecks"), list):
            state["recentDecks"] = [str(item) for item in saved["recentDecks"] if isinstance(item, str)][:8]
        if isinstance(saved.get("lastChapters"), dict):
            state["lastChapters"] = {str(key): max(0, _safe_int(value, 0, 0, 100000))
                                     for key, value in saved["lastChapters"].items()
                                     if isinstance(key, str)}
        if isinstance(saved.get("customBooks"), list):
            state["customBooks"] = [self._clean_book(item) for item in saved["customBooks"] if self._clean_book(item)]
        session = saved.get("session")
        if isinstance(session, dict) and isinstance(session.get("ids"), list):
            state["session"] = {
                "deckKey": str(session.get("deckKey", "")),
                "deckKeys": [str(item) for item in session.get("deckKeys", []) if isinstance(item, str)],
                "ids": [str(item) for item in session["ids"] if isinstance(item, str)][:10000],
                "kind": session.get("kind", "free") if session.get("kind") in {"today", "deck", "review", "free", "notebook", "random", "dictation", "chapter"} else "free",
                "chapterIndex": max(0, _safe_int(session.get("chapterIndex"), 0, 0, 100000)),
                "chapterDeck": str(session.get("chapterDeck", ""))[:200],
                "position": max(0, _safe_int(session.get("position"), 0, 0, 10000)),
                "completed": max(0, _safe_int(session.get("completed"), 0, 0, 10000)),
                "answer": str(session.get("answer", ""))[:500],
                "result": session.get("result") if isinstance(session.get("result"), dict) else None,
                "right": max(0, _safe_int(session.get("right"), 0, 0, 10000)),
                "retrying": bool(session.get("retrying", False)),
                "retryResult": session.get("retryResult") if isinstance(session.get("retryResult"), dict) else None,
                "retryWrong": bool(session.get("retryWrong", False)),
                "passes": max(1, min(2, _safe_int(session.get("passes"), 2, 1, 2))),
                "typedLetters": max(0, _safe_int(session.get("typedLetters"), 0, 0, 10_000_000)),
                "revealHint": str(session.get("revealHint", ""))[:200],
                "startedAt": _safe_int(session.get("startedAt"), _now_ms(), 0, 8_640_000_000_000_000),
            }
        return state

    @staticmethod
    def _valid_attempt(item: Any) -> bool:
        return isinstance(item, dict) and isinstance(item.get("id"), str) and isinstance(item.get("at"), (int, float)) and isinstance(item.get("correct"), bool)

    @staticmethod
    def _clean_book(book: Any) -> dict[str, Any] | None:
        if not isinstance(book, dict) or not isinstance(book.get("id"), str) or not isinstance(book.get("entries"), list):
            return None
        entries = [entry for entry in book["entries"] if isinstance(entry, dict) and isinstance(entry.get("id"), str) and isinstance(entry.get("word"), str)]
        if not entries:
            return None
        return {"id": book["id"], "name": str(book.get("name") or "自定义词书"), "source": str(book.get("source") or ""), "entries": entries}

    def _save_state(self) -> None:
        self._state_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self._state_path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(self._state, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(self._state_path)
        if self._state.get("settings", {}).get("autoBackup", True):
            try:
                backup_dir = self._state_path.parent / "backups"
                backup_dir.mkdir(parents=True, exist_ok=True)
                backup = backup_dir / f"state-{date.today().isoformat()}.json"
                if not backup.exists():
                    shutil.copy2(self._state_path, backup)
                backups = sorted(backup_dir.glob("state-*.json"))
                for old in backups[:-7]:
                    old.unlink(missing_ok=True)
            except OSError:
                pass

    def _emit_changed(self, save: bool = True, invalidate: bool = True) -> None:
        if invalidate:
            self._cache.clear()
        if save:
            try:
                self._save_state()
            except OSError as error:
                self._status_message = f"无法保存学习记录：{error}"
                self.statusMessageChanged.emit()
        self.stateChanged.emit()

    def _refresh_index(self) -> None:
        self._cache.clear()
        self._entries_by_id = {}
        self._ids_by_word = {}
        for key in DECK_META:
            for raw in self._vocabulary.get(key, []):
                if not isinstance(raw, dict) or not raw.get("id") or not raw.get("word"):
                    continue
                entry = dict(raw)
                entry["deckKey"] = key
                entry["deckName"] = DECK_META[key]["name"]
                entry.setdefault("meaning", "")
                entry.setdefault("pos", "词义")
                entry["phrase"] = DECK_META[key].get("type") == "phrases"
                self._entries_by_id[str(entry["id"])] = entry
        for book in self._state.get("customBooks", []):
            for raw in book["entries"]:
                entry = dict(raw)
                entry["deckKey"] = book["id"]
                entry["deckName"] = book["name"]
                self._entries_by_id[str(entry["id"])] = entry
        for entry in self._state.get("notebook", []):
            if entry.get("id") not in self._entries_by_id:
                self._entries_by_id[entry["id"]] = dict(entry)
        for entry_id, entry in self._entries_by_id.items():
            word_key = _normalise_answer(entry.get("word", ""))
            if word_key:
                self._ids_by_word.setdefault(word_key, []).append(entry_id)
        self._sync_shared_progress()

    def _sync_shared_progress(self) -> None:
        """Mirror a word's progress to every deck/notebook occurrence.

        A word can exist in several books with different entry ids.  Learning
        it in one place must count in all of them, so each group of ids that
        share a normalized word gets the most advanced record.
        """
        progress = self._state.get("progress")
        if not isinstance(progress, dict):
            return
        for ids in self._ids_by_word.values():
            records = [(entry_id, progress[entry_id]) for entry_id in ids
                       if isinstance(progress.get(entry_id), dict)]
            if not records:
                continue
            best = max(records, key=lambda pair: (
                _safe_int(pair[1].get("correctCount"), 0, 0, 1_000_000),
                _safe_int(pair[1].get("lastSeenAt"), 0, 0, 2**63 - 1),
            ))[1]
            for entry_id in ids:
                current = progress.get(entry_id)
                if current == best:
                    continue
                if not isinstance(current, dict) or _safe_int(current.get("correctCount"), 0, 0, 1_000_000) <= _safe_int(best.get("correctCount"), 0, 0, 1_000_000):
                    progress[entry_id] = copy.deepcopy(best)

    def _sanitize_deck_selection(self) -> None:
        all_decks = self._all_decks()
        valid = {deck["id"] for deck in all_decks}
        selected = [str(item) for item in self._state.get("selectedDeckIds", [])]
        selected = ["cet46Phrases" if item == "cet6Phrases" else item for item in selected]
        selected = [item for item in selected if item in valid]
        selected = list(dict.fromkeys(selected))
        if not selected:
            primary = str(self._state.get("selectedDeckId", ""))
            if primary == "cet6Phrases":
                primary = "cet46Phrases"
            selected = [primary] if primary in valid else []
        if not selected and all_decks:
            selected = [all_decks[0]["id"]]
        word_id = next((item_id for item_id in selected
                        for deck in all_decks if deck["id"] == item_id and deck.get("type") != "phrases"), "")
        phrase_id = next((item_id for item_id in selected
                          for deck in all_decks if deck["id"] == item_id and deck.get("type") == "phrases"), "")
        if not word_id:
            word_id = next((deck["id"] for deck in all_decks if deck.get("type") != "phrases"), "")
        if not phrase_id:
            phrase_id = next((deck["id"] for deck in all_decks if deck.get("type") == "phrases"), "")
        normalized = [item_id for item_id in (word_id, phrase_id) if item_id]
        if not normalized and all_decks:
            normalized = [all_decks[0]["id"]]
        self._state["selectedDeckIds"] = normalized
        self._state["selectedDeckId"] = normalized[0] if normalized else ""
        if not (word_id and phrase_id):
            self._state.setdefault("settings", {})["includeNotebook"] = False

    def _sanitize_stats_decks(self) -> None:
        all_decks = self._all_decks()
        all_ids = [str(deck["id"]) for deck in all_decks]
        valid = set(all_ids)
        raw = self._state.get("statsDeckIds")
        selected = []
        for item in raw if isinstance(raw, list) else []:
            deck_id = str(item)
            if deck_id in valid and deck_id not in selected:
                selected.append(deck_id)
        if not selected:
            selected = all_ids[:5]
        self._state["statsDeckIds"] = selected[:5]

    def _clear_session_for_deck_change(self) -> None:
        if self._state.get("session") is not None:
            self._state["session"] = None
            self._history.clear()

    def _apply_deck_selection(self, word_id: str, phrase_id: str) -> None:
        ids = [item_id for item_id in (word_id, phrase_id) if item_id]
        if not ids:
            return
        self._clear_session_for_deck_change()
        self._state["selectedDeckIds"] = ids
        self._state["selectedDeckId"] = ids[0]
        if not (word_id and phrase_id):
            self._state["settings"]["includeNotebook"] = False
        self._emit_changed()
        self.goalsChanged.emit()

    def _sanitize_session(self) -> None:
        session = self._state.get("session")
        if not session:
            return
        valid_ids = [item for item in session["ids"] if item in self._entries_by_id]
        if not valid_ids:
            self._state["session"] = None
            return
        session["ids"] = valid_ids
        session["position"] = min(session["position"], len(valid_ids))
        if session["position"] < len(valid_ids) and session.get("result") and session["position"] == 0:
            pass

    def _all_decks(self) -> list[dict[str, Any]]:
        if "decks" in self._cache:
            return self._cache["decks"]
        result = []
        progress = self._state["progress"]
        today = _day_key()
        chapter_size = max(5, min(100, self.chapterSize))
        for key, meta in DECK_META.items():
            entries = self._vocabulary.get(key, [])
            learned = sum(1 for entry in entries if isinstance(entry, dict) and _is_mastered(progress.get(entry.get("id"))))
            studied = sum(1 for entry in entries if isinstance(entry, dict) and entry.get("id") in progress)
            result.append({**meta, "id": key, "deckKey": key, "goal": self._state["dailyGoals"][key],
                           "favorite": key in self._state.get("favoriteDecks", []),
                           "total": len(entries), "studied": studied, "learned": learned,
                           "chapterCount": max(1, (len(entries) + chapter_size - 1) // chapter_size),
                           "lastChapter": max(0, _safe_int(self._state.get("lastChapters", {}).get(key), 0, 0, 100000)),
                           "unlearned": max(0, len(entries) - learned), "custom": False})
        for book in self._state["customBooks"]:
            entries = book["entries"]
            learned = sum(1 for entry in entries if _is_mastered(progress.get(entry.get("id"))))
            studied = sum(1 for entry in entries if entry.get("id") in progress)
            result.append({"id": book["id"], "deckKey": book["id"], "name": book["name"], "exam": "自定义", "type": "custom",
                           "short": "CUSTOM", "tag": "自定义词书", "color": "green", "description": "导入的自定义单词书。",
                           "goal": self._state.get("customGoals", {}).get(book["id"], 20), "total": len(entries),
                           "studied": studied, "learned": learned,
                           "chapterCount": max(1, (len(entries) + chapter_size - 1) // chapter_size),
                           "lastChapter": max(0, _safe_int(self._state.get("lastChapters", {}).get(book["id"]), 0, 0, 100000)),
                           "unlearned": len(entries) - learned, "custom": True})
        self._cache["decks"] = result
        return result

    def _selected_decks(self) -> list[dict[str, Any]]:
        all_decks = self._all_decks()
        wanted = [str(item_id) for item_id in self._state.get("selectedDeckIds", [])]
        selected = [deck for item_id in wanted for deck in all_decks if deck["id"] == item_id]
        if not selected:
            selected = [deck for deck in all_decks if deck["id"] == self._state.get("selectedDeckId")]
        if not selected and all_decks:
            selected = [all_decks[0]]
        return selected

    def _selected_deck(self) -> dict[str, Any] | None:
        decks = self._selected_decks()
        return decks[0] if decks else None

    def _deck_entries(self, deck: dict[str, Any]) -> list[dict[str, Any]]:
        if deck.get("custom"):
            book = next((item for item in self._state["customBooks"] if item["id"] == deck["id"]), None)
            return [self._entries_by_id[item["id"]] for item in book["entries"] if item["id"] in self._entries_by_id] if book else []
        return [self._entries_by_id[item["id"]] for item in self._vocabulary.get(deck["id"], [])
                if isinstance(item, dict) and item.get("id") in self._entries_by_id]

    def _selected_entries(self) -> list[dict[str, Any]]:
        if "selected_entries" in self._cache:
            return self._cache["selected_entries"]
        entries: list[dict[str, Any]] = []
        seen: set[str] = set()
        for deck in self._selected_decks():
            for entry in self._deck_entries(deck):
                key = _normalise_answer(entry.get("word", ""))
                if not key or key in seen:
                    continue
                seen.add(key)
                entries.append(entry)
        self._cache["selected_entries"] = entries
        return entries

    def _chapter_limit(self, entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
        if not self.chapterMode:
            return entries
        size = max(5, min(100, self.chapterSize))
        return entries[:size]

    def _notebook_entries(self) -> list[dict[str, Any]]:
        entries: list[dict[str, Any]] = []
        seen: set[str] = set()
        for item in self._state.get("notebook", []):
            entry = self._entries_by_id.get(str(item.get("id", "")))
            if not entry:
                continue
            key = _normalise_answer(entry.get("word", ""))
            if not key or key in seen:
                continue
            seen.add(key)
            entries.append(entry)
        return entries

    def _relearn_entries(self) -> list[dict[str, Any]]:
        entries: list[dict[str, Any]] = []
        seen: set[str] = set()
        for item in self._state.get("notebook", []):
            if not item.get("relearn"):
                continue
            entry = self._entries_by_id.get(str(item.get("id", "")))
            if not entry:
                continue
            key = _normalise_answer(entry.get("word", ""))
            if not key or key in seen:
                continue
            seen.add(key)
            entries.append(entry)
        return entries

    def _session_entry(self) -> dict[str, Any] | None:
        session = self._state.get("session")
        if not session or session["position"] >= len(session["ids"]):
            return None
        return self._entries_by_id.get(session["ids"][session["position"]])

    def _today_new(self, entries: list[dict[str, Any]] | None = None) -> int:
        groups: list[list[str]] = []
        if entries is None:
            groups = list(self._ids_by_word.values())
        else:
            seen: set[str] = set()
            for entry in entries:
                key = _normalise_answer(entry.get("word", ""))
                if key and key not in seen:
                    seen.add(key)
                    groups.append(self._ids_by_word.get(key, [str(entry.get("id", ""))]))
        return sum(1 for ids in groups
                   if any(isinstance(self._state["progress"].get(entry_id), dict)
                          and _day_key(self._state["progress"][entry_id].get("firstSeenAt")) == _day_key()
                          for entry_id in ids))

    def _due_entries(self, entries: list[dict[str, Any]] | None = None) -> list[dict[str, Any]]:
        entries = entries if entries is not None else list(self._entries_by_id.values())
        now = _now_ms()
        due = [entry for entry in entries if (record := self._state["progress"].get(entry["id"]))
               and isinstance(record, dict) and isinstance(record.get("nextReviewAt"), (int, float)) and record["nextReviewAt"] <= now]
        return sorted(due, key=lambda entry: self._state["progress"][entry["id"]]["nextReviewAt"])

    def _stats(self) -> dict[str, Any]:
        attempts = self._state["attempts"]
        dates = {_day_key(item.get("at")) for item in attempts}
        today = date.today()
        streak = 0
        cursor = today if today.isoformat() in dates else today - timedelta(days=1)
        while cursor.isoformat() in dates:
            streak += 1
            cursor -= timedelta(days=1)

        # A word counts once per calendar day. Repeating it on the same day
        # does not inflate the total; seeing it again on another day counts
        # again. Shared deck/notebook IDs are folded by normalized headword.
        word_days: set[tuple[str, str]] = set()
        day_strings = [(today - timedelta(days=offset)).isoformat() for offset in range(7)]
        per_day: dict[str, set[str]] = {day: set() for day in day_strings}
        for item in attempts:
            if item.get("skipped"):
                continue
            entry = self._entries_by_id.get(item.get("id"), {})
            word_key = _normalise_answer(entry.get("word", "")) or str(item.get("id", ""))
            day_key = _day_key(item.get("at"))
            word_days.add((word_key, day_key))

        # The weekly chart follows the same definition as the home page's
        # "今日新词": a word is counted on the day it was first learned, and
        # repeated reviews do not add another unit.
        # The weekly chart is global: every word and phrase from every
        # wordbook counts on its first-learning day, independent of the
        # currently selected study decks.
        for key, ids in self._ids_by_word.items():
            first_seen = [self._state["progress"][entry_id].get("firstSeenAt")
                          for entry_id in ids if isinstance(self._state["progress"].get(entry_id), dict)]
            if not first_seen:
                continue
            day_key = _day_key(min(first_seen))
            if day_key in per_day:
                per_day[day_key].add(key)
        week = [len(per_day[(today - timedelta(days=offset)).isoformat()]) for offset in range(6, -1, -1)]
        month_days = [(today - timedelta(days=offset)).isoformat() for offset in range(29, -1, -1)]
        month_counts: dict[str, set[str]] = {day: set() for day in month_days}
        for key, ids in self._ids_by_word.items():
            first_seen = [self._state["progress"][entry_id].get("firstSeenAt")
                          for entry_id in ids if isinstance(self._state["progress"].get(entry_id), dict)]
            if not first_seen:
                continue
            day_key = _day_key(min(first_seen))
            if day_key in month_counts:
                month_counts[day_key].add(key)
        month = [len(month_counts[day]) for day in month_days]
        learned = sum(1 for ids in self._ids_by_word.values()
                      if any(_is_mastered(self._state["progress"].get(entry_id)) for entry_id in ids))
        return {"learned": learned, "streak": streak, "reviews": len(word_days), "week": week,
                "month": month,
                "accuracy": round(100 * sum(bool(item["correct"]) for item in attempts) / len(attempts)) if attempts else 0,
                "right": sum(bool(item["correct"]) for item in attempts)}

    # QML properties share a notifier to keep state mutation and views in sync.
    @Property("QVariantList", notify=stateChanged)
    def decks(self):
        return self._all_decks()

    @Property("QVariantList", notify=stateChanged)
    def statsDecks(self):
        self._sanitize_stats_decks()
        by_id = {str(deck["id"]): deck for deck in self._all_decks()}
        return [by_id[item] for item in self._state.get("statsDeckIds", []) if item in by_id][:5]

    @Property("QVariantList", notify=stateChanged)
    def statsDeckIds(self):
        self._sanitize_stats_decks()
        return list(self._state.get("statsDeckIds", []))[:5]

    @Property("QVariantList", notify=stateChanged)
    def recentDecks(self):
        by_id = {str(deck["id"]): deck for deck in self._all_decks()}
        return [by_id[item] for item in self._state.get("recentDecks", []) if item in by_id][:4]

    @Property("QVariantList", notify=stateChanged)
    def deckEntries(self):
        deck = self._selected_deck()
        if not deck:
            return []
        cache_key = f"deck_entries:{deck['id']}"
        if cache_key in self._cache:
            return self._cache[cache_key]
        result = []
        for entry in self._deck_entries(deck):
            item = dict(entry)
            item["studied"] = item["id"] in self._state["progress"]
            item["mastered"] = _is_mastered(self._state["progress"].get(item["id"]))
            result.append(item)
        self._cache[cache_key] = result
        return result

    @Property(str, notify=stateChanged)
    def deckName(self):
        deck = self._selected_deck()
        return str(deck.get("name", "")) if deck else "词库"

    @Property(int, notify=stateChanged)
    def deckCount(self):
        deck = self._selected_deck()
        return len(self._deck_entries(deck)) if deck else 0

    @Property(bool, notify=stateChanged)
    def selectedDeckCustom(self):
        deck = self._selected_deck()
        return bool(deck and deck.get("custom"))

    @Property(str, notify=stateChanged)
    def selectedDeckId(self):
        return self._state["selectedDeckId"]

    @Property(str, notify=stateChanged)
    def selectedDeckName(self):
        deck = self._selected_deck()
        return str(deck.get("name", "")) if deck else ""

    @Property(int, notify=stateChanged)
    def sessionChapter(self):
        session = self._state.get("session") or {}
        if session.get("kind") == "chapter":
            return _safe_int(session.get("chapterIndex"), 0, 0, 100000)
        return -1

    @Property("QVariantList", notify=stateChanged)
    def selectedDeckIds(self):
        return list(self._state.get("selectedDeckIds", []))

    @Property(str, notify=stateChanged)
    def selectedWordDeckId(self):
        for deck in self._selected_decks():
            if deck.get("type") != "phrases":
                return str(deck["id"])
        return ""

    @Property(str, notify=stateChanged)
    def selectedPhraseDeckId(self):
        for deck in self._selected_decks():
            if deck.get("type") == "phrases":
                return str(deck["id"])
        return ""

    @Slot(str)
    def setWordDeck(self, deck_id: str):
        if not deck_id:
            phrase_id = self.selectedPhraseDeckId
            if phrase_id:
                self._apply_deck_selection("", phrase_id)
            return
        deck = next((item for item in self._all_decks() if item["id"] == deck_id), None)
        if not deck or deck.get("type") == "phrases":
            return
        phrase_id = self.selectedPhraseDeckId
        self._apply_deck_selection(deck_id, phrase_id)

    @Slot(str)
    def setPhraseDeck(self, deck_id: str):
        if deck_id:
            deck = next((item for item in self._all_decks() if item["id"] == deck_id), None)
            if not deck or deck.get("type") != "phrases":
                return
        word_id = self.selectedWordDeckId
        self._apply_deck_selection(word_id, deck_id)

    @Property(str, notify=stateChanged)
    def page(self):
        return self._page

    @Property(str, notify=stateChanged)
    def mode(self):
        return self._state["mode"]

    @Property(bool, notify=stateChanged)
    def choiceAvailable(self):
        entries = list(self._selected_entries())
        if self._state.get("settings", {}).get("includeNotebook", False):
            entries.extend(self._notebook_entries())
        return bool(entries)

    @Property(str, notify=stateChanged)
    def currentMode(self):
        return self._state["mode"]

    @Property("QVariant", notify=stateChanged)
    def current(self):
        return self._session_entry()

    @Property(int, notify=stateChanged)
    def currentOccurrence(self):
        """How many times this word has appeared in the queue up to now."""
        session = self._state.get("session") or {}
        ids = session.get("ids") or []
        position = _safe_int(session.get("position"), 0, 0, 10000)
        if position < 0 or position >= len(ids):
            return 0
        return ids[:position + 1].count(ids[position])

    @Property(str, notify=answerChanged)
    def answer(self):
        session = self._state.get("session") or {}
        return session.get("answer", "")

    @Property("QVariant", notify=stateChanged)
    def result(self):
        session = self._state.get("session") or {}
        return session.get("result")

    @Property(bool, notify=stateChanged)
    def retrying(self):
        session = self._state.get("session") or {}
        return bool(session.get("retrying"))

    @Property("QVariant", notify=stateChanged)
    def retryResult(self):
        session = self._state.get("session") or {}
        return session.get("retryResult")

    @Property(bool, notify=stateChanged)
    def retryWrong(self):
        session = self._state.get("session") or {}
        return bool(session.get("retryWrong"))

    @Property(int, notify=stateChanged)
    def queuePosition(self):
        session = self._state.get("session")
        return session["position"] + 1 if session and session["position"] < len(session["ids"]) else 0

    @Property(int, notify=stateChanged)
    def queueTotal(self):
        return len((self._state.get("session") or {}).get("ids", []))

    @Property(int, notify=stateChanged)
    def sessionRight(self):
        session = self._state.get("session") or {}
        return int(session.get("right", 0))

    @Property(int, notify=stateChanged)
    def sessionTotal(self):
        session = self._state.get("session") or {}
        if not session:
            return 0
        return len(session.get("ids", []))

    @Property("QVariantList", notify=stateChanged)
    def notebook(self):
        return list(self._state["notebook"])

    @Property("QVariantList", notify=stateChanged)
    def masteredWords(self):
        if "mastered_words" in self._cache:
            return self._cache["mastered_words"]
        result = []
        for word_key, ids in self._ids_by_word.items():
            chosen_id = ""
            record = None
            for entry_id in ids:
                candidate = self._state["progress"].get(entry_id)
                if _is_mastered(candidate):
                    chosen_id = entry_id
                    record = candidate
                    break
            if not chosen_id or not isinstance(record, dict):
                continue
            entry = self._entries_by_id.get(chosen_id)
            if not entry:
                continue
            item = dict(entry)
            item["correctCount"] = _safe_int(record.get("correctCount"), 0, 0, 1_000_000)
            item["masteredAt"] = _safe_int(record.get("lastSeenAt"), 0, 0, 2**63 - 1)
            item["deckName"] = DECK_META.get(str(entry.get("deckKey", "")), {}).get("name", "")
            result.append(item)
        result.sort(key=lambda item: item.get("masteredAt", 0), reverse=True)
        self._cache["mastered_words"] = result
        return result

    @Property(int, notify=stateChanged)
    def todayNew(self):
        if "today_new" not in self._cache:
            # Daily total across every wordbook, not just the selected deck.
            self._cache["today_new"] = self._today_new()
        return self._cache["today_new"]

    @Property(int, notify=stateChanged)
    def todayPlanNew(self):
        """New words learned today within the currently selected study scope."""
        if "today_plan_new" not in self._cache:
            self._cache["today_plan_new"] = self._today_new(self._selected_entries())
        return self._cache["today_plan_new"]

    @Property(int, notify=goalsChanged)
    def dailyGoal(self):
        return sum(self._deck_goal(deck_id) for deck_id in self._state.get("selectedDeckIds", []))

    @Property(int, notify=goalsChanged)
    def goalPerDeck(self):
        ids = self._state.get("selectedDeckIds", [])
        if not ids:
            return 20
        return self._deck_goal(str(ids[0]))

    def _deck_goal(self, deck_id: str) -> int:
        if deck_id in DEFAULT_DAILY_GOALS:
            return _safe_int(self._state["dailyGoals"].get(deck_id), 20, 1, 200)
        if any(book.get("id") == deck_id for book in self._state.get("customBooks", [])):
            return _safe_int(self._state.get("customGoals", {}).get(deck_id), 20, 1, 200)
        return 20

    @Property(int, notify=stateChanged)
    def dueCount(self):
        if "due_count" not in self._cache:
            self._cache["due_count"] = len(self._due_entries(self._selected_entries()))
        return self._cache["due_count"]

    @Property("QVariantMap", notify=stateChanged)
    def stats(self):
        if "stats" not in self._cache:
            self._cache["stats"] = self._stats()
        return self._cache["stats"]

    @Property(int, notify=studyTimeChanged)
    def studySeconds(self):
        return _safe_int(self._state.get("studySeconds"), 0, 0, 10**12)

    @Property(bool, notify=stateChanged)
    def welcomeSeen(self):
        return bool(self._state.get("settings", {}).get("welcomeSeen", False))

    @Property(bool, notify=stateChanged)
    def welcomePending(self):
        settings = self._state.get("settings", {})
        return (not bool(settings.get("welcomeSeen", False))
                or settings.get("welcomeVersion", "") != APP_VERSION)

    @Slot(bool)
    def setWelcomeSeen(self, seen: bool):
        self._state.setdefault("settings", {})["welcomeSeen"] = bool(seen)
        self._state["settings"]["welcomeVersion"] = APP_VERSION if seen else ""
        try:
            self._save_state()
        except OSError:
            pass
        self.stateChanged.emit()

    @Slot(int)
    def addStudyTime(self, seconds: int):
        amount = max(0, min(60, _safe_int(seconds, 0, 0, 60)))
        if not amount:
            return
        self._state["studySeconds"] = _safe_int(self._state.get("studySeconds"), 0, 0, 10**12) + amount
        self._study_pending += amount
        if self._study_pending >= 20:
            self.flushStudyTime()

    def _sound_asset(self, style: str) -> Path:
        base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
        return base / "assets" / ("bubble.mp3" if style == "bubble" else "key.wav")

    def _prepare_input_sounds(self) -> None:
        try:
            from PySide6.QtMultimedia import QSoundEffect
        except (ImportError, RuntimeError):
            return
        for style, copies in (("click", 3), ("bubble", 2)):
            path = self._sound_asset(style)
            if not path.exists():
                continue
            effects = []
            for _ in range(copies):
                effect = QSoundEffect(self)
                effect.setSource(QUrl.fromLocalFile(str(path)))
                effect.setVolume(0.62)
                effects.append(effect)
            self._sound_pool[style] = effects

    @Slot()
    def playInputSound(self):
        if not self.inputSound:
            return
        effects = self._sound_pool.get(self.inputSoundStyle, [])
        if effects:
            from PySide6.QtMultimedia import QSoundEffect
            effect = effects[self._sound_index % len(effects)]
            self._sound_index += 1
            if effect.status() != QSoundEffect.Error:
                effect.play()
                return
        path = self._sound_asset(self.inputSoundStyle)
        if not path.exists():
            return
        if os.name == "nt" and self.inputSoundStyle == "click":
            try:
                import winsound
                winsound.PlaySound(str(path), winsound.SND_FILENAME | winsound.SND_ASYNC | winsound.SND_NODEFAULT)
            except (ImportError, OSError, RuntimeError):
                pass

    @Slot()
    def flushStudyTime(self):
        if self._study_pending <= 0:
            return
        self._study_pending = 0
        try:
            self._save_state()
        except OSError:
            pass
        self.studyTimeChanged.emit()

    @Property("QVariantMap", notify=stateChanged)
    def settings(self):
        return dict(self._state["settings"])

    @Property(bool, notify=stateChanged)
    def hasSession(self):
        return self._state.get("session") is not None and self._session_entry() is not None

    @Property(int, notify=stateChanged)
    def chapterSize(self):
        return _safe_int(self._state.get("settings", {}).get("chapterSize"), 20, 5, 100)

    @Property(bool, notify=stateChanged)
    def chapterMode(self):
        return bool(self._state.get("settings", {}).get("chapterMode", True))

    def _chapter_size(self) -> int:
        return max(5, min(100, self.chapterSize))

    def _chapter_count_for(self, deck: dict[str, Any] | None) -> int:
        if not deck:
            return 0
        entries = self._deck_entries(deck)
        size = self._chapter_size()
        return max(1, (len(entries) + size - 1) // size) if entries else 0

    @Property(int, notify=stateChanged)
    def chapterCount(self):
        return self._chapter_count_for(self._selected_deck())

    @Property(int, notify=stateChanged)
    def currentChapter(self):
        deck = self._selected_deck()
        if not deck:
            return 0
        count = self._chapter_count_for(deck)
        last = _safe_int(self._state.get("lastChapters", {}).get(deck["id"]), 0, 0, 100000)
        return min(max(0, last), max(0, count - 1))

    @Property("QVariantList", notify=stateChanged)
    def chapterRows(self):
        deck = self._selected_deck()
        if not deck:
            return []
        entries = self._deck_entries(deck)
        size = self._chapter_size()
        last = self.currentChapter
        progress = self._state["progress"]
        rows = []
        for start in range(0, len(entries), size):
            index = start // size
            chunk = entries[start:start + size]
            studied = sum(1 for entry in chunk if entry.get("id") in progress)
            mastered = sum(1 for entry in chunk if _is_mastered(progress.get(entry.get("id"))))
            if studied >= len(chunk) and len(chunk) > 0:
                status = "done"
            elif studied > 0 or index == last:
                status = "active"
            else:
                status = "new"
            rows.append({"index": index, "label": f"第 {index + 1} 章",
                         "total": len(chunk), "studied": studied, "mastered": mastered,
                         "current": index == last, "status": status,
                         "percent": int(round(studied * 100 / max(1, len(chunk))))})
        return rows


    @Property(str, notify=stateChanged)
    def studyScope(self):
        scope = self._state.get("settings", {}).get("studyScope", "mix")
        return scope if scope in {"mix", "new", "review"} else "mix"

    @Property(bool, notify=stateChanged)
    def inputSound(self):
        return bool(self._state.get("settings", {}).get("inputSound", True))

    @Property(bool, notify=stateChanged)
    def loopSession(self):
        return bool(self._state.get("settings", {}).get("loopSession", False))

    @Slot()
    def toggleLoop(self):
        self._state.setdefault("settings", {})["loopSession"] = not self.loopSession
        self._emit_changed()
        self._status("单词循环已开启" if self.loopSession else "单词循环已关闭")

    @Property(str, notify=stateChanged)
    def inputSoundStyle(self):
        style = self._state.get("settings", {}).get("inputSoundStyle", "click")
        return style if style in {"click", "bubble"} else "click"

    @Slot(str)
    def setInputSoundStyle(self, style: str):
        self._state.setdefault("settings", {})["inputSoundStyle"] = "bubble" if style == "bubble" else "click"
        self._emit_changed()

    @Property(float, notify=stateChanged)
    def speechRate(self):
        return float(self._state.get("settings", {}).get("speechRate", 0.0))

    @Property(int, notify=stateChanged)
    def sessionWpm(self):
        session = self._state.get("session") or {}
        started = _safe_int(session.get("startedAt"), _now_ms(), 0, 2**63 - 1)
        elapsed = max(1, _now_ms() - started)
        typed = _safe_int(session.get("typedLetters"), 0, 0, 10_000_000)
        return int(round((typed / 5.0) / (elapsed / 60000.0))) if typed else 0

    @Property(int, notify=stateChanged)
    def sessionAccuracy(self):
        session = self._state.get("session") or {}
        done = _safe_int(session.get("completed"), 0, 0, 100000)
        right = _safe_int(session.get("right"), 0, 0, 100000)
        return int(round(right * 100.0 / done)) if done else 0

    @Property(int, notify=stateChanged)
    def sessionTyped(self):
        session = self._state.get("session") or {}
        return _safe_int(session.get("typedLetters"), 0, 0, 10_000_000)

    @Property(int, notify=stateChanged)
    def sessionElapsed(self):
        session = self._state.get("session") or {}
        started = _safe_int(session.get("startedAt"), _now_ms(), 0, 2**63 - 1)
        return max(0, int((_now_ms() - started) / 1000))

    @Property("QVariantList", notify=stateChanged)
    def reviewForecast(self):
        today = date.today()
        buckets = [0] * 7
        for entry in self._selected_entries():
            record = self._state["progress"].get(entry.get("id"))
            if not isinstance(record, dict):
                continue
            due = record.get("nextReviewAt")
            if not isinstance(due, (int, float)):
                continue
            day = (datetime.fromtimestamp(float(due) / 1000).date() - today).days
            if 0 <= day < 7:
                buckets[day] += 1
        labels = ["今天", "明天", "后天", "第4天", "第5天", "第6天", "第7天"]
        return [{"label": labels[i], "count": buckets[i]} for i in range(7)]

    @Slot(str)
    def setStudyScope(self, scope: str):
        if scope not in {"mix", "new", "review"}:
            return
        self._state.setdefault("settings", {})["studyScope"] = scope
        self._emit_changed()

    @Slot(int)
    def setChapterSize(self, amount: int):
        self._state.setdefault("settings", {})["chapterSize"] = _safe_int(amount, 20, 5, 100)
        self._emit_changed()

    @staticmethod
    def _normalise_shortcut(value: Any) -> str:
        text = str(value or "").strip()
        if re.fullmatch(r"(?:(?:Ctrl|Alt|Shift)\+){1,3}(?:[A-Za-z]|F(?:[1-9]|1[0-2]))", text):
            return text
        return "Alt+F"

    @Property(str, notify=stateChanged)
    def forgotShortcut(self):
        return self._normalise_shortcut(self._state.get("settings", {}).get("forgotShortcut", "Alt+F"))

    @Slot(str)
    def setForgotShortcut(self, shortcut: str):
        self._state.setdefault("settings", {})["forgotShortcut"] = self._normalise_shortcut(shortcut)
        self._emit_changed()

    @Slot(float)
    def setSpeechRate(self, rate: float):
        self._state.setdefault("settings", {})["speechRate"] = max(-0.4, min(0.4, float(rate)))
        self._apply_voice_accent()
        self._emit_changed()

    @Slot(str)
    def toggleDeckFavorite(self, deck_id: str):
        favorites = list(self._state.get("favoriteDecks", []))
        if deck_id in favorites:
            favorites.remove(deck_id)
        elif deck_id in DECK_META:
            favorites.append(deck_id)
        self._state["favoriteDecks"] = favorites
        self._emit_changed()

    @Slot(str, result=bool)
    def isDeckFavorite(self, deck_id: str) -> bool:
        return deck_id in self._state.get("favoriteDecks", [])

    def _apply_voice_rate(self):
        if self._tts is None:
            return
        try:
            self._tts.setRate(self.speechRate)
        except (AttributeError, RuntimeError):
            pass

    @Property(str, notify=stateChanged)
    def voiceAccent(self):
        return "uk" if self._state.get("settings", {}).get("voiceAccent") == "uk" else "us"

    @Property(bool, notify=stateChanged)
    def britishVoiceAvailable(self):
        try:
            import winreg
            paths = (
                r"SOFTWARE\Microsoft\Speech\Voices\Tokens",
                r"SOFTWARE\WOW6432Node\Microsoft\Speech\Voices\Tokens",
                r"SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens",
            )
            for path in paths:
                try:
                    root = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path)
                except OSError:
                    continue
                for index in range(winreg.QueryInfoKey(root)[0]):
                    token = winreg.EnumKey(root, index)
                    try:
                        attrs = winreg.OpenKey(root, token + r"\Attributes")
                        language, _ = winreg.QueryValueEx(attrs, "Language")
                    except OSError:
                        continue
                    if int(language) == 0x809:
                        return True
        except (ImportError, OSError, ValueError):
            return False
        return False

    @Property(str, notify=stateChanged)
    def voiceAccentStatus(self):
        if self.voiceAccent == "uk" and not self.britishVoiceAvailable:
            return "当前 Windows 未安装英式语音，英式会回退美式。"
        return "英式语音" if self.voiceAccent == "uk" else "美式语音"

    @Slot(str)
    def setVoiceAccent(self, accent: str):
        self._state.setdefault("settings", {})["voiceAccent"] = "uk" if accent == "uk" else "us"
        try:
            self._save_state()
        except OSError:
            pass
        self._apply_voice_accent()
        self.stateChanged.emit()

    def _apply_voice_accent(self):
        if self._tts is None:
            return
        try:
            voices = list(self._tts.availableVoices())
            target = "en_gb" if self.voiceAccent == "uk" else "en_us"
            exact = [voice for voice in voices
                     if str(voice.locale().name()).lower().replace("-", "_").startswith(target)]
            if exact:
                self._tts.setVoice(exact[0])
                self._qt_voice_ready = True
            else:
                self._qt_voice_ready = False
            self._apply_voice_rate()
        except (AttributeError, RuntimeError):
            self._qt_voice_ready = False

    @Property("QVariantList", notify=stateChanged)
    def choices(self):
        session = self._state.get("session") or {}
        return self._ensure_choices(session)

    def _ensure_choices(self, session: dict[str, Any]) -> list[dict[str, Any]]:
        choices = session.get("choices")
        if isinstance(choices, list):
            return choices
        current = self._session_entry()
        if not current:
            return []
        is_phrase = bool(current.get("phrase"))
        pool = [entry for entry in self._selected_entries()
                if bool(entry.get("phrase")) == is_phrase]
        if self._state.get("settings", {}).get("includeNotebook", False):
            pool.extend(entry for entry in self._notebook_entries()
                        if bool(entry.get("phrase")) == is_phrase)
        if len(pool) < 4:
            pool.extend(entry for entry in self._entries_by_id.values()
                        if bool(entry.get("phrase")) == is_phrase
                        and entry["id"] not in {item["id"] for item in pool})
        if not pool:
            pool = list(self._entries_by_id.values())
        alternatives = [entry for entry in pool if entry["id"] != current["id"] and entry.get("meaning") != current.get("meaning")]
        random.shuffle(alternatives)
        picked = alternatives[:3] + [current]
        random.shuffle(picked)
        choices = [{"id": entry["id"], "text": entry.get("meaning", ""), "meaning": entry.get("meaning", ""), "correct": entry["id"] == current["id"]} for entry in picked]
        session["choices"] = choices
        return choices

    @Property(str, notify=statusMessageChanged)
    def statusMessage(self):
        return self._status_message

    @Property(str, notify=stateChanged)
    def revealRetryHint(self):
        session = self._state.get("session") or {}
        return str(session.get("revealHint", ""))

    @Property(bool, notify=stateChanged)
    def sessionComplete(self):
        session = self._state.get("session")
        return bool(session and session["position"] >= len(session["ids"]))

    @Property(bool, notify=stateChanged)
    def canGoPrevious(self):
        session = self._state.get("session") or {}
        if session.get("retrying") or session.get("retryResult") is not None:
            return False
        return bool(self._history)

    @Slot(str)
    def selectDeck(self, deck_id: str):
        if any(deck["id"] == deck_id for deck in self._all_decks()):
            self._clear_session_for_deck_change()
            self._state["selectedDeckId"] = deck_id
            self._state["selectedDeckIds"] = [deck_id]
            self._emit_changed()
            self.goalsChanged.emit()

    @Slot(str)
    def selectStatsDeck(self, deck_id: str):
        if not any(deck["id"] == deck_id for deck in self._all_decks()):
            return
        self._sanitize_stats_decks()
        selected = list(self._state.get("statsDeckIds", []))
        if deck_id in selected:
            if len(selected) <= 1:
                self._status("至少保留一本词书")
                return
            selected.remove(deck_id)
        else:
            if len(selected) >= 5:
                self._status("最多选择 5 本词书")
                return
            selected.append(deck_id)
        self._state["statsDeckIds"] = selected[:5]
        self._emit_changed()

    @Slot(str)
    def openDeck(self, deck_id: str):
        if any(deck["id"] == deck_id for deck in self._all_decks()):
            self._clear_session_for_deck_change()
            self._state["selectedDeckId"] = deck_id
            self._state["selectedDeckIds"] = [deck_id]
            self._page = "deck"
            self._emit_changed()
            self.goalsChanged.emit()

    @Slot(str)
    def toggleDeckSelection(self, deck_id: str):
        if not any(deck["id"] == deck_id for deck in self._all_decks()):
            return
        ids = [str(item) for item in self._state.get("selectedDeckIds", [])]
        if deck_id in ids:
            if len(ids) <= 1:
                self._status("至少保留一本词书")
                return
            ids = [item for item in ids if item != deck_id]
        else:
            ids.append(deck_id)
        self._clear_session_for_deck_change()
        self._state["selectedDeckIds"] = ids
        self._state["selectedDeckId"] = ids[0]
        self._emit_changed()
        self.goalsChanged.emit()

    @Slot(str, result=bool)
    def isDeckSelected(self, deck_id: str) -> bool:
        return deck_id in self._state.get("selectedDeckIds", [])

    @Slot(int)
    def startStudyChapter(self, index: int):
        deck_id = str(self._state.get("selectedDeckId", ""))
        recents = [item for item in self._state.get("recentDecks", []) if item != deck_id]
        if deck_id:
            recents.insert(0, deck_id)
        self._state["recentDecks"] = recents[:8]
        self.startChapter(index)

    @Slot()
    def continueStudy(self):
        session = self._state.get("session")
        if session and session.get("ids") and session.get("position", 0) < len(session["ids"]):
            self.continueSession()
            return
        self.startStudyChapter(self.currentChapter)

    @Slot(int)
    def startChapter(self, index: int):
        deck = self._selected_deck()
        if not deck:
            self._status("请先选择一本词书")
            return
        entries = self._deck_entries(deck)
        if not entries:
            self._status("这本词书还没有词条")
            return
        size = self._chapter_size()
        count = max(1, (len(entries) + size - 1) // size)
        index = max(0, min(count - 1, int(index)))
        chunk = entries[index * size:(index + 1) * size]
        if self.studyScope == "new":
            chunk = [entry for entry in chunk if entry["id"] not in self._state["progress"]]
        elif self.studyScope == "review":
            now = _now_ms()
            chunk = [entry for entry in chunk
                     if isinstance(self._state["progress"].get(entry["id"]), dict)
                     and _safe_int(self._state["progress"][entry["id"]].get("nextReviewAt"), 0, 0, 2**63 - 1) <= now]
        queue: list[dict[str, Any]] = []
        seen_words: set[str] = set()
        for entry in chunk:
            key = _normalise_answer(entry.get("word", ""))
            if not key or key in seen_words:
                continue
            seen_words.add(key)
            queue.append(entry)
        if not queue:
            self._status("这一章还没有词条")
            return
        self._state.setdefault("lastChapters", {})[deck["id"]] = index
        self._history.clear()
        self._state["session"] = {
            "deckKey": deck["id"], "deckKeys": [deck["id"]],
            "ids": [entry["id"] for entry in queue + queue],
            "kind": "chapter", "chapterIndex": index, "chapterDeck": deck["id"],
            "position": 0, "completed": 0, "answer": "", "result": None, "right": 0,
            "retrying": False, "retryResult": None, "retryWrong": False,
            "passes": 2, "typedLetters": 0, "startedAt": _now_ms(),
        }
        self._page = "practice"
        self.answerChanged.emit()
        self._emit_changed()
        self._speak_first_word(queue)

    @Slot()
    def resumeChapter(self):
        self.startChapter(self.currentChapter)

    @Slot(str)
    def startPlan(self, kind: str = "today"):
        if not self._selected_deck():
            self._status("请先选择一本词书")
            return
        if kind == "deck":
            self.startChapter(self.currentChapter)
            return
        entries = self._selected_entries()
        due = self._due_entries(entries) if self._state["settings"].get("spacedRepetition", True) else []
        learned_today = self._today_new(entries)
        new_limit = max(0, self.dailyGoal - learned_today)
        new = [entry for entry in entries if entry["id"] not in self._state["progress"]][:new_limit]
        notebook = (self._notebook_entries()
                    if self._state["settings"].get("includeNotebook", False)
                    else self._relearn_entries()) if kind == "today" else []
        scope = self.studyScope
        if kind == "random":
            candidates = list(entries)
            random.shuffle(candidates)
        elif kind == "deck":
            candidates = due + [entry for entry in entries if entry["id"] not in {item["id"] for item in due}]
        elif scope == "new":
            candidates = new
        elif scope == "review":
            candidates = due
        elif self._state.get("settings", {}).get("spacedRepetition", True) is False:
            candidates = notebook + new
        else:
            candidates = due + notebook + [entry for entry in new if entry["id"] not in {item["id"] for item in due}]
        queue: list[dict[str, Any]] = []
        seen_words: set[str] = set()
        for entry in candidates:
            key = _normalise_answer(entry.get("word", ""))
            if not key or key in seen_words:
                continue
            seen_words.add(key)
            queue.append(entry)
        queue = self._chapter_limit(queue)
        # Every word is studied in two rounds per session.
        queue = queue + queue
        # Every deck supports spelling, choice and dictation modes.
        self._history.clear()
        deck_keys = [deck["id"] for deck in self._selected_decks()]
        self._state["session"] = {"deckKey": self._state["selectedDeckId"], "deckKeys": deck_keys,
                                   "ids": [entry["id"] for entry in queue],
                                   "kind": kind if kind in {"today", "deck", "random"} else "today", "position": 0,
                                   "completed": 0, "answer": "", "result": None, "right": 0,
                                   "retrying": False, "retryResult": None, "retryWrong": False,
                                   "passes": 2, "typedLetters": 0, "startedAt": _now_ms()}
        self._page = "practice"
        self.answerChanged.emit()
        self._emit_changed()
        self._speak_first_word(queue)
        if not queue:
            self._status("今日计划已完成，继续保持")

    @Slot()
    def startNextChapter(self):
        session = self._state.get("session") or {}
        if session.get("kind") == "chapter":
            deck = next((item for item in self._all_decks() if item["id"] == session.get("chapterDeck")), None)
            count = self.chapterCount if deck and deck["id"] == self._state.get("selectedDeckId") else 0
            next_index = _safe_int(session.get("chapterIndex"), 0, 0, 100000) + 1
            if count and next_index < count:
                self.startChapter(next_index)
                return
            self._status("已经是最后一章")
            return
        self.startPlan("today")

    @Slot()
    def startChapterDictation(self):
        session = self._state.get("session") or {}
        ids = []
        for entry_id in session.get("ids", []):
            if entry_id not in ids and entry_id in self._entries_by_id:
                ids.append(entry_id)
        if not ids:
            self._status("本章还没有可默写的单词")
            return
        entries = [self._entries_by_id[item] for item in ids]
        queue = self._chapter_limit(entries)
        queue = queue + queue
        self._state.setdefault("settings", {})["mode"] = "dictation"
        self._state["mode"] = "dictation"
        self._history.clear()
        self._state["session"] = {"deckKey": self._state["selectedDeckId"],
                                   "deckKeys": [deck["id"] for deck in self._selected_decks()],
                                   "ids": [entry["id"] for entry in queue],
                                   "kind": "dictation", "position": 0, "completed": 0, "answer": "", "result": None,
                                   "right": 0, "retrying": False, "retryResult": None, "retryWrong": False,
                                   "passes": 2, "typedLetters": 0, "startedAt": _now_ms()}
        self._page = "practice"
        self.answerChanged.emit()
        self._emit_changed()
        self._speak_first_word(queue)

    @Slot()
    def startRandom(self):
        self.startPlan("random")

    @Slot()
    def startReview(self):
        due = self._due_entries(self._selected_entries())
        if not due:
            self._status("今天没有到期的复习")
            return
        queue: list[dict[str, Any]] = []
        seen_words: set[str] = set()
        for entry in due:
            key = _normalise_answer(entry.get("word", ""))
            if key and key not in seen_words:
                seen_words.add(key)
                queue.append(entry)
        if not queue:
            self._status("今天没有到期的复习")
            return
        queue = self._chapter_limit(queue)
        queue = queue + queue
        self._history.clear()
        self._state["session"] = {
            "deckKey": self._state["selectedDeckId"],
            "deckKeys": [deck["id"] for deck in self._selected_decks()],
            "ids": [entry["id"] for entry in queue],
            "kind": "review", "position": 0, "completed": 0,
            "answer": "", "result": None, "right": 0,
            "retrying": False, "retryResult": None, "retryWrong": False,
            "passes": 2, "typedLetters": 0, "startedAt": _now_ms(),
        }
        self._page = "practice"
        self.answerChanged.emit()
        self._emit_changed()
        self._speak_first_word(queue)

    @Slot()
    def resetAllProgress(self):
        self._state["progress"] = {}
        self._state["attempts"] = []
        self._state["notebook"] = []
        self._state["favoriteDecks"] = []
        self._state["lastChapters"] = {}
        self._state["studySeconds"] = 0
        self._state["session"] = None
        self._state.setdefault("settings", {})["welcomeSeen"] = False
        self._history.clear()
        self._study_pending = 0
        self._page = "home"
        self._refresh_index()
        self._emit_changed()
        self.studyTimeChanged.emit()
        self._status("已清除所有学习记录")

    @Slot(str)
    def resetDeck(self, deck_id: str):
        deck = next((item for item in self._all_decks() if item["id"] == deck_id), None)
        if not deck:
            return
        entries = self._deck_entries(deck)
        word_keys = {_normalise_answer(entry.get("word", "")) for entry in entries}
        word_keys.discard("")
        target_ids: set[str] = set()
        for key in word_keys:
            target_ids.update(self._ids_by_word.get(key, []))
        for entry in entries:
            target_ids.add(entry["id"])
        for entry_id in target_ids:
            self._state["progress"].pop(entry_id, None)
        self._state.setdefault("lastChapters", {}).pop(deck_id, None)
        self._state["attempts"] = [item for item in self._state["attempts"] if item.get("id") not in target_ids]
        session = self._state.get("session")
        if session and (session.get("deckKey") == deck_id
                        or deck_id in (session.get("deckKeys") or [])
                        or target_ids.intersection(session.get("ids") or [])):
            self._state["session"] = None
        self._history.clear()
        self._emit_changed()
        self.goalsChanged.emit()
        self._status(f"已重置《{deck['name']}》，全部单词回到未学状态")

    @Slot(str)
    def deleteCustomBook(self, deck_id: str):
        book = next((item for item in self._state.get("customBooks", []) if item["id"] == deck_id), None)
        if not book:
            return
        entries = [self._entries_by_id[item["id"]] for item in book.get("entries", [])
                   if item.get("id") in self._entries_by_id]
        word_keys = {_normalise_answer(entry.get("word", "")) for entry in entries}
        word_keys.discard("")
        target_ids: set[str] = set(entry["id"] for entry in entries)
        for key in word_keys:
            target_ids.update(self._ids_by_word.get(key, []))
        for entry_id in target_ids:
            self._state["progress"].pop(entry_id, None)
        self._state["attempts"] = [item for item in self._state["attempts"] if item.get("id") not in target_ids]
        self._state["customBooks"] = [item for item in self._state["customBooks"] if item["id"] != deck_id]
        self._state.get("customGoals", {}).pop(deck_id, None)
        session = self._state.get("session")
        if session and (session.get("deckKey") == deck_id
                        or deck_id in (session.get("deckKeys") or [])
                        or target_ids.intersection(session.get("ids") or [])):
            self._state["session"] = None
        self._state["selectedDeckIds"] = [item for item in self._state.get("selectedDeckIds", []) if item != deck_id]
        self._history.clear()
        self._refresh_index()
        self._sanitize_deck_selection()
        self._page = "library"
        self._emit_changed()
        self.goalsChanged.emit()
        self._status(f"已删除《{book['name']}》")

    @Slot()
    def continueSession(self):
        session = self._state.get("session")
        if session and session["ids"] and session["position"] < len(session["ids"]):
            deck_keys = session.get("deckKeys")
            if isinstance(deck_keys, list) and deck_keys:
                valid = [str(item) for item in deck_keys if any(deck["id"] == item for deck in self._all_decks())]
                if valid:
                    self._state["selectedDeckIds"] = valid
                elif any(deck["id"] == session["deckKey"] for deck in self._all_decks()):
                    self._state["selectedDeckIds"] = [session["deckKey"]]
            elif any(deck["id"] == session["deckKey"] for deck in self._all_decks()):
                self._state["selectedDeckIds"] = [session["deckKey"]]
            self._state["selectedDeckId"] = session["deckKey"]
            self._page = "practice"
            self._emit_changed()
            current = self._session_entry()
            if current and self.currentMode == "spelling":
                self.speak(current.get("word", ""))
        else:
            self.startPlan("today")

    @Slot(str)
    def setMode(self, mode: str):
        if mode in {"spelling", "choice", "dictation"}:
            self._state["mode"] = mode
            session = self._state.get("session")
            if session:
                session["answer"] = ""
                session["result"] = None
                session["retrying"] = False
                session["retryResult"] = None
                session["retryWrong"] = False
                session.pop("choices", None)
            self.answerChanged.emit()
            self._emit_changed()

    @Slot()
    def hintFirstLetter(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or session.get("result") or self.currentMode != "spelling":
            return
        if _normalise_answer(session.get("answer")):
            return
        match = re.search(r"[A-Za-z]", str(current.get("word", "")))
        if not match:
            return
        session["answer"] = match.group(0)
        self.answerChanged.emit()

    @Slot(str)
    def setAnswer(self, answer: str):
        session = self._state.get("session")
        if session and session["position"] < len(session["ids"]) and not session.get("result"):
            raw = str(answer)[:500]
            current = self._session_entry() or {}
            target = str(current.get("word", ""))
            allow_space = " " in target
            allowed_letters = {character for character in target if character.isalpha()}
            allowed_marks = {character for character in target
                             if not character.isalpha() and character != " "}
            filtered = "".join(
                character for character in raw
                if (character.isalpha() and (character.isascii() or character in allowed_letters))
                or (character == " " and allow_space)
                or character in allowed_marks
            )
            filtered = re.sub(r" {2,}", " ", filtered)
            session["answer"] = filtered
            self.answerChanged.emit()

    @Slot()
    def submit(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or session.get("result") or session.get("retrying") or self.currentMode == "choice":
            return
        if not _normalise_answer(session.get("answer")):
            self._clear_invalid_result()
            return
        correct = _spelling_key(session.get("answer")) == _spelling_key(current["word"])
        self._finish_question(correct)

    def _clear_invalid_result(self):
        session = self._state.get("session") or {}
        result = session.get("result")
        if not isinstance(result, dict):
            return
        expected = str(result.get("expected", ""))
        skipped = bool(result.get("skipped"))
        answer = str(session.get("answer", ""))
        if expected and (skipped or _normalise_answer(answer)):
            return
        session["result"] = None
        session["retrying"] = False
        session["retryResult"] = None
        session["retryWrong"] = False
        self.answerChanged.emit()
        self._emit_changed()

    @Slot()
    def validateCurrentResult(self):
        self._clear_invalid_result()

    @Slot(str)
    def choose(self, entry_id: str):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or session.get("result") or session.get("retrying") or self.currentMode != "choice":
            return
        choice = next((item for item in self._ensure_choices(session) if item["id"] == entry_id), None)
        if not choice:
            return
        session["answer"] = entry_id
        self.answerChanged.emit()
        self._finish_question(entry_id == current["id"])

    def _finish_question(self, correct: bool, skipped: bool = False, revealed: bool = False) -> None:
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session:
            return
        at = _now_ms()
        session["retrying"] = False
        session["retryResult"] = None
        session["retryWrong"] = False
        word_key = _normalise_answer(current.get("word", ""))
        word_ids = self._ids_by_word.get(word_key, [current["id"]])
        self._history.append({
            "entryId": current["id"],
            "position": session["position"],
            "ids": list(session["ids"]),
            "completed": int(session.get("completed", 0)),
            "right": int(session.get("right", 0)),
            "progress": {entry_id: copy.deepcopy(self._state["progress"][entry_id])
                         for entry_id in word_ids if entry_id in self._state["progress"]},
            "attempts": len(self._state["attempts"]),
        })
        if len(self._history) > 30:
            del self._history[:-30]
        session["result"] = {"correct": bool(correct), "expected": current["word"],
                              "skipped": bool(skipped), "revealed": bool(revealed)}
        session["completed"] = int(session.get("completed", 0)) + 1
        if correct:
            session["right"] = int(session.get("right", 0)) + 1
        attempt = {"id": current["id"], "at": at, "correct": bool(correct), "skipped": bool(skipped),
                   "deckKey": current.get("deckKey", session.get("deckKey", "")), "mode": self.currentMode}
        self._state["attempts"].append(attempt)
        self._state["attempts"] = self._state["attempts"][-10000:]
        self._update_progress(current["id"], attempt)

        session["typedLetters"] = _safe_int(session.get("typedLetters"), 0, 0, 10_000_000) + \
            len(str(session.get("answer", ""))) if self.currentMode != "choice" else _safe_int(session.get("typedLetters"), 0, 0, 10_000_000)

        record = self._state["progress"].get(current["id"], {})
        session["result"]["correctCount"] = _safe_int(record.get("correctCount"), 0, 0, 1_000_000)
        session["result"]["mastered"] = bool(record.get("mastered"))
        session["result"]["occurrence"] = self.currentOccurrence
        if not correct and not skipped and not revealed and self.currentMode != "choice":
            session["result"]["typed"] = str(session.get("answer", ""))
            session["result"]["answerMarks"] = _spell_marks(session.get("answer"), current["word"])

        # Only a missed word needs a second attempt.  A correct, skipped or
        # revealed answer clears the still-pending repeat that was seeded by
        # the initial two-pass queue.
        current_id = current["id"]
        max_passes = _safe_int(session.get("passes"), 2, 1, 2)
        ids = session["ids"]
        position = session["position"]
        if correct or skipped or revealed:
            session["ids"] = [item_id for index, item_id in enumerate(ids)
                              if not (item_id == current_id and index > position)]
        elif not correct and not skipped:
            if ids.count(current_id) < max_passes and current_id not in ids[position + 1:]:
                ids.insert(min(len(ids), position + 1 + 4), current_id)

        self._emit_changed()
        if correct or skipped or revealed or self._state["settings"].get("autoSpeak", True):
            self.speak(current["word"])

    def _update_progress(self, entry_id: str, attempt: dict[str, Any]) -> None:
        entry = self._entries_by_id.get(entry_id, {})
        word_key = _normalise_answer(entry.get("word", ""))
        target_ids = self._ids_by_word.get(word_key, [entry_id])
        records = [(target_id, self._state["progress"][target_id]) for target_id in target_ids
                   if isinstance(self._state["progress"].get(target_id), dict)]
        old = max(records, key=lambda pair: (
            _safe_int(pair[1].get("correctCount"), 0, 0, 1_000_000),
            _safe_int(pair[1].get("lastSeenAt"), 0, 0, 2**63 - 1),
        ))[1] if records else None
        first_seen = min((_safe_int(record.get("firstSeenAt"), int(attempt["at"]), 0, 2**63 - 1)
                          for _, record in records), default=int(attempt["at"]))
        correct = bool(attempt["correct"] and not attempt.get("skipped"))
        at = int(attempt["at"])
        if old and at <= old.get("lastSeenAt", -1):
            return
        if not old:
            stage = 0
        elif not correct:
            stage = 0
        elif at < old.get("nextReviewAt", 0):
            stage = old.get("stage", 0)
        else:
            stage = min(old.get("stage", 0) + 1, len(REVIEW_INTERVALS) - 1)
        next_review = old.get("nextReviewAt", at + REVIEW_INTERVALS[stage]) if old and correct and at < old.get("nextReviewAt", 0) else at + REVIEW_INTERVALS[stage]
        correct_count = _safe_int(old.get("correctCount") if old else 0, 0, 0, 1_000_000) + int(correct)
        record = {
            "firstSeenAt": first_seen, "lastSeenAt": at, "nextReviewAt": next_review,
            "stage": stage, "lapses": (old.get("lapses", 0) if old else 0) + int(not correct),
            "correctStreak": (old.get("correctStreak", 0) + 1) if old and correct else (1 if correct else 0),
            "correctCount": correct_count,
            "mastered": correct_count >= MASTERY_TARGET,
            "reviews": (old.get("reviews", 0) if old else 0) + int(bool(old)), "lastCorrect": correct,
            "deckKey": attempt.get("deckKey", ""),
        }
        for target_id in target_ids:
            target = self._entries_by_id.get(target_id, {})
            copy_record = copy.deepcopy(record)
            copy_record["deckKey"] = target.get("deckKey", record["deckKey"])
            self._state["progress"][target_id] = copy_record

    @Slot()
    def previous(self):
        if not self._history:
            return
        history = self._history
        session = self._state.get("session")
        if not isinstance(session, dict):
            return
        if session.get("retrying") or session.get("retryResult") is not None:
            return
        step = history.pop()
        entry_id = str(step.get("entryId", ""))
        session["ids"] = [str(item_id) for item_id in step.get("ids", session["ids"])]
        session["position"] = max(0, _safe_int(step.get("position"), 0, 0, 10000))
        session["answer"] = ""
        session["result"] = None
        session["completed"] = max(0, _safe_int(step.get("completed"), 0, 0, 10000))
        session["right"] = max(0, _safe_int(step.get("right"), 0, 0, 10000))
        session.pop("choices", None)
        if entry_id:
            old_progress = step.get("progress")
            word_key = _normalise_answer(self._entries_by_id.get(entry_id, {}).get("word", ""))
            word_ids = self._ids_by_word.get(word_key, [entry_id])
            if old_progress is None:
                for target_id in word_ids:
                    self._state["progress"].pop(target_id, None)
            else:
                for target_id in word_ids:
                    if isinstance(old_progress, dict) and target_id in old_progress:
                        self._state["progress"][target_id] = copy.deepcopy(old_progress[target_id])
                    else:
                        self._state["progress"].pop(target_id, None)
            attempts = self._state.get("attempts")
            if isinstance(attempts, list):
                self._state["attempts"] = attempts[:max(0, _safe_int(step.get("attempts"), 0, 0, 10000))]
        self.answerChanged.emit()
        self._emit_changed()
        self._status("已回到上一词，可以重新作答")

    @Slot()
    def startRetry(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or session.get("retrying"):
            return
        result = session.get("result")
        if not isinstance(result, dict) or result.get("correct") or result.get("skipped"):
            return
        if self.currentMode == "choice":
            return
        session["retrying"] = True
        session["retryResult"] = None
        session["retryWrong"] = False
        session["result"] = None
        session["answer"] = ""
        session.pop("choices", None)
        self.answerChanged.emit()
        self._emit_changed()

    @Slot()
    def forgotAnswer(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or not session.get("retrying"):
            return
        session["answer"] = str(current.get("word", ""))
        self.answerChanged.emit()
        self.submitRetry()

    @Slot()
    def submitRetry(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or not session.get("retrying"):
            return
        if not _normalise_answer(session.get("answer")):
            return
        correct = _spelling_key(session.get("answer")) == _spelling_key(current["word"])
        # This retry is deliberately practice-only: it never changes
        # correctCount, mastery, review dates, attempts or accuracy.
        if correct:
            session["retryResult"] = {
                "correct": True,
                "expected": current["word"],
                "answer": str(session.get("answer", "")),
            }
            session["retrying"] = False
            session["retryWrong"] = False
            session["revealHint"] = ""
            self.speak(current["word"])
        else:
            # Keep the answer hidden and stay on the retry page until the
            # spelling is correct.  Wrong retries are not recorded.
            session["retrying"] = True
            session["retryResult"] = None
            session["retryWrong"] = True
        session["answer"] = ""
        self.answerChanged.emit()
        self._emit_changed()

    @Slot()
    def next(self):
        session = self._state.get("session")
        if not session:
            return
        if session.get("retryResult") is None and not session.get("result"):
            return
        session["position"] += 1
        session["answer"] = ""
        session["result"] = None
        session["retrying"] = False
        session["retryResult"] = None
        session["retryWrong"] = False
        session["revealHint"] = ""
        session.pop("choices", None)
        self.answerChanged.emit()
        if session["position"] >= len(session["ids"]) and self.loopSession:
            session["position"] = 0
            session["loops"] = _safe_int(session.get("loops"), 0, 0, 1_000_000) + 1
            self._status("本轮完成，继续循环")
        self._emit_changed()
        if session["position"] >= len(session["ids"]):
            self._status("本轮完成，做得很好")

    @Slot()
    def revealAnswer(self):
        current = self._session_entry()
        session = self._state.get("session")
        if not current or not session or session.get("result") or session.get("retrying"):
            return
        session["answer"] = str(current.get("word", ""))
        self._finish_question(False, revealed=True)
        session["revealHint"] = str(current.get("word", ""))
        self.startRetry()
        self._status("已显示答案，请照着答案重新拼写一次")

    @Slot()
    def skip(self):
        session = self._state.get("session")
        if not session:
            return
        if session.get("retrying"):
            return
        if session.get("retryResult") is not None:
            self.next()
            return
        if not session.get("result"):
            self._finish_question(False, skipped=True)
            self.next()

    @Slot()
    def exitPractice(self):
        if self._page == "practice":
            self.flushStudyTime()
        self._state["session"] = None
        self._history.clear()
        self._page = "home"
        self._emit_changed()
        self._status("已退出练习，进度已保留")

    def _speak_first_word(self, entries: list[dict[str, Any]]) -> None:
        # Spelling must never read the answer before the user has typed it.
        # Dictation playback is handled by QML on every newly displayed word.
        return

    def _remember_mistake(self, entry: dict[str, Any]) -> None:
        """Automatically keep a missed word in the notebook."""
        word_key = _normalise_answer(entry.get("word", ""))
        if not word_key:
            return
        if any(_normalise_answer(item.get("word", "")) == word_key for item in self._state["notebook"]):
            return
        item = dict(entry)
        item["relearn"] = True
        self._state["notebook"].append(item)

    @Slot()
    def toggleNotebook(self):
        current = self._session_entry()
        if not current:
            return
        existing = next((item for item in self._state["notebook"] if item.get("id") == current["id"]), None)
        if existing:
            self._state["notebook"] = [item for item in self._state["notebook"] if item.get("id") != current["id"]]
            self._status("已从生词本移除")
        else:
            self._state["notebook"].append(dict(current))
            self._status("已加入生词本")
        self._refresh_index()
        self._emit_changed()

    @Slot(str)
    def removeNotebook(self, entry_id: str):
        self._state["notebook"] = [item for item in self._state["notebook"] if item.get("id") != entry_id]
        self._refresh_index()
        self._emit_changed()

    @Slot(str)
    def markMasteredAsNew(self, entry_id: str):
        entry = self._entries_by_id.get(entry_id)
        if not entry:
            return
        word_key = _normalise_answer(entry.get("word", ""))
        target_ids = self._ids_by_word.get(word_key, [entry_id])
        existing = next((item for item in self._state["notebook"]
                         if _normalise_answer(item.get("word", "")) == word_key), None)
        if existing:
            existing["relearn"] = True
        else:
            item = dict(entry)
            item["relearn"] = True
            self._state["notebook"].append(item)
        for target_id in target_ids:
            self._state["progress"].pop(target_id, None)
        self._refresh_index()
        self._emit_changed()
        self._status("已标为生词，会加入每日学习")

    @Slot(str)
    def openPage(self, page: str):
        if page in {"home", "library", "deck", "practice", "notebook", "stats", "settings"}:
            self._clear_invalid_result()
            if self._page == "practice" and page != "practice":
                self.flushStudyTime()
            self._page = page
            self._emit_changed(save=False, invalidate=False)

    @Slot(str, "QVariant")
    def saveSetting(self, key: str, value: Any):
        if key in {"autoSpeak", "spacedRepetition", "includeNotebook", "autoCheckUpdates",
                   "chapterMode", "inputSound", "autoBackup", "loopSession"}:
            self._state["settings"][key] = bool(value)
            self._emit_changed()
        elif key == "dailyGoal":
            self.setSelectedGoals(int(value))
        elif key == "chapterSize":
            self.setChapterSize(int(value))
        elif key == "speechRate":
            self.setSpeechRate(float(value))
        elif key == "studyScope":
            self.setStudyScope(str(value))

    @Slot(int)
    def setSelectedGoals(self, amount: int):
        amount = _safe_int(amount, 20, 1, 200)
        for deck_id in self._state.get("selectedDeckIds", []):
            deck_id = str(deck_id)
            if deck_id in DEFAULT_DAILY_GOALS:
                self._state["dailyGoals"][deck_id] = amount
            elif any(book["id"] == deck_id for book in self._state["customBooks"]):
                self._state.setdefault("customGoals", {})[deck_id] = amount
        try:
            self._save_state()
        except OSError as error:
            self._status(f"无法保存学习记录：{error}")
        self.goalsChanged.emit()

    @Slot(str, int)
    def setDailyGoal(self, deck_id: str, amount: int):
        amount = _safe_int(amount, 20, 1, 200)
        if deck_id in DEFAULT_DAILY_GOALS:
            self._state["dailyGoals"][deck_id] = amount
        elif any(book["id"] == deck_id for book in self._state["customBooks"]):
            self._state.setdefault("customGoals", {})[deck_id] = amount
        try:
            self._save_state()
        except OSError as error:
            self._status(f"无法保存学习记录：{error}")
        self.goalsChanged.emit()

    @Slot(str)
    def importWordbookPath(self, path: str):
        local_path = QUrl(str(path)).toLocalFile() if str(path).startswith("file:") else str(path)
        if not local_path:
            return
        try:
            try:
                from .import_wordbook import import_wordbook
            except ImportError:
                from import_wordbook import import_wordbook
            result = import_wordbook(local_path)
            name = Path(local_path).stem.strip() or "自定义词书"
            self._enrich_placeholder_entries(result["entries"])
            book = {"id": f"custom-{uuid.uuid4().hex}", "name": name, "source": result["source"], "entries": result["entries"]}
            self._state["customBooks"].append(book)
            self._state["selectedDeckId"] = book["id"]
            self._state["selectedDeckIds"] = [book["id"]]
            self._refresh_index()
            self._page = "library"
            self._emit_changed()
            self.goalsChanged.emit()
            self._status(f"已导入“{name}”：{result['imported']} 个词条，跳过 {result['skipped']} 行")
        except (OSError, ValueError) as error:
            self._status(f"导入失败：{error}")

    def _enrich_placeholder_entries(self, entries: list[dict[str, Any]]) -> None:
        """Use a bundled definition when an imported plain word list has no gloss."""
        known: dict[str, dict[str, Any]] = {}
        for deck_key in DECK_META:
            for entry in self._vocabulary.get(deck_key, []):
                if isinstance(entry, dict) and entry.get("word"):
                    known.setdefault(_normalise_answer(entry["word"]), entry)
        placeholder = "请回忆这个词的中文释义"
        for entry in entries:
            if entry.get("meaning") != placeholder:
                continue
            bundled = known.get(_normalise_answer(entry.get("word")))
            if not bundled or not bundled.get("meaning"):
                continue
            for key in ("meaning", "pos", "senses", "phonetic", "example", "exampleZh", "phrase"):
                if key in bundled:
                    entry[key] = bundled[key]

    @Slot()
    def startNotebookReview(self):
        entries = [self._entries_by_id[item["id"]] for item in self._state["notebook"] if item.get("id") in self._entries_by_id]
        queue: list[dict[str, Any]] = []
        seen: set[str] = set()
        for entry in entries:
            key = _normalise_answer(entry.get("word", ""))
            if not key or key in seen:
                continue
            seen.add(key)
            queue.append(entry)
        queue = self._chapter_limit(queue)
        queue = queue + queue
        self._history.clear()
        self._state["session"] = {"deckKey": self._state["selectedDeckId"],
                                   "deckKeys": [deck["id"] for deck in self._selected_decks()],
                                   "ids": [item["id"] for item in queue],
                                   "kind": "notebook", "position": 0, "completed": 0, "answer": "", "result": None,
                                   "right": 0, "retrying": False, "retryResult": None, "retryWrong": False,
                                   "passes": 2, "typedLetters": 0, "startedAt": _now_ms()}
        self._page = "practice"
        self.answerChanged.emit()
        self._emit_changed()
        self._speak_first_word(queue)

    @Slot(str)
    def speak(self, word: str):
        text = re.sub(r"\s+", " ", str(word or "")).strip()
        if not text or text.casefold() in {"undefined", "null", "nan"}:
            return
        self._speech_token += 1
        token = self._speech_token
        if self._tts is not None:
            try:
                self._tts.stop()
            except (AttributeError, RuntimeError):
                pass
        if self._play_audio(text, token):
            return
        self._speak_system(text, token)

    def _audio_path(self, text: str) -> Path:
        key = hashlib.sha1((self.voiceAccent + ":" + text.casefold()).encode("utf-8")).hexdigest()
        return self._audio_dir / f"{key}.mp3"

    def _ensure_audio_player(self) -> bool:
        if self._audio_player is not None:
            return True
        try:
            from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
        except (ImportError, RuntimeError):
            return False
        try:
            self._audio_output = QAudioOutput(self)
            self._audio_output.setVolume(0.92)
            self._audio_player = QMediaPlayer(self)
            self._audio_player.setAudioOutput(self._audio_output)
            self._audio_player.setVolume(1.0)
            return True
        except (AttributeError, RuntimeError):
            self._audio_player = None
            self._audio_output = None
            return False

    def _play_audio_file(self, path: Path) -> bool:
        if not self._ensure_audio_player():
            return False
        try:
            self._audio_player.stop()
            self._audio_player.setSource(QUrl.fromLocalFile(str(path)))
            self._audio_player.play()
            return True
        except (AttributeError, RuntimeError):
            return False

    def _play_audio(self, text: str, token: int) -> bool:
        path = self._audio_path(text)
        try:
            if path.exists() and path.stat().st_size > 800:
                if self._play_audio_file(path):
                    return True
        except OSError:
            pass
        return self._fetch_audio(text, token)

    def _fetch_audio(self, text: str, token: int) -> bool:
        try:
            from PySide6.QtCore import QUrl
            from PySide6.QtNetwork import QNetworkRequest
        except (ImportError, RuntimeError):
            return False
        try:
            if self._audio_manager is None:
                from PySide6.QtNetwork import QNetworkAccessManager
                self._audio_manager = QNetworkAccessManager(self)
            key = hashlib.sha1((self.voiceAccent + ":" + text.casefold()).encode("utf-8")).hexdigest()
            if key in self._audio_pending:
                return True
            from urllib.parse import quote
            accent = "1" if self.voiceAccent == "uk" else "2"
            url = QUrl(f"https://dict.youdao.com/dictvoice?audio={quote(text, safe='')}&type={accent}")
            request = QNetworkRequest(url)
            request.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader,
                              "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            try:
                request.setTransferTimeout(2200)
            except AttributeError:
                pass
            reply = self._audio_manager.get(request)
            self._audio_pending.add(key)
            reply.finished.connect(lambda: self._finish_audio(reply, text, token, key))
            return True
        except (AttributeError, RuntimeError):
            return False

    def _finish_audio(self, reply, text: str, token: int, key: str):
        self._audio_pending.discard(key)
        try:
            if token != self._speech_token:
                return
            from PySide6.QtNetwork import QNetworkReply
            if reply.error() == QNetworkReply.NetworkError.NoError:
                data = bytes(reply.readAll())
                if len(data) > 800:
                    path = self._audio_path(text)
                    try:
                        path.parent.mkdir(parents=True, exist_ok=True)
                        temporary = path.with_suffix(".part")
                        temporary.write_bytes(data)
                        temporary.replace(path)
                        if self._play_audio_file(path):
                            return
                    except OSError:
                        pass
            self._speak_system(text, token)
        finally:
            reply.deleteLater()

    def _speak_system(self, text: str, token: int):
        if token != self._speech_token:
            return
        try:
            from PySide6.QtTextToSpeech import QTextToSpeech  # optional Qt module
            if self._tts is None:
                if not QTextToSpeech.availableEngines():
                    raise RuntimeError("no system speech engine")
                self._tts = QTextToSpeech(self)
                self._apply_voice_accent()
            voices = list(self._tts.availableVoices())
            has_english = any(str(voice.locale().name()).lower().startswith("en")
                              for voice in voices)
            if has_english and self._qt_voice_ready:
                self._tts.stop()
                self._tts.say(text)
                return
        except (ImportError, RuntimeError, AttributeError):
            pass
        if os.name != "nt":
            return
        culture = "en-GB" if self.voiceAccent == "uk" else "en-US"
        script = (
            "Add-Type -AssemblyName System.Speech; "
            "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            f"$s.Rate = {int(self.speechRate * 10)}; "
            "$v=$s.GetInstalledVoices() | Where-Object {{ $_.VoiceInfo.Culture.Name -eq '{culture}' }} | Select-Object -First 1; "
            "if(-not $v){{$v=$s.GetInstalledVoices() | Where-Object {{ $_.VoiceInfo.Culture.Name -eq 'en-US' }} | Select-Object -First 1}}; "
            "if($v){{$s.SelectVoice($v.VoiceInfo.Name)}}; "
            "$t=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{payload}')); "
            "[void]$s.Speak($t)"
        ).format(culture=culture, payload=base64.b64encode(text.encode("utf-8")).decode("ascii"))
        encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
        try:
            subprocess.Popen(["powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-EncodedCommand", encoded],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        except OSError:
            return

    @Slot(str)
    def exportBackupPath(self, path: str):
        local_path = QUrl(str(path)).toLocalFile() if str(path).startswith("file:") else str(path)
        if not local_path:
            return
        if not local_path.casefold().endswith(".json"):
            local_path += ".json"
        payload = {"app": "lexicon-study-desktop", "version": 1, "exportedAt": _now_ms(), "data": self._state}
        try:
            Path(local_path).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            self._status(f"备份已导出：{Path(local_path).name}")
        except OSError as error:
            self._status(f"导出失败：{error}")

    @Slot(str)
    def importBackupPath(self, path: str):
        local_path = QUrl(str(path)).toLocalFile() if str(path).startswith("file:") else str(path)
        if not local_path:
            return
        try:
            parsed = json.loads(Path(local_path).read_text(encoding="utf-8-sig"))
            data = parsed.get("data") if isinstance(parsed, dict) else None
            if not isinstance(data, dict):
                raise ValueError("备份文件格式不正确")
            incoming = _default_state()
            incoming.update({key: data[key] for key in incoming.keys() if key in data})
            incoming["customBooks"] = [self._clean_book(item) for item in incoming.get("customBooks", []) if self._clean_book(item)]
            attempts = {f"{item['id']}:{item['at']}": item for item in self._state["attempts"] + [item for item in incoming.get("attempts", []) if self._valid_attempt(item)]}
            self._state["attempts"] = sorted(attempts.values(), key=lambda item: item["at"])[-10000:]
            notebook = {item["id"]: item for item in self._state["notebook"] + incoming.get("notebook", []) if isinstance(item, dict) and isinstance(item.get("id"), str)}
            self._state["notebook"] = list(notebook.values())
            self._state["progress"].update(incoming.get("progress", {}) if isinstance(incoming.get("progress"), dict) else {})
            existing_books = {item["id"]: item for item in self._state["customBooks"]}
            existing_books.update({item["id"]: item for item in incoming["customBooks"]})
            self._state["customBooks"] = list(existing_books.values())
            self._state["dailyGoals"].update(incoming.get("dailyGoals", {}) if isinstance(incoming.get("dailyGoals"), dict) else {})
            self._state["settings"].update(incoming.get("settings", {}) if isinstance(incoming.get("settings"), dict) else {})
            if not self._state.get("session") and isinstance(incoming.get("session"), dict):
                self._state["session"] = incoming["session"]
            if incoming.get("selectedDeckId") and (incoming["selectedDeckId"] in DECK_META or any(book["id"] == incoming["selectedDeckId"] for book in self._state["customBooks"])):
                self._state["selectedDeckId"] = incoming["selectedDeckId"]
            incoming_ids = incoming.get("selectedDeckIds")
            if isinstance(incoming_ids, list) and incoming_ids:
                self._state["selectedDeckIds"] = [str(item) for item in incoming_ids if isinstance(item, str)]
            self._refresh_index()
            self._sanitize_deck_selection()
            self._sanitize_session()
            self._emit_changed()
            self.goalsChanged.emit()
            self.answerChanged.emit()
            self._status(f"备份已合并：{len(self._state['attempts'])} 条记录，{len(self._state['notebook'])} 个生词")
        except (OSError, json.JSONDecodeError, ValueError, TypeError) as error:
            self._status(f"备份导入失败：{error}")

    def _status(self, message: str):
        self._status_message = str(message)
        self.statusMessageChanged.emit()


__all__ = ["StudyBackend", "DECK_META", "DEFAULT_DAILY_GOALS", "REVIEW_INTERVALS"]
