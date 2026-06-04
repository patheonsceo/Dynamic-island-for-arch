pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

// Center notch — top-attached, morphing. THE STAR.
//
// Shape: hangs from the top-center; SQUARE top corners flush with the screen edge,
// ROUNDED bottom corners (rounded throughout the morph). Concave "shoulder" fillets
// (RoundCorner) on each top side blend it fluidly into the top edge — like the
// Hyprfabricated reference. Borderless solid fill (a border would draw seam lines).
//
// States: idle (small empty) · expanded (medium, auto content) · open (large, click).
// Morph uses the reference's goey overshoot curve (cubic-bezier 0.175,0.885,0.32,1.275).
Scope {
    id: root

    // Lively but controlled goey overshoot — bouncier than 1.12, without the violent
    // open→idle collapse the reference's 1.275 caused.
    readonly property list<real> goeyCurve: [0.34, 1.22, 0.64, 1, 1, 1]
    readonly property int morphDuration: 330
    readonly property int shoulderSize: 20
    // Constant bottom radius across all states (≤ idle-height/2 so it never clamps) →
    // the corners look identical at every size, no "rounding in" during the morph.
    readonly property int cornerRadius: 18

    function stateWidth(s) {
        return s === "open" ? 480 : s === "expanded" ? 380 : 180;
    }
    function stateHeight(s) {
        return s === "open" ? 300 : s === "expanded" ? 56 : 36;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notchWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:islandNotch"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: true
            }
            margins {
                top: 0
            }

            // Fixed at the largest state (+ room for the shoulders); masked to the notch.
            implicitWidth: root.stateWidth("open") + root.shoulderSize * 2
            implicitHeight: root.stateHeight("open")
            mask: Region {
                item: notch
            }

            // --- state machine ---
            property string islandState: "idle"

            // TEMP test trigger: click cycles idle → expanded → open → idle.
            function cycle() {
                islandState = islandState === "idle" ? "expanded" : islandState === "expanded" ? "open" : "idle";
            }

            // Left shoulder — concave fillet blending the notch's left edge into the top.
            // Overlaps the notch by 1px to avoid an anti-alias seam.
            RoundCorner {
                id: leftShoulder
                corner: RoundCorner.CornerEnum.TopRight
                color: IslandStyle.pillColor
                implicitSize: root.shoulderSize
                anchors.right: notch.left
                anchors.rightMargin: -1
                anchors.top: parent.top
            }
            RoundCorner {
                id: rightShoulder
                corner: RoundCorner.CornerEnum.TopLeft
                color: IslandStyle.pillColor
                implicitSize: root.shoulderSize
                anchors.left: notch.right
                anchors.leftMargin: -1
                anchors.top: parent.top
            }

            Rectangle {
                id: notch
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                width: root.stateWidth(notchWindow.islandState)
                height: root.stateHeight(notchWindow.islandState)

                color: IslandStyle.pillColor
                // Borderless — a border would draw hairline seams at the top edge and
                // where the shoulders meet the body.

                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: root.cornerRadius
                bottomRightRadius: root.cornerRadius

                Behavior on width {
                    NumberAnimation { duration: root.morphDuration; easing.bezierCurve: root.goeyCurve }
                }
                Behavior on height {
                    NumberAnimation { duration: root.morphDuration; easing.bezierCurve: root.goeyCurve }
                }
                // No radius animation: the target radius is set instantly and Qt clamps
                // it to half the current height, so the bottom stays fully rounded at
                // every frame of the size morph — never a sharp/square phase.

                // Per-state content goes here (empty for now).
                MouseArea {
                    anchors.fill: parent
                    onClicked: notchWindow.cycle()
                }
            }
        }
    }
}
