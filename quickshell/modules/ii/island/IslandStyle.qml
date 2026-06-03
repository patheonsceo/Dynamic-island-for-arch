pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

// Shared design tokens for all three floating islands, so left / notch / right
// stay visually consistent (geometry, solid space-black surface, accents).
Singleton {
    id: root

    // Geometry
    readonly property int margin: 4            // gap from the screen edge (top/left/right)
    readonly property int pillHeight: 32       // island height
    readonly property int hPadding: 10         // inner horizontal padding
    readonly property real radius: Appearance.rounding.full

    // Surface — solid space black (reference pills/notch are opaque black,
    // not the translucent themed bar look).
    readonly property color pillColor: "#0B0B0E"
    readonly property color pillBorder: Appearance.colors.colLayer0Border
    readonly property int borderWidth: 1

    // Content colors
    readonly property color textColor: "#FFFFFF"        // primary text / used indicators
    readonly property color subtextColor: "#9AA0AA"     // secondary text
    readonly property color accent: "#8AB4F8"           // blue tint (current workspace, highlights)
    readonly property real inactiveOpacity: 0.45        // unused / dim elements
}
