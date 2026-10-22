"""Regression tests for values shown on the daily plan."""

from __future__ import annotations

import tempfile
import unittest
from datetime import datetime
from pathlib import Path

from desktop.backend import StudyBackend


class DailyPlanTests(unittest.TestCase):
    def test_today_plan_new_only_counts_words_in_selected_books(self):
        repo = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="lexicon-plan-test-") as temp:
            backend = StudyBackend(
                data_path=repo / "desktop" / "data" / "vocabulary.json",
                state_path=Path(temp) / "state.json",
            )
            selected_word = backend._vocabulary["cet6Words"][0]
            selected_key = str(selected_word["word"]).casefold()
            outside_word = next(
                entry for entry in backend._vocabulary["cet4Outline"]
                if str(entry["word"]).casefold() != selected_key
            )
            first_seen_at = int(datetime.now().timestamp() * 1000)
            backend._state["progress"] = {
                selected_word["id"]: {"firstSeenAt": first_seen_at},
                outside_word["id"]: {"firstSeenAt": first_seen_at},
            }
            backend.selectDeck("cet6Words")

            self.assertEqual(backend.todayNew, 2)
            self.assertEqual(backend.todayPlanNew, 1)

            backend.selectDeck("cet4Outline")
            self.assertEqual(backend.todayPlanNew, 1)


if __name__ == "__main__":
    unittest.main()
