pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Center notch — top-attached, morphing. THE STAR.
//
// Shape: hangs from top-center; square top corners flush with the screen edge,
// rounded bottom (constant radius), concave RoundCorner shoulders. Borderless fill.
// Reserves a top strip (exclusiveZone) so maximized windows sit BELOW the islands.
//
// State machine (precedence: agent > media > volume/brightness > notification > idle).
// Transient OSDs auto-hide; media shows only while PLAYING. `open` is click-toggled.
// Goey overshoot morph (cubic-bezier 0.34,1.22,0.64,1).
Scope {
    id: root

    readonly property list<real> goeyCurve: [0.34, 1.22, 0.64, 1, 1, 1]
    readonly property int morphDuration: 330
    readonly property int shoulderSize: 20
    readonly property int cornerRadius: 18
    readonly property int maxWidth: 1100          // widest open surface (overview) — also sizes the window
    readonly property int maxHeight: 400
    readonly property int expandedMaxWidth: 480   // cap for transient OSDs (volume/brightness/media/notif)
    readonly property int reservedStrip: 40       // top space reserved for the island strip

    // Open-state surface sizes — notch body w×h per named surface (Island.openSurface).
    readonly property var surfaceSizes: ({
            "dashboard": { "w": 1040, "h": 360 },
            "overview":  { "w": 1100, "h": 300 },
            "launcher":  { "w": 560,  "h": 380 },
            "power":     { "w": 320,  "h": 92  },
            "tools":     { "w": 440,  "h": 84  }
        })

    // Media (shared across monitors). Show only while actively playing.
    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool mediaActive: activePlayer?.isPlaying ?? false
    property list<real> visualizerPoints: []

    // Cover art: download the (often remote / flickery) trackArtUrl to a stable local
    // cache file so the art doesn't vanish when the player rewrites/clears the URL.
    readonly property string artUrl: activePlayer?.trackArtUrl ?? ""
    readonly property string artFilePath: artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(artUrl)}` : ""
    // Persisted local art path. Only cleared on an actual TRACK change — NOT when the
    // player momentarily rewrites/clears artUrl (which made the art vanish). Set only
    // once the cache file is confirmed present (exit 0).
    property string displayedArt: ""
    readonly property string trackKey: activePlayer?.trackTitle ?? ""
    onTrackKeyChanged: displayedArt = ""
    onArtFilePathChanged: {
        if (artFilePath.length === 0)
            return; // transient empty URL — keep the current art
        coverArtDownloader.outFile = artFilePath;
        coverArtDownloader.targetUrl = artUrl;
        coverArtDownloader.running = true;
    }
    Process {
        id: coverArtDownloader
        property string targetUrl: ""
        property string outFile: ""
        command: ["bash", "-c", `[ -f '${outFile}' ] || curl -4 -sSL '${targetUrl}' -o '${outFile}'`]
        onExited: (code, status) => {
            if (code === 0)
                root.displayedArt = Qt.resolvedUrl(coverArtDownloader.outFile);
        }
    }

    Process {
        id: cavaProc
        running: root.mediaActive
        onRunningChanged: {
            if (!cavaProc.running)
                root.visualizerPoints = [];
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notchWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:islandNotch"
            WlrLayershell.layer: WlrLayer.Top
            // Grab keyboard only while a surface is open (Esc / tab-nav / search typing).
            WlrLayershell.keyboardFocus: notchWindow.islandState === "open" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"
            // Reserve the top strip so windows open below the island row.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.reservedStrip

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

            // --- state machine ---
            property string expandedSource: ""  // transient OSD: volume|brightness|notification|""
            property string displaySource: expandedSource !== "" ? expandedSource : (root.mediaActive ? "media" : "")
            // open (a named surface is up) outranks transient OSDs, which outrank idle.
            property string islandState: Island.openSurface !== "" ? "open"
                : (displaySource !== "" ? "expanded" : "idle")

            Timer {
                id: hideTimer
                onTriggered: notchWindow.expandedSource = ""
            }
            function trigger(src, ms) {
                expandedSource = src;
                hideTimer.interval = ms;
                hideTimer.restart();
            }

            property string notifApp: ""
            property string notifSummary: ""
            property string notifIcon: ""
            readonly property var brightnessMonitor: Brightness.getMonitorForScreen(notchWindow.screen)

            // Downsampled equalizer bars from the cava points (0..1).
            readonly property int barCount: 22
            property var barValues: {
                const pts = root.visualizerPoints;
                const n = barCount;
                let out = [];
                for (let i = 0; i < n; i++) {
                    if (pts && pts.length > 0) {
                        const idx = Math.floor(i * pts.length / n);
                        out.push(Math.max(0, Math.min(1, (pts[idx] ?? 0) / 1000)));
                    } else {
                        out.push(0);
                    }
                }
                return out;
            }

            Connections {
                target: Audio.sink?.audio ?? null
                function onVolumeChanged() {
                    if (Audio.ready)
                        notchWindow.trigger("volume", 2000);
                }
                function onMutedChanged() {
                    if (Audio.ready)
                        notchWindow.trigger("volume", 2000);
                }
            }
            Connections {
                target: Brightness
                function onBrightnessChanged() {
                    notchWindow.trigger("brightness", 2000);
                }
            }
            Connections {
                target: Notifications
                function onNotify(notification) {
                    notchWindow.notifApp = notification.appName ?? "";
                    notchWindow.notifSummary = notification.summary ?? "";
                    notchWindow.notifIcon = notification.appIcon ?? "";
                    notchWindow.trigger("notification", 4000);
                }
            }

            property real contentWidth: {
                switch (displaySource) {
                case "volume":
                    return volumeUI.implicitWidth;
                case "brightness":
                    return brightnessUI.implicitWidth;
                case "notification":
                    return notifUI.implicitWidth;
                case "media":
                    return mediaUI.implicitWidth;
                default:
                    return 0;
                }
            }
            property real targetWidth: islandState === "open" ? (root.surfaceSizes[Island.openSurface]?.w ?? root.maxWidth)
                : islandState === "expanded" ? Math.min(root.expandedMaxWidth, contentWidth + 36)
                : 180
            property real targetHeight: islandState === "open" ? (root.surfaceSizes[Island.openSurface]?.h ?? root.maxHeight)
                : islandState === "expanded" ? (displaySource === "media" ? 40 : 54)
                : 36

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
                clip: true
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
                    // Click the notch body: open the dashboard from idle/OSD, or close
                    // whatever surface is up (surface content sits on top with its own
                    // handlers; this catches clicks on the surrounding padding).
                    onClicked: {
                        if (Island.openSurface === "")
                            Island.open("dashboard");
                        else
                            Island.close();
                    }
                }

                // ---- volume ----
                RowLayout {
                    id: volumeUI
                    anchors.centerIn: parent
                    spacing: 9
                    opacity: notchWindow.islandState === "expanded" && notchWindow.displaySource === "volume" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
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
                    OsdBar {
                        value: Audio.sink?.audio?.volume ?? 0
                        accent: (Audio.sink?.audio?.muted ?? false) ? Qt.rgba(1, 1, 1, 0.4) : IslandStyle.accent
                    }
                    OsdPercent { value: Audio.sink?.audio?.volume ?? 0 }
                }

                // ---- brightness ----
                RowLayout {
                    id: brightnessUI
                    anchors.centerIn: parent
                    spacing: 9
                    opacity: notchWindow.islandState === "expanded" && notchWindow.displaySource === "brightness" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: 20
                        fill: 1
                        color: IslandStyle.textColor
                        text: (notchWindow.brightnessMonitor?.brightness ?? 1) < 0.5 ? "brightness_low" : "brightness_high"
                    }
                    OsdBar {
                        value: notchWindow.brightnessMonitor?.brightness ?? 0
                        accent: "#FFD479"
                    }
                    OsdPercent { value: notchWindow.brightnessMonitor?.brightness ?? 0 }
                }

                // ---- notification ----
                RowLayout {
                    id: notifUI
                    anchors.centerIn: parent
                    spacing: 9
                    opacity: notchWindow.islandState === "expanded" && notchWindow.displaySource === "notification" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        active: notchWindow.notifIcon !== ""
                        visible: active
                        sourceComponent: IconImage {
                            implicitSize: 22
                            source: Quickshell.iconPath(notchWindow.notifIcon, "dialog-information-symbolic")
                        }
                    }
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        visible: notchWindow.notifIcon === ""
                        iconSize: 20
                        fill: 1
                        color: IslandStyle.textColor
                        text: "notifications"
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -2
                        StyledText {
                            Layout.maximumWidth: 280
                            visible: notchWindow.notifApp !== ""
                            text: notchWindow.notifApp
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                        }
                        StyledText {
                            Layout.maximumWidth: 280
                            text: notchWindow.notifSummary
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: IslandStyle.textColor
                        }
                    }
                }

                // ---- media: art · equalizer bars · play/pause (minimal, reference-style) ----
                RowLayout {
                    id: mediaUI
                    anchors.centerIn: parent
                    spacing: 10
                    opacity: notchWindow.islandState === "expanded" && notchWindow.displaySource === "media" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.08)
                        StyledImage {
                            id: artImg
                            anchors.fill: parent
                            source: root.displayedArt
                            fillMode: Image.PreserveAspectCrop
                            visible: root.displayedArt !== "" && status === Image.Ready
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: artImg.width
                                    height: artImg.height
                                    radius: 7
                                }
                            }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !artImg.visible
                            text: "music_note"
                            iconSize: 16
                            color: IslandStyle.textColor
                        }
                    }

                    // Equalizer bars
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 112
                        implicitHeight: 24
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: notchWindow.barCount
                                delegate: Item {
                                    id: barCell
                                    required property int index
                                    width: 3
                                    height: 24
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 3
                                        radius: 1.5
                                        color: IslandStyle.accent
                                        height: Math.max(3, (notchWindow.barValues[barCell.index] ?? 0) * 22)
                                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                                    }
                                }
                            }
                        }
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: 24
                        fill: 1
                        color: IslandStyle.textColor
                        text: root.mediaActive ? "pause" : "play_arrow"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.activePlayer?.togglePlaying()
                        }
                    }
                }

                // ---- open-state surface host (dashboard / power / tools / launcher / overview) ----
                FocusScope {
                    id: surfaceHost
                    anchors.fill: parent
                    visible: notchWindow.islandState === "open"
                    focus: visible
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                    Loader {
                        id: surfaceLoader
                        anchors.fill: parent
                        active: surfaceHost.visible
                        focus: true
                        sourceComponent: {
                            switch (Island.openSurface) {
                            case "dashboard":
                                return dashboardComp;
                            case "power":
                                return powerComp;
                            default:
                                return null;
                            }
                        }
                    }
                    Component { id: dashboardComp; DashboardSurface { focus: true } }
                    Component { id: powerComp; PowerSurface { focus: true } }
                }
            }
        }
    }

    // Small reusable OSD bits.
    component OsdBar: Rectangle {
        id: bar
        property real value: 0
        property color accent: IslandStyle.accent
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 110
        implicitHeight: 6
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.18)
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: bar.height
            width: bar.width * Math.max(0, Math.min(1, bar.value))
            radius: height / 2
            color: bar.accent
            Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        }
    }
    component OsdPercent: StyledText {
        property real value: 0
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 26
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(Math.max(0, Math.min(1, value)) * 100)}`
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: IslandStyle.textColor
    }
}
