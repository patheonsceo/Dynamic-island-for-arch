pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Month-grid calendar for the Widgets tab. Today highlighted; prev/next month.
Item {
    id: cal
    readonly property date today: DateTime.clock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-11

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function firstWeekday(y, m) { return new Date(y, m, 1).getDay(); } // 0=Sun
    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear--; } else viewMonth--;
    }
    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++; } else viewMonth++;
    }

    // 42-cell (6-week) grid; 0 = blank padding cell.
    readonly property var cells: {
        let arr = [];
        const fw = firstWeekday(viewYear, viewMonth);
        const dim = daysInMonth(viewYear, viewMonth);
        for (let i = 0; i < 42; i++) {
            const d = i - fw + 1;
            arr.push(d >= 1 && d <= dim ? d : 0);
        }
        return arr;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            MaterialSymbol {
                text: "chevron_left"; iconSize: 18; color: IslandStyle.subtextColor
                MouseArea { anchors.fill: parent; onClicked: cal.prevMonth() }
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: `${cal.monthNames[cal.viewMonth]} ${cal.viewYear}`
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: IslandStyle.textColor
            }
            MaterialSymbol {
                text: "chevron_right"; iconSize: 18; color: IslandStyle.subtextColor
                MouseArea { anchors.fill: parent; onClicked: cal.nextMonth() }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 0; columnSpacing: 0
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                delegate: StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: IslandStyle.subtextColor
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 1; columnSpacing: 1
            Repeater {
                model: cal.cells
                delegate: Item {
                    id: dayCell
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property bool isToday: modelData === cal.today.getDate()
                        && cal.viewMonth === cal.today.getMonth()
                        && cal.viewYear === cal.today.getFullYear()
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(dayCell.width, dayCell.height) - 2
                        height: width
                        radius: width / 2
                        visible: dayCell.modelData > 0
                        color: dayCell.isToday ? IslandStyle.accent : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: dayCell.modelData > 0 ? dayCell.modelData : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: dayCell.isToday ? "#000000" : IslandStyle.textColor
                        }
                    }
                }
            }
        }
    }
}
