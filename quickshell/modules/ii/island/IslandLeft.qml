pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Left floating island — top-left.
// Phase 1: static themed pill placeholder.
// Later: workspace dots + active window title (click → sidebarLeftOpen).
Scope {
    id: root

    // Shared floating-island geometry tokens
    readonly property int islandMargin: 8
    readonly property int pillHeight: 34

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: islandWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:islandLeft"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: true
                left: true
            }
            margins {
                top: root.islandMargin
                left: root.islandMargin
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

                implicitWidth: leftRow.implicitWidth + 28

                RowLayout {
                    id: leftRow
                    anchors.centerIn: parent
                    spacing: 8

                    StyledText {
                        text: "left"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }
            }
        }
    }
}
