"""Launch the Vocabulary Studio desktop client."""

from __future__ import annotations

import sys
import os
from pathlib import Path

# PySide6 searches some dependent Qt DLLs through PATH on Windows. In a
# frozen one-file build these files live in PyInstaller's temporary extraction
# directory, so register its directories before importing any Qt modules.
_DLL_DIRECTORY_HANDLES = []
if sys.platform == "win32" and getattr(sys, "frozen", False):
    _bundle_dir = Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent)).resolve()
    _pyside_dir = _bundle_dir / "PySide6"
    _dll_directories = (
        _bundle_dir,
        _pyside_dir,
        _pyside_dir / "Qt" / "bin",
        _bundle_dir / "shiboken6",
    )
    for _dll_directory in _dll_directories:
        if _dll_directory.is_dir():
            _DLL_DIRECTORY_HANDLES.append(os.add_dll_directory(str(_dll_directory)))
    os.environ["PATH"] = os.pathsep.join(
        [str(path) for path in _dll_directories if path.is_dir()] + [os.environ.get("PATH", "")]
    )
    _qt_plugin_dir = _bundle_dir / "PySide6" / "plugins"
    if _qt_plugin_dir.is_dir():
        os.environ["QT_PLUGIN_PATH"] = str(_qt_plugin_dir)

from PySide6.QtCore import QUrl, Qt
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

try:  # Support both module launch and direct launch from the project folder.
    from .backend import StudyBackend
    from .updater import Updater
    from .version import APP_VERSION
except ImportError:  # pragma: no cover - exercised by `python desktop/app.py`
    from backend import StudyBackend
    from updater import Updater
    from version import APP_VERSION


def _asset_path(name: str) -> Path:
    if getattr(sys, "frozen", False):
        base = Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent))
    else:
        base = Path(__file__).resolve().parent
    return base / "assets" / name


def main() -> int:
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )
    QQuickStyle.setStyle("Fusion")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("词序桌面版")
    app.setApplicationDisplayName("词序 · Vocabulary Studio")
    app.setOrganizationName("Lexicon Studio")
    app.setApplicationVersion(APP_VERSION)
    app.setFont(QFont("Microsoft YaHei UI", 10))

    icon_path = _asset_path("icon.ico")
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))
    engine = QQmlApplicationEngine()
    backend = StudyBackend()
    updater = Updater(backend, app)
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("updater", updater)
    qml_path = Path(__file__).resolve().parent / "qml" / "Main.qml"
    if getattr(sys, "frozen", False):
        qml_path = Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent)) / "qml" / "Main.qml"
    engine.addImportPath(str(qml_path.parent))
    engine.load(QUrl.fromLocalFile(str(qml_path)))
    if not engine.rootObjects():
        return 1

    window = engine.rootObjects()[0]
    if sys.platform == "win32":
        # Ensure the standard taskbar-button toggle (click active app to
        # minimize) is available for the frameless window.
        try:
            import ctypes

            hwnd = int(window.winId())
            gwl_style = -16
            ws_minimizebox = 0x00020000
            style = ctypes.windll.user32.GetWindowLongW(hwnd, gwl_style)
            if not (style & ws_minimizebox):
                ctypes.windll.user32.SetWindowLongW(hwnd, gwl_style, style | ws_minimizebox)
                ctypes.windll.user32.SetWindowPos(
                    hwnd, 0, 0, 0, 0, 0, 0x0020 | 0x0002 | 0x0001 | 0x0004
                )
        except Exception:
            pass
    updater.startAutoCheck()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
