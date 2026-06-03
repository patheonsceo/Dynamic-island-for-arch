pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Center floating notch — top-center. THE STAR (morphing state machine comes in
// Phase 3+). Phase 1: static themed pill placeholder, horizontally centered.
Scope {
    id: root

    readonly property int islandMargin: 8
    readonly property int pillHeight: 34

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: islandWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:islandNotch"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            // Anchor top edge only → layer-shell centers the surface horizontally.
            anchors {
                top: true
            }
            margins {
                top: root.islandMargin
            }

            implicitWidth: pill.implicitWidth
            implicitHeight: root.pillHeight

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                implicitWidth: notchRow.implicitWidth + 36

                RowLayout {
                    id: notchRow
                    anchors.centerIn: parent
                    spacing: 8

                    StyledText {
                        text: "notch"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }
            }
        }
    }
}
