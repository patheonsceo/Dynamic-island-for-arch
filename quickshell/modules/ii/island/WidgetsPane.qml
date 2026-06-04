pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris

// Widgets tab content: media player · quick toggles · volume/mic sliders ·
// calendar · notification centre · power-profile selector · live stat bars.
Item {
    id: pane

    // ---------- reusable bits ----------
    component ToggleChip: Rectangle {
        id: chip
        property string icon
        property string label
        property string sublabel
        property bool active: false
        signal toggled
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 10
        color: active ? Qt.rgba(0.54, 0.70, 0.97, 0.18) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: active ? Qt.rgba(0.54, 0.70, 0.97, 0.5) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
            MaterialSymbol {
                text: chip.icon
                iconSize: 18
                fill: chip.active ? 1 : 0
                color: chip.active ? IslandStyle.accent : IslandStyle.textColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: chip.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: IslandStyle.textColor
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: chip.sublabel !== ""
                    text: chip.sublabel
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: IslandStyle.subtextColor
                    elide: Text.ElideRight
                }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: chip.toggled() }
    }

    component HSlider: Rectangle {
        id: sl
        property string icon
        property real value: 0
        signal moved(real v)
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 8
            MaterialSymbol { text: sl.icon; iconSize: 16; color: IslandStyle.textColor }
            Item {
                Layout.fillWidth: true
                implicitHeight: 30
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.15)
                    Rectangle {
                        height: parent.height
                        radius: 2.5
                        width: parent.width * Math.max(0, Math.min(1, sl.value))
                        color: IslandStyle.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: m => sl.moved(Math.max(0, Math.min(1, m.x / width)))
                    onPositionChanged: m => { if (pressed) sl.moved(Math.max(0, Math.min(1, m.x / width))); }
                }
            }
        }
    }

    component VBar: ColumnLayout {
        id: vb
        property real value: 0
        property string label: ""
        property color barColor: IslandStyle.accent
        spacing: 3
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 16
            Layout.alignment: Qt.AlignHCenter
            Rectangle { anchors.fill: parent; radius: 5; color: Qt.rgba(1, 1, 1, 0.08) }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 5
                height: parent.height * Math.max(0.03, Math.min(1, vb.value))
                color: vb.barColor
                Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutQuad } }
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: vb.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: IslandStyle.subtextColor
        }
    }

    // ---------- layout ----------
    RowLayout {
        anchors.fill: parent
        spacing: 10

        // === Media player ===
        Rectangle {
            id: mp
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.05)

            readonly property var player: MprisController.activePlayer
            readonly property string artUrl: player?.trackArtUrl ?? ""
            readonly property string artPath: artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(artUrl)}` : ""
            property string artLocal: ""
            readonly property string trackKey: player?.trackTitle ?? ""
            onTrackKeyChanged: artLocal = ""
            onArtPathChanged: {
                if (artPath.length === 0)
                    return;
                artDl.outFile = artPath;
                artDl.url = artUrl;
                artDl.running = true;
            }
            Process {
                id: artDl
                property string url: ""
                property string outFile: ""
                command: ["bash", "-c", `[ -f '${outFile}' ] || curl -4 -sSL '${url}' -o '${outFile}'`]
                onExited: code => { if (code === 0) mp.artLocal = Qt.resolvedUrl(artDl.outFile); }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 88
                    implicitHeight: 88
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.08) }
                    StyledImage {
                        id: art
                        anchors.fill: parent
                        source: mp.artLocal
                        fillMode: Image.PreserveAspectCrop
                        visible: mp.artLocal !== "" && status === Image.Ready
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: art.width; height: art.height; radius: width / 2 }
                        }
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !art.visible
                        text: "music_note"
                        iconSize: 32
                        color: IslandStyle.subtextColor
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: 6
                        color: "#000000"
                        opacity: 0.85
                        visible: art.visible
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: mp.player?.trackTitle || "Nothing playing"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: IslandStyle.textColor
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: mp.player?.trackArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: IslandStyle.subtextColor
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    MaterialSymbol {
                        text: "skip_previous"; iconSize: 22; fill: 1; color: IslandStyle.textColor
                        MouseArea { anchors.fill: parent; onClicked: mp.player?.previous() }
                    }
                    MaterialSymbol {
                        text: (mp.player?.isPlaying ?? false) ? "pause_circle" : "play_circle"
                        iconSize: 32; fill: 1; color: IslandStyle.textColor
                        MouseArea { anchors.fill: parent; onClicked: mp.player?.togglePlaying() }
                    }
                    MaterialSymbol {
                        text: "skip_next"; iconSize: 22; fill: 1; color: IslandStyle.textColor
                        MouseArea { anchors.fill: parent; onClicked: mp.player?.next() }
                    }
                }
            }
        }

        // === Center column: toggles · sliders · calendar+notifications ===
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ToggleChip {
                    icon: Network.materialSymbol
                    label: "Wi-Fi"
                    sublabel: Network.wifiEnabled ? (Network.networkName || "On") : "Off"
                    active: Network.wifiEnabled
                    onToggled: Network.toggleWifi()
                }
                ToggleChip {
                    icon: "bluetooth"
                    label: "Bluetooth"
                    sublabel: BluetoothStatus.enabled ? (BluetoothStatus.connected ? "Connected" : "On") : "Off"
                    active: BluetoothStatus.enabled
                    onToggled: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; }
                }
                ToggleChip {
                    icon: "nightlight"
                    label: "Night Mode"
                    sublabel: Hyprsunset.temperatureActive ? "Enabled" : "Disabled"
                    active: Hyprsunset.temperatureActive
                    onToggled: Hyprsunset.toggleTemperature()
                }
                ToggleChip {
                    icon: "coffee"
                    label: "Caffeine"
                    sublabel: Idle.inhibit ? "Enabled" : "Disabled"
                    active: Idle.inhibit
                    onToggled: Idle.toggleInhibit()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                HSlider {
                    icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                    value: Audio.sink?.audio?.volume ?? 0
                    onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.volume = v; }
                }
                HSlider {
                    icon: (Audio.source?.audio?.muted ?? false) ? "mic_off" : "mic"
                    value: Audio.source?.audio?.volume ?? 0
                    onMoved: v => { if (Audio.source?.audio) Audio.source.audio.volume = v; }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 232
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    WidgetCalendar {
                        anchors.fill: parent
                        anchors.margins: 10
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "Notifications"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: IslandStyle.textColor
                            }
                            MaterialSymbol {
                                text: "delete_sweep"
                                iconSize: 18
                                color: IslandStyle.subtextColor
                                visible: Notifications.list.length > 0
                                MouseArea { anchors.fill: parent; onClicked: Notifications.discardAllNotifications() }
                            }
                        }
                        ColumnLayout {
                            visible: Notifications.list.length === 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Item { Layout.fillHeight: true }
                            MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "notifications_off"; iconSize: 30; color: IslandStyle.subtextColor }
                            StyledText { Layout.alignment: Qt.AlignHCenter; text: "No notifications"; font.pixelSize: Appearance.font.pixelSize.smaller; color: IslandStyle.subtextColor }
                            Item { Layout.fillHeight: true }
                        }
                        ListView {
                            visible: Notifications.list.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 5
                            model: Notifications.list
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                implicitHeight: ncol.implicitHeight + 12
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                ColumnLayout {
                                    id: ncol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.appName
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: IslandStyle.subtextColor
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.summary
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: IslandStyle.textColor
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // === Right column: power-profile selector + live stat bars ===
        ColumnLayout {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            spacing: 8

            ColumnLayout {
                id: modeSel
                Layout.fillWidth: true
                spacing: 5
                property string current: "balanced"
                readonly property var modes: [
                    { "key": "power-saver", "icon": "energy_savings_leaf", "label": "Saver" },
                    { "key": "balanced", "icon": "balance", "label": "Normal" },
                    { "key": "performance", "icon": "rocket_launch", "label": "Performance" }
                ]
                Process {
                    id: getProf
                    command: ["powerprofilesctl", "get"]
                    stdout: SplitParser { onRead: d => modeSel.current = d.trim() }
                }
                Component.onCompleted: getProf.running = true
                Repeater {
                    model: modeSel.modes
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 8
                        readonly property bool sel: modeSel.current === modelData.key
                        color: sel ? Qt.rgba(0.54, 0.70, 0.97, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: sel ? Qt.rgba(0.54, 0.70, 0.97, 0.5) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            spacing: 7
                            MaterialSymbol { text: modelData.icon; iconSize: 15; color: parent.parent.sel ? IslandStyle.accent : IslandStyle.textColor }
                            StyledText { text: modelData.label; font.pixelSize: Appearance.font.pixelSize.smaller; color: IslandStyle.textColor }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                modeSel.current = modelData.key;
                                Quickshell.execDetached(["powerprofilesctl", "set", modelData.key]);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    VBar { value: ResourceUsage.cpuUsage; label: "CPU"; barColor: IslandStyle.accent }
                    VBar { value: ResourceUsage.memoryUsedPercentage; label: "RAM"; barColor: "#A0E7A0" }
                    VBar { value: ResourceUsage.swapUsedPercentage; label: "SWP"; barColor: "#E7C0A0" }
                }
            }
        }
    }
}
