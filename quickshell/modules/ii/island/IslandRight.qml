pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Right floating island — top-right.
// Phase 1: static themed pill placeholder.
// Later: resources + clock + battery + tray + wifi/bt (click → sidebarRightOpen).
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

            WlrLayershell.namespace: "quickshell:islandRight"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: true
                right: true
            }
            margins {
                top: root.islandMargin
                right: root.islandMargin
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

                implicitWidth: rightRow.implicitWidth + 28

                RowLayout {
                    id: rightRow
                    anchors.centerIn: parent
                    spacing: 8

                    StyledText {
                        text: "right"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }
            }
        }
    }
}
