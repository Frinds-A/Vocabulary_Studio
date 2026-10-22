"""Offscreen interaction regression test for immersive spelling."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QObject, QEvent, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

from desktop.backend import StudyBackend
from desktop.updater import Updater

QQuickStyle.setStyle("Fusion")


class ImmersiveSpellingInteractionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def test_enter_submits_then_advances_and_wrong_answer_is_visible(self):
        repo = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="lexicon-qml-test-") as temp:
            backend = StudyBackend(
                data_path=repo / "desktop" / "data" / "vocabulary.json",
                state_path=Path(temp) / "state.json",
            )
            backend.selectDeck("cet46Phrases")
            backend.startPlan("today")

            engine = QQmlApplicationEngine()
            engine.rootContext().setContextProperty("backend", backend)
            engine.rootContext().setContextProperty("updater", Updater(backend, self.app))
            engine.addImportPath(str(repo / "desktop" / "qml"))
            engine.load(QUrl.fromLocalFile(str(repo / "desktop" / "qml" / "Main.qml")))
            self.assertTrue(engine.rootObjects(), "QML app should load in offscreen mode")
            root = engine.rootObjects()[0]

            # Focus mode is opt-in in the redesigned UI; open it explicitly.
            root.setProperty("immersive", True)
            self.app.processEvents()

            input_field = root.findChild(QObject, "answerInputImmersive")
            self.assertIsNotNone(input_field, "immersive answer field should exist")

            self.app.processEvents()
            word = str(backend.current["word"])
            wrong = "z" * len(word)
            if wrong.casefold() == word.casefold():
                wrong = "y" * len(word)
            previous_position = backend.queuePosition

            input_field.forceActiveFocus()
            self.app.processEvents()
            input_field.setProperty("text", wrong)
            backend.setAnswer(wrong)
            QTest.keyClick(root, Qt.Key_Return)
            self.app.processEvents()

            self.assertIsNotNone(backend.result)
            self.assertFalse(backend.result["correct"])
            self.assertEqual(backend.result["expected"], word)

            # The same Enter key advances after feedback is visible.
            input_field.forceActiveFocus()
            QTest.keyClick(root, Qt.Key_Return)
            self.app.processEvents()
            self.assertEqual(backend.queuePosition, previous_position + 1)
            self.assertIsNone(backend.result)

            engine.deleteLater()
            self.app.processEvents()


if __name__ == "__main__":
    unittest.main()
