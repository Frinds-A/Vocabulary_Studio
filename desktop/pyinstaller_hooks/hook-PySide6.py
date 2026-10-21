"""Collect only the PySide6 runtime binaries used by the desktop client."""

import os

from PyInstaller.utils.hooks import check_requirement
from PyInstaller.utils.hooks.qt import ensure_single_qt_bindings_package, pyside6_library_info

ensure_single_qt_bindings_package("PySide6")

EXCLUDED_BINARY_PREFIXES = (
    "Qt63D",
    "Qt6Pdf",
    "Qt6Quick3D",
    "Qt6Labs",
    "Qt6MultimediaWidgets",
    "Qt6Widgets",
    "Qt6PrintSupport",
    "Qt6QuickTest",
    "Qt6QuickTimeline",
    "Qt6QuickParticles",
    "Qt6QuickShapes",
    "Qt6QuickVectorImage",
    "Qt6QuickNativeStyle",
    "Qt6QuickControls2FluentWinUI3",
    "Qt6QuickControls2Imagine",
    "Qt6QuickControls2Material",
    "Qt6QuickControls2Universal",
    "Qt6QuickControls2Windows",
    "Qt6QmlDesignSupport",
    "Qt6QmlLocalStorage",
    "Qt6QmlXmlListModel",
    "Qt6QmlNetwork",
    "Qt6QmlCompiler",
    "Qt6QmlDom",
    "Qt6QmlFormat",
    "Qt6QmlLint",
    "Qt6QmlTypeRegistrar",
    "Qt6QmlDebug",
    "Qt6Charts",
    "Qt6DataVisualization",
    "Qt6Graphs",
    "Qt6Scxml",
    "Qt6Sql",
    "Qt6Sensors",
    "Qt6Positioning",
    "Qt6Location",
    "Qt6Bluetooth",
    "Qt6Nfc",
    "Qt6SerialPort",
    "Qt6Web",
    "Qt6Test",
    "Qt6Designer",
    "Qt6Help",
    "Qt6UiTools",
    "Qt6Concurrent",
)


def _allowed_binary(item):
    name = os.path.basename(item[0])
    return not name.startswith(EXCLUDED_BINARY_PREFIXES)


if pyside6_library_info.version is not None:
    hiddenimports = ["shiboken6", "inspect"]
    if check_requirement("PySide6 >= 6.4.0"):
        hiddenimports.append("PySide6.support.deprecated")

    binaries = pyside6_library_info.collect_extra_binaries()
    binaries = [
        item for item in binaries
        if _allowed_binary(item)
        and not os.path.basename(item[0]).lower().startswith(("icuuc", "icuin", "icudt"))
    ]
