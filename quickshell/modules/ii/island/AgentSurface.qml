pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// State-3 agent surface (click-to-open). Shows the orange PERMISSION CARD when a
// request is pending (tool + preview + Deny/Allow Once/Allow All/Bypass), else
// the SESSION LIST. Wires into the proven AgentService backend.
FocusScope {
    id: surf
    focus: true
    Keys.onEscapePressed: Island.close()

    readonly property color cOrange: "#E8A23D"
    readonly property color cGreen: "#7EE787"
    readonly property color cRed: "#E05561"
    readonly property bool hasPermission: AgentService.pendingPermissions.length > 0

    // small rounded chip ("Claude")
    component Chip: Rectangle {
        property string label: ""
        implicitHeight: 18
        implicitWidth: chipText.implicitWidth + 14
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.08)
        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: IslandStyle.subtextColor
        }
    }

    component PermBtn: Rectangle {
        id: btn
        property string label: ""
        property color accent: Qt.rgba(1, 1, 1, 0.10)
        property color fg: IslandStyle.textColor
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 9
        color: ma.containsMouse ? Qt.lighter(btn.accent, 1.25) : btn.accent
        Behavior on color { ColorAnimation { duration: 110 } }
        StyledText {
            anchors.centerIn: parent
            text: btn.label
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: btn.fg
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: surf.hasPermission ? permComp : listComp
    }

    // ===================== PERMISSION CARD =====================
    Component {
        id: permComp
        Item {
            anchors.fill: parent
            readonly property var p: AgentService.pendingPermissions[0] ?? null
            readonly property var sess: p ? (AgentService.sessions[p.session_id] ?? null) : null
            readonly property var preview: p?.preview ?? null
            property bool confirmingBypass: false
            Timer { id: bypassTimer; interval: 2500; onTriggered: confirmingBypass = false }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // header: mascot + project · prompt + chip
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 11
                    AgentSpinner { Layout.alignment: Qt.AlignVCenter; mode: "permission"; pixel: 2 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -1
                        StyledText {
                            Layout.fillWidth: true
                            text: (p?.project ?? "") + (sess?.summary ? "  ·  " + sess.summary : "")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: IslandStyle.textColor
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: sess?.message ? true : false
                            text: "You: " + (sess?.message ?? "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                            elide: Text.ElideRight
                        }
                    }
                    Chip { Layout.alignment: Qt.AlignVCenter; label: "Claude" }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        visible: AgentService.pendingPermissions.length > 1
                        text: "1 / " + AgentService.pendingPermissions.length
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: surf.cOrange
                    }
                }

                // ⚠ tool
                RowLayout {
                    spacing: 7
                    MaterialSymbol { text: "warning"; iconSize: 18; fill: 1; color: surf.cOrange }
                    StyledText { text: p?.tool ?? ""; font.pixelSize: Appearance.font.pixelSize.normal; font.weight: Font.DemiBold; color: IslandStyle.textColor }
                }

                // preview box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.05)
                    clip: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        RowLayout {
                            visible: (preview?.path ?? "") !== ""
                            StyledText { text: preview?.path ?? ""; font.family: "monospace"; font.pixelSize: Appearance.font.pixelSize.smaller; color: IslandStyle.textColor }
                            Rectangle {
                                visible: (preview?.kind ?? "") === "write"
                                radius: 4; color: Qt.rgba(0.49, 0.90, 0.53, 0.18)
                                implicitHeight: 16; implicitWidth: nf.implicitWidth + 10
                                StyledText { id: nf; anchors.centerIn: parent; text: "new file"; font.pixelSize: Appearance.font.pixelSize.smaller; color: surf.cGreen }
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: {
                                const k = preview?.kind ?? "generic";
                                if (k === "bash") return "$ " + (preview?.command ?? "");
                                if (k === "write") return preview?.body ?? "";
                                if (k === "edit") return (preview?.old ? "- " + preview.old + "\n" : "") + (preview?.new ? "+ " + preview.new : "");
                                return preview?.body ?? "";
                            }
                            font.family: "monospace"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                            wrapMode: Text.Wrap
                            verticalAlignment: Text.AlignTop
                        }
                    }
                }

                // buttons: Deny / Allow Once / Allow All / Bypass
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    PermBtn {
                        label: "Deny"
                        accent: Qt.rgba(1, 1, 1, 0.08)
                        onClicked: { if (p) AgentService.deny(p.request_id); }
                    }
                    PermBtn {
                        label: "Allow Once"
                        accent: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: { if (p) AgentService.allowOnce(p.request_id); }
                    }
                    PermBtn {
                        label: "Allow All"
                        accent: Qt.rgba(0.91, 0.64, 0.24, 0.85)
                        fg: "#1A1206"
                        onClicked: { if (p) AgentService.allowAll(p.request_id); }
                    }
                    PermBtn {
                        label: confirmingBypass ? "Confirm?" : "Bypass"
                        accent: confirmingBypass ? surf.cRed : Qt.rgba(0.88, 0.33, 0.38, 0.45)
                        fg: confirmingBypass ? "#FFFFFF" : surf.cRed
                        onClicked: {
                            if (!confirmingBypass) {
                                confirmingBypass = true;
                                bypassTimer.restart();
                            } else if (p) {
                                AgentService.bypass(p.request_id);
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: AgentService.sessionCount > 0
                    text: "Show all " + AgentService.sessionCount + " session" + (AgentService.sessionCount === 1 ? "" : "s")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: IslandStyle.subtextColor
                    MouseArea {
                        anchors.fill: parent
                        // resolving the permission switches to the list automatically;
                        // tapping here just acknowledges (no-op while pending).
                    }
                }
            }
        }
    }

    // ===================== SESSION LIST =====================
    Component {
        id: listComp
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                AgentSpinner { mode: "running"; pixel: 2 }
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    text: "Agent Island"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: IslandStyle.textColor
                }
                StyledText {
                    text: AgentService.sessionCount + " session" + (AgentService.sessionCount === 1 ? "" : "s")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: IslandStyle.subtextColor
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: AgentService.sessionList
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 46
                    radius: 10
                    color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                    HoverHandler { id: rowHover }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 9
                            implicitHeight: 9
                            radius: 4.5
                            color: modelData.status === "permission" ? surf.cOrange
                                 : modelData.status === "waiting" ? surf.cOrange
                                 : modelData.status === "working" ? "#7AA2F7"
                                 : modelData.status === "done" ? surf.cGreen
                                 : IslandStyle.subtextColor
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1
                            StyledText {
                                Layout.fillWidth: true
                                text: (modelData.project || "session") + (modelData.summary ? "  ·  " + modelData.summary : "")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: IslandStyle.textColor
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: (modelData.message || "") !== ""
                                text: "You: " + modelData.message
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: IslandStyle.subtextColor
                                elide: Text.ElideRight
                            }
                        }
                        Chip { Layout.alignment: Qt.AlignVCenter; label: "Claude" }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.status
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                        }
                    }
                }
            }

            // empty state
            ColumnLayout {
                visible: AgentService.sessionList.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Item { Layout.fillHeight: true }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: "No agent sessions"; color: IslandStyle.subtextColor; font.pixelSize: Appearance.font.pixelSize.small }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
