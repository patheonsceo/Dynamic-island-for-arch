pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Custom workspace indicator for the floating island.
// Reference-style: uniform-spaced dots (used = solid, unused = faint), and the
// CURRENT workspace renders as a capsule the SAME height as the dots, which
// expands and fluidly pushes its neighbours apart (uniform gaps everywhere).
Item {
    id: root

    property int workspacesShown: 10
    property real dotSize: 8
    property real capsuleWidth: 26
    property real gap: 7
    property real emptyOpacity: 0.5
    property color usedColor: Appearance.colors.colOnLayer0
    property color activeColor: Appearance.colors.colPrimary

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int activeWs: monitor?.activeWorkspace?.id ?? 1
    readonly property int group: Math.floor((activeWs - 1) / workspacesShown)

    // Occupancy, refreshed on Hyprland signals (bindings over .values don't always re-eval).
    property var occupied: []
    function updateOccupied() {
        root.occupied = Array.from({ length: root.workspacesShown }, (_, i) =>
            Hyprland.workspaces.values.some(w => w.id === root.group * root.workspacesShown + i + 1));
    }
    Component.onCompleted: updateOccupied()
    onGroupChanged: updateOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.updateOccupied(); }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.updateOccupied(); }
    }

    implicitWidth: wsRow.implicitWidth
    implicitHeight: root.dotSize

    // Scroll anywhere → switch workspace.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace e+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace e-1`);
        }
    }

    // Right-click anywhere → overview. Sits below the per-dot left-click areas;
    // right-clicks fall through to it, and the inter-dot gaps hit it directly.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        onPressed: event => {
            if (event.button === Qt.RightButton)
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.workspacesShown

            delegate: Item {
                id: del
                required property int index
                readonly property int wsId: root.group * root.workspacesShown + index + 1
                readonly property bool isActive: root.activeWs === wsId
                readonly property bool isOccupied: root.occupied[index] ?? false

                width: indicator.width
                height: root.height

                Rectangle {
                    id: indicator
                    anchors.centerIn: parent
                    width: del.isActive ? root.capsuleWidth : root.dotSize
                    height: root.dotSize
                    radius: height / 2
                    color: del.isActive ? root.activeColor : root.usedColor
                    opacity: del.isActive ? 1 : (del.isOccupied ? 1 : root.emptyOpacity)

                    Behavior on width {
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: Hyprland.dispatch(`workspace ${del.wsId}`)
                }
            }
        }
    }
}
