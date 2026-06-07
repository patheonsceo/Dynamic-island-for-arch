pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Left floating island — top-left. Five pills (reference layout, no title):
//   1) search    → launcher surface
//   2) workspaces → live indicator (scroll switch, right-click overview;
//                   background click → left sidebar)
//   3) weather   → emoji + °C
//   4) overview  → workspace overview surface
//   5) network   → status icon, hover reveals throughput
// Shared geometry/colors from IslandStyle.
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

            // Fixed window width (≥ the widest pill layout) so a pill expanding on
            // hover grows INTO reserved space instead of resizing the window every
            // frame (that caused the jitter). Masked to the actual pills so the
            // empty trailing area stays click-through.
            implicitWidth: Math.max(600, rowPills.implicitWidth)
            implicitHeight: IslandStyle.pillHeight
            mask: Region { item: rowPills }

            component Pill: Rectangle {
                radius: IslandStyle.radius
                color: IslandStyle.pillColor
                border.width: IslandStyle.borderWidth
                border.color: IslandStyle.pillBorder
            }

            RowLayout {
                id: rowPills
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: 6

                // ---- 1) search → launcher ----
                Pill {
                    Layout.fillHeight: true
                    Layout.preferredWidth: IslandStyle.pillHeight
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "search"
                        iconSize: 18
                        fill: 1
                        color: searchHover.hovered ? IslandStyle.accent : IslandStyle.textColor
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    HoverHandler { id: searchHover }
                    TapHandler { onTapped: Island.toggle("launcher", islandWindow.screen.name) }
                }

                // ---- 2) workspaces ----
                Pill {
                    Layout.fillHeight: true
                    Layout.preferredWidth: wsRow.implicitWidth + IslandStyle.hPadding * 2

                    // background click → left sidebar (dots handle their own clicks)
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
                    }

                    Item {
                        id: wsRow
                        anchors.fill: parent
                        anchors.leftMargin: IslandStyle.hPadding
                        anchors.rightMargin: IslandStyle.hPadding
                        implicitWidth: ws.implicitWidth
                        IslandWorkspaces {
                            id: ws
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            usedColor: IslandStyle.textColor
                            activeColor: IslandStyle.accent
                            emptyOpacity: IslandStyle.inactiveOpacity
                            capsuleWidth: 32
                        }
                    }
                }

                // ---- 3) weather ----
                IslandWeatherPill {
                    Layout.fillHeight: true
                }

                // ---- 4) overview ----
                Pill {
                    Layout.fillHeight: true
                    Layout.preferredWidth: IslandStyle.pillHeight
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "grid_view"
                        iconSize: 17
                        fill: 1
                        color: overviewHover.hovered ? IslandStyle.accent : IslandStyle.textColor
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    HoverHandler { id: overviewHover }
                    TapHandler { onTapped: Island.toggle("overview", islandWindow.screen.name) }
                }

                // ---- 5) network ----
                IslandNetworkPill {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
