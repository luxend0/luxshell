import QtQuick
import qs.config
import qs.widgets

// One block of a sheet (ref/09): dim caption ("Saved", "Nearby"), optional status
// at the right ("• Scanning") or a small text action, then rows. With showHint
// the rows give way to one dim line ("Looking for devices...").
Item {
    id: section

    readonly property QtObject sh: Theme.cc.sheet

    property string caption
    property string status: ""        // right of the caption, dim
    property bool statusDot: true     // leading dot ("• Scanning")
    property string action: ""        // clickable text in the same place, when there is no status
    property string hint: ""
    property bool showHint: false
    signal actionClicked

    default property alias content: column.data

    width: parent ? parent.width : 0
    implicitHeight: sh.captionGap + (showHint ? sh.hintHeight : column.implicitHeight)
    height: implicitHeight

    SheetText {
        x: section.sh.captionX
        capY: section.sh.captionY
        px: section.sh.captionSize
        text: section.caption
        color: section.sh.captionColor
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: section.sh.statusRight
        y: Math.round(section.sh.captionY - height / 2)
        height: 20
        spacing: 8
        visible: section.status !== ""

        // the dot pulses between grey and white while the status is live (ref/09c:
        // white in one frame, grey in the next). Timer steps, not a running
        // animation, so the surface only repaints during the short fades.
        Rectangle {
            id: dot
            property bool bright: false
            anchors.verticalCenter: parent.verticalCenter
            visible: section.statusDot
            width: section.sh.dot
            height: width
            radius: width / 2
            color: bright ? Theme.text : Theme.textDim
            Behavior on color {
                ColorAnim {
                    ms: 300
                }
            }
            Timer {
                running: dot.visible && section.visible
                repeat: true
                interval: Motion.ms(700)
                onTriggered: dot.bright = !dot.bright
                onRunningChanged: if (!running)
                    dot.bright = false
            }
        }
        SheetText {
            capY: 10
            px: section.sh.statusSize
            text: section.status
            color: Theme.textDim
        }
    }

    // text action ("Scan"): ccControl so the keyboard reaches it
    SheetText {
        id: actionText
        anchors.right: parent.right
        anchors.rightMargin: section.sh.statusRight
        capY: section.sh.captionY
        px: section.sh.statusSize
        visible: section.status === "" && section.action !== ""
        text: section.action
        color: actionArea.containsMouse ? Theme.text : Theme.textSecondary
        font.weight: Font.Medium

        readonly property bool ccControl: visible
        readonly property real radius: 6
        function key(k: int): bool {
            if (k !== Qt.Key_Space && k !== Qt.Key_Return && k !== Qt.Key_Enter)
                return false;
            section.actionClicked();
            return true;
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.actionClicked()
        }
        FocusRing {}
    }

    SheetText {
        x: section.sh.hintX
        width: section.width - 2 * x
        capY: section.sh.captionGap + section.sh.hintY
        px: section.sh.hintSize
        visible: section.showHint
        text: section.hint
        color: section.sh.hintColor
    }

    Column {
        id: column
        x: section.sh.rowX
        y: section.sh.captionGap
        width: section.width - 2 * section.sh.rowX
        spacing: section.sh.rowGap
        visible: !section.showHint
    }
}
