pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects

// Animated agent status label: optional cycling dots ("Working" → "Working...")
// and an optional shimmer sweep across the glyphs. Width is reserved for the max
// dot count so the cycling never jitters the notch.
Item {
    id: root
    property string word: ""
    property bool animateDots: false
    property bool shimmer: false
    property int pixelSize: Appearance.font.pixelSize.small
    property color baseColor: IslandStyle.textColor

    property int dots: 0
    Timer {
        interval: 380
        running: root.animateDots && root.visible
        repeat: true
        onTriggered: root.dots = (root.dots + 1) % 4
    }
    readonly property string shown: root.word + (root.animateDots ? "....".substring(0, root.dots) : "")
    readonly property string maxStr: root.word + (root.animateDots ? "..." : "")

    implicitWidth: maskText.implicitWidth
    implicitHeight: maskText.implicitHeight

    // hidden, max-width copy — drives layout width + shimmer mask shape
    StyledText {
        id: maskText
        text: root.maxStr
        font.pixelSize: root.pixelSize
        font.weight: Font.Medium
        color: "white"
        visible: false
    }
    // visible (dim while shimmering) text
    StyledText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.shown
        font.pixelSize: root.pixelSize
        font.weight: Font.Medium
        color: root.baseColor
        opacity: root.shimmer ? 0.72 : 1.0
    }
    // bright band sweeping across, clipped to the text glyphs
    Item {
        anchors.fill: maskText
        visible: root.shimmer
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: maskText }
        Rectangle {
            id: band
            height: parent.height
            width: Math.max(20, maskText.implicitWidth * 0.45)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "#FFFFFF" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                running: root.shimmer && root.visible
                from: -band.width
                to: maskText.implicitWidth + band.width
                duration: 1700
                loops: Animation.Infinite
            }
        }
    }
}
