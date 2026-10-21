/*
 * Monochrome MD3 theme for 词序.
 *
 * The component implementations under Controls/ come from
 * https://github.com/sudoevolve/material-components-qml
 * (GNU Lesser General Public License v3 or later).
 * This file supplies the color/typography primitives without the upstream
 * C++ StyleManager so the controls can run inside a pure-QML PySide6 app.
 */

pragma Singleton
import QtQuick

QtObject {
    id: theme

    readonly property var color: ({
        "primary": "#3A4048",
        "onPrimaryColor": "#FFFFFF",
        "primaryContainer": "#F0F1F3",
        "onPrimaryContainerColor": "#2A3038",
        "secondary": "#5A626C",
        "onSecondaryColor": "#FFFFFF",
        "secondaryContainer": "#E8EAED",
        "onSecondaryContainerColor": "#2A3038",
        "tertiary": "#4A515A",
        "onTertiaryColor": "#FFFFFF",
        "tertiaryContainer": "#F0F1F3",
        "onTertiaryContainerColor": "#2A3038",
        "error": "#6B7078",
        "onErrorColor": "#FFFFFF",
        "errorContainer": "#F0F1F3",
        "onErrorContainerColor": "#2A3038",
        "background": "#FFFFFF",
        "onBackgroundColor": "#2A3038",
        "surface": "#FFFFFF",
        "onSurfaceColor": "#2A3038",
        "surfaceVariant": "#F3F4F6",
        "onSurfaceVariantColor": "#5A626C",
        "outline": "#CFD4DA",
        "outlineVariant": "#E4E7EC",
        "shadow": "#000000",
        "scrim": "#000000",
        "inverseSurface": "#2A3038",
        "inverseOnSurface": "#F7F8FA",
        "inversePrimary": "#D5D8DC",
        "surfaceDim": "#E4E7EC",
        "surfaceBright": "#FFFFFF",
        "surfaceContainerLowest": "#FFFFFF",
        "surfaceContainerLow": "#F9FAFB",
        "surfaceContainer": "#F3F4F6",
        "surfaceContainerHigh": "#ECEEF1",
        "surfaceContainerHighest": "#E4E7EC"
    })

    property FontLoader iconFont: FontLoader {
        source: "assets/MaterialIconsRound-Regular.otf"
    }

    readonly property var typography: ({
        "displayLarge": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 57, "lineHeight": 64, "tracking": -0.25 },
        "displayMedium": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 45, "lineHeight": 52, "tracking": 0 },
        "displaySmall": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 36, "lineHeight": 44, "tracking": 0 },
        "headlineLarge": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 32, "lineHeight": 40, "tracking": 0 },
        "headlineMedium": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 28, "lineHeight": 36, "tracking": 0 },
        "headlineSmall": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 24, "lineHeight": 32, "tracking": 0 },
        "titleLarge": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 22, "lineHeight": 28, "tracking": 0 },
        "titleMedium": { "family": "Microsoft YaHei UI", "weight": Font.Medium, "size": 16, "lineHeight": 24, "tracking": 0.15 },
        "titleSmall": { "family": "Microsoft YaHei UI", "weight": Font.Medium, "size": 14, "lineHeight": 20, "tracking": 0.1 },
        "labelLarge": { "family": "Microsoft YaHei UI", "weight": Font.Medium, "size": 14, "lineHeight": 20, "tracking": 0.1 },
        "labelMedium": { "family": "Microsoft YaHei UI", "weight": Font.Medium, "size": 12, "lineHeight": 16, "tracking": 0.5 },
        "labelSmall": { "family": "Microsoft YaHei UI", "weight": Font.Medium, "size": 11, "lineHeight": 16, "tracking": 0.5 },
        "bodyLarge": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 16, "lineHeight": 24, "tracking": 0.5 },
        "bodyMedium": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 14, "lineHeight": 20, "tracking": 0.25 },
        "bodySmall": { "family": "Microsoft YaHei UI", "weight": Font.Normal, "size": 12, "lineHeight": 16, "tracking": 0.4 }
    })

    readonly property var shape: ({
        "cornerNone": 0,
        "cornerExtraSmall": 4,
        "cornerSmall": 8,
        "cornerMedium": 12,
        "cornerLarge": 16,
        "cornerExtraLarge": 28,
        "cornerFull": 1000
    })

    readonly property var elevation: ({
        "level0": 0,
        "level1": 1,
        "level2": 3,
        "level3": 6,
        "level4": 8,
        "level5": 12
    })

    readonly property var state: ({
        "draggedStateLayerOpacity": 0.16,
        "focusStateLayerOpacity": 0.12,
        "hoverStateLayerOpacity": 0.08,
        "pressedStateLayerOpacity": 0.12
    })
}
