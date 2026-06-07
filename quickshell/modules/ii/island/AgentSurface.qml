pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// State-3 agent surface (click-to-open). Shows the orange PERMISSION CARD when a
// request is pending (tool + preview + Deny/Allow Once/Allow All/Bypass), else
// the SESSION LIST. Wires into the proven AgentService backend.
FocusScope {
    id: surf
    focus: true
    Keys.onEscapePressed: Island.close()

    readonly property color cOrange: "#E8A23D"
    readonly property color cGreen: "#7EE787"
    readonly property color cBlue: "#7AA2F7"
    readonly property color cRed: "#E05561"
    readonly property bool hasPermission: AgentService.pendingPermissions.length > 0
    property string expandedId: ""  // "" → the first (most-urgent) row is expanded
    property bool viewList: false   // peek the list while a permission is pending
    onHasPermissionChanged: if (hasPermission) surf.viewList = false  // new permission → show the card

    function relTime(ts) {
        if (!ts)
            return "";
        const age = Math.max(0, Math.floor(AgentService.now - ts));  // AgentService.now ticks every 1s
        if (age < 60) return age + "s";
        if (age < 3600) return Math.floor(age / 60) + "m";
        if (age < 86400) return Math.floor(age / 3600) + "h";
        return Math.floor(age / 86400) + "d";
    }
    function statusLabel(s) {
        return s === "working" ? "Working…" : s === "waiting" ? "Waiting for input"
             : s === "permission" ? "Needs approval" : s === "done" ? "Done" : "Idle";
    }
    function statusColor(s) {
        return s === "permission" || s === "waiting" ? surf.cOrange
             : s === "working" ? surf.cBlue : s === "done" ? surf.cGreen : IslandStyle.subtextColor;
    }

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
        sourceComponent: (surf.hasPermission && !surf.viewList) ? permComp : listComp
    }

    // ===================== PERMISSION CARD =====================
    Component {
        id: permComp
        Item {
            id: card
            anchors.fill: parent
            readonly property var p: AgentService.pendingPermissions[0] ?? null
            readonly property var sess: p ? (AgentService.sessions[p.session_id] ?? null) : null
            readonly property var preview: p?.preview ?? null
            property bool confirmingBypass: false
            Timer { id: bypassTimer; interval: 2500; onTriggered: confirmingBypass = false }

            // entrance: slide up + fade in
            opacity: 0
            transform: Translate { id: cardTr; y: 16 }
            Component.onCompleted: cardIn.start()
            ParallelAnimation {
                id: cardIn
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: cardTr; property: "y"; to: 0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }

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
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: (p?.project ?? "") || "session"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: IslandStyle.textColor
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: (sess?.prompt ?? "") !== ""
                            text: "You: " + (sess?.prompt ?? "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: IslandStyle.subtextColor
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
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
                        Item {
                            id: pview
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            property real scrollY: 0
                            readonly property real maxScroll: Math.max(0, bodyText.implicitHeight - height)
                            onMaxScrollChanged: scrollY = Math.min(scrollY, maxScroll)
                            StyledText {
                                id: bodyText
                                width: pview.width - 6
                                y: -pview.scrollY
                                text: {
                                    const k = card.preview?.kind ?? "generic";
                                    if (k === "bash") return "$ " + (card.preview?.command ?? "");
                                    if (k === "write") return card.preview?.body ?? "";
                                    if (k === "edit") return (card.preview?.old ? "- " + card.preview.old + "\n" : "") + (card.preview?.new ? "+ " + card.preview.new : "");
                                    return card.preview?.body ?? "";
                                }
                                font.family: "monospace"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: IslandStyle.subtextColor
                                wrapMode: Text.Wrap
                            }
                            // drag-to-scroll (robust; wheel-up isn't delivered to layer
                            // surfaces under nested Hyprland) + wheel for good measure
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: pview.maxScroll > 0 ? Qt.OpenHandCursor : Qt.ArrowCursor
                                property real lastY: 0
                                onPressed: m => lastY = m.y
                                onPositionChanged: m => {
                                    if (pressed)
                                        pview.scrollY = Math.max(0, Math.min(pview.maxScroll, pview.scrollY - (m.y - lastY)));
                                    lastY = m.y;
                                }
                                onWheel: wheel => {
                                    pview.scrollY = Math.max(0, Math.min(pview.maxScroll, pview.scrollY - wheel.angleDelta.y * 0.6));
                                }
                            }
                            // scrollbar indicator
                            Rectangle {
                                visible: pview.maxScroll > 0
                                anchors.right: parent.right
                                width: 3
                                radius: 1.5
                                color: Qt.rgba(1, 1, 1, 0.22)
                                height: Math.max(18, pview.height * (pview.height / Math.max(1, bodyText.implicitHeight)))
                                y: pview.maxScroll > 0 ? (pview.scrollY / pview.maxScroll) * (pview.height - height) : 0
                            }
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
                    id: showAll
                    Layout.alignment: Qt.AlignHCenter
                    visible: AgentService.sessionCount > 0
                    text: "Show all " + AgentService.sessionCount + " session" + (AgentService.sessionCount === 1 ? "" : "s")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: showAllMa.containsMouse ? IslandStyle.textColor : IslandStyle.subtextColor
                    MouseArea {
                        id: showAllMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: surf.viewList = true
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

            // peeking the list while a permission is pending → banner back to the card
            Rectangle {
                visible: surf.hasPermission
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: bannerMa.containsMouse ? Qt.rgba(0.91, 0.64, 0.24, 0.28) : Qt.rgba(0.91, 0.64, 0.24, 0.18)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    MaterialSymbol { text: "warning"; iconSize: 15; fill: 1; color: surf.cOrange }
                    StyledText {
                        Layout.fillWidth: true
                        text: AgentService.pendingPermissions.length + " permission" + (AgentService.pendingPermissions.length === 1 ? "" : "s") + " pending — review"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: IslandStyle.textColor
                    }
                    MaterialSymbol { text: "chevron_right"; iconSize: 16; color: surf.cOrange }
                }
                MouseArea { id: bannerMa; anchors.fill: parent; hoverEnabled: true; onClicked: surf.viewList = false }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: AgentService.sessionList
                delegate: Rectangle {
                    id: srow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    readonly property bool expanded: surf.expandedId !== "" ? (surf.expandedId === srow.modelData.id) : (srow.index === 0)
                    implicitHeight: srowCol.implicitHeight + 16
                    radius: 10
                    color: srow.expanded ? Qt.rgba(1, 1, 1, 0.07)
                         : srowHover.hovered ? Qt.rgba(1, 1, 1, 0.05)
                         : Qt.rgba(1, 1, 1, 0.03)
                    Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    HoverHandler { id: srowHover }

                    ColumnLayout {
                        id: srowCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 9
                                implicitHeight: 9
                                radius: 4.5
                                color: surf.statusColor(srow.modelData.status)
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: srow.modelData.project || "session"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: IslandStyle.textColor
                                elide: Text.ElideRight
                            }
                            Chip { Layout.alignment: Qt.AlignVCenter; label: "Claude" }
                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                text: surf.relTime(srow.modelData.ts)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: IslandStyle.subtextColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 19
                            Layout.topMargin: 3
                            visible: srow.expanded
                            spacing: 6
                            // the user's request — given room to breathe (up to 2 lines)
                            StyledText {
                                Layout.fillWidth: true
                                visible: (srow.modelData.prompt || "") !== ""
                                text: "You: " + srow.modelData.prompt
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: IslandStyle.subtextColor
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            // status + current action (the command) as a SHORT, dimmed,
                            // single-line tail — never mushed into the title anymore
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                StyledText {
                                    text: surf.statusLabel(srow.modelData.status)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: surf.statusColor(srow.modelData.status)
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: (srow.modelData.summary || "") !== "" && srow.modelData.summary !== "{}"
                                    text: srow.modelData.summary
                                    font.family: "monospace"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: IslandStyle.subtextColor
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: surf.expandedId = srow.modelData.id
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
