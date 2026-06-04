pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Center notch — top-attached, morphing. THE STAR.
//
// Shape: hangs from the top-center; SQUARE top corners flush with the screen edge,
// ROUNDED bottom corners (constant radius). Concave RoundCorner shoulders blend it
// fluidly into the top edge. Borderless solid fill.
//
// State machine (precedence: agent > media > volume/brightness > notification > idle;
// only volume wired so far). `open` is a click-toggled full view.
//   idle      — small empty visible shape
//   expanded  — medium; transient content (volume now; brightness/media/agent later)
//   open      — large; click-toggled
// Morph uses a lively-but-controlled goey overshoot (cubic-bezier 0.34,1.22,0.64,1).
Scope {
    id: root

    readonly property list<real> goeyCurve: [0.34, 1.22, 0.64, 1, 1, 1]
    readonly property int morphDuration: 330
    readonly property int shoulderSize: 20
    readonly property int cornerRadius: 18
    readonly property int maxWidth: 480
    readonly property int maxHeight: 300

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

            implicitWidth: root.maxWidth + root.shoulderSize * 2
            implicitHeight: root.maxHeight
            mask: Region {
                item: notch
            }

            // --- state machine (precedence) ---
            property bool clickedOpen: false
            property bool volumeActive: volumeTimer.running
            property string islandState: clickedOpen ? "open" : volumeActive ? "expanded" : "idle"

            // Target geometry: idle/open fixed; expanded fits the active content.
            property real targetWidth: islandState === "open" ? root.maxWidth
                : islandState === "expanded" ? (volumeUI.implicitWidth + 44)
                : 180
            property real targetHeight: islandState === "open" ? root.maxHeight
                : islandState === "expanded" ? 54
                : 36

            // Volume: trigger on the actual audio VALUE (not the flicker-prone OSD flag).
            Timer {
                id: volumeTimer
                interval: 2000
            }
            Connections {
                target: Audio.sink?.audio ?? null
                function onVolumeChanged() {
                    if (Audio.ready)
                        volumeTimer.restart();
                }
                function onMutedChanged() {
                    if (Audio.ready)
                        volumeTimer.restart();
                }
            }

            // Left/right concave shoulders (overlap notch 1px to avoid a seam).
            RoundCorner {
                corner: RoundCorner.CornerEnum.TopRight
                color: IslandStyle.pillColor
                implicitSize: root.shoulderSize
                anchors.right: notch.left
                anchors.rightMargin: -1
                anchors.top: parent.top
            }
            RoundCorner {
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

                width: notchWindow.targetWidth
                height: notchWindow.targetHeight

                color: IslandStyle.pillColor
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: notchWindow.clickedOpen = !notchWindow.clickedOpen
                }

                // --- volume content (expanded) ---
                RowLayout {
                    id: volumeUI
                    anchors.centerIn: parent
                    spacing: 9
                    opacity: (notchWindow.islandState === "expanded" && notchWindow.volumeActive) ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: 20
                        fill: 1
                        color: IslandStyle.textColor
                        text: {
                            const a = Audio.sink?.audio;
                            if (!a || a.muted)
                                return "volume_off";
                            if (a.volume <= 0.0001)
                                return "volume_mute";
                            if (a.volume < 0.5)
                                return "volume_down";
                            return "volume_up";
                        }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 110
                        implicitHeight: 6
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.18)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, Audio.sink?.audio?.volume ?? 0))
                            radius: height / 2
                            color: (Audio.sink?.audio?.muted ?? false) ? Qt.rgba(1, 1, 1, 0.4) : IslandStyle.accent
                            Behavior on width {
                                NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 26
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: IslandStyle.textColor
                    }
                }
            }
        }
    }
}
