"""Collect only the QML modules used by the desktop client.

PyInstaller's default QtQml hook bundles every QML module installed with
PySide6, including WebEngine, Qt3D, and Quick3D. This application imports
QtQuick, QtQuick.Controls, and QtQuick.Layouts only.
"""

from PyInstaller.utils.hooks.qt import add_qt6_dependencies, pyside6_library_info

hiddenimports, binaries, datas = add_qt6_dependencies(__file__)
qml_binaries, qml_datas = pyside6_library_info.collect_qtqml_files()

EXCLUDED_RUNTIME_BINARIES = (
    "Qt63D",
    "Qt6Pdf",
    "Qt6Widgets",
    "Qt6QuickTest",
    "Qt6QuickShapes",
    "Qt6QuickTimeline",
    "Qt6QuickParticles",
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
)


def _keep_binary(item):
    name = str(item[0]).replace("\\", "/").rsplit("/", 1)[-1]
    return not name.startswith(EXCLUDED_RUNTIME_BINARIES)


binaries = [item for item in binaries if _keep_binary(item)]

EXCLUDED_QML_MODULES = {
    "Qt3D",
    "QtCharts",
    "QtDataVisualization",
    "QtGraphs",
    "QtLocation",
    "QtMultimedia",
    "QtPdf",
    "QtPositioning",
    "QtQuick3D",
    "QtScxml",
    "QtSensors",
    "QtSql",
    "QtWebChannel",
    "QtWebEngine",
    "QtWebSockets",
    "QtWebView",
}

EXCLUDED_CONTROL_STYLES = {
    "FluentWinUI3",
    "Imagine",
    "Material",
    "Universal",
    "Windows",
}


def _is_excluded_qml_destination(item):
    destination = str(item[1]).replace("\\", "/")
    parts = destination.split("/")
    if "qml" in parts and any(module in parts for module in EXCLUDED_QML_MODULES):
        return True
    if "Controls" in parts:
        control_index = parts.index("Controls")
        if control_index + 1 < len(parts) and parts[control_index + 1] in EXCLUDED_CONTROL_STYLES:
            return True
    return "Designer" in parts


binaries += [item for item in qml_binaries if not _is_excluded_qml_destination(item)]
datas += [item for item in qml_datas if not _is_excluded_qml_destination(item)]
