pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Left floating island — top-left.
// Custom workspace indicator + active window title (ActiveWindow, compact).
// Left-click pill → toggle left sidebar. Right-click workspaces → overview.
// Shared geometry/colors come from IslandStyle (see notch & right islands).
Scope {
    id: root

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
                top: IslandStyle.margin
                left: IslandStyle.margin
            }

            implicitWidth: pill.implicitWidth
            implicitHeight: IslandStyle.pillHeight

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: IslandStyle.radius
                color: IslandStyle.pillColor
                border.width: IslandStyle.borderWidth
                border.color: IslandStyle.pillBorder

                implicitWidth: contentRow.implicitWidth + IslandStyle.hPadding * 2

                // Base layer: left-click anywhere on the pill toggles the left sidebar.
                // Workspace buttons / title sit above and handle their own clicks.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
                }

                RowLayout {
                    id: contentRow
                    anchors.fill: parent
                    anchors.leftMargin: IslandStyle.hPadding
                    anchors.rightMargin: IslandStyle.hPadding
                    spacing: 8

                    // Custom reference-style indicator: uniform-spaced dots + expanding
                    // current-workspace capsule. Scroll = switch, right-click = overview.
                    IslandWorkspaces {
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        usedColor: IslandStyle.textColor   // used (not current) → white
                        activeColor: IslandStyle.accent    // current → blue-tinted
                        emptyOpacity: IslandStyle.inactiveOpacity
                        capsuleWidth: 32                   // current capsule a bit longer
                    }

                    ActiveWindow {
                        compact: true
                        Layout.fillHeight: true
                        Layout.maximumWidth: 160
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
