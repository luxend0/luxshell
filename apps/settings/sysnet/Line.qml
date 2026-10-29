import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// One line of a list inside a settings card (System > Sound, Network & Bluetooth): icon disc,
// name over a grey sub line, actions right (children), separator above every line but the
// first, keyboard ring, hover. `details` (a Component) unfolds below the line while `expanded`.
// clicked(): the line itself (not its buttons). A bare custom row stacks these in a Column.
Item {
    id: line

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property string glyph: ""
    property url iconSource: ""      // app icon instead of the glyph
    property bool on: false          // disc lit (in use, connected)
    property string title: ""
    property string sub: ""
    property color subColor: g.value
    property bool ring: false        // keyboard cursor
    property bool first: false       // no separator above
    property bool roundTop: false    // hover corners: first line of the card
    property bool roundBottom: false // last line of the card
    property bool clickable: true
    property bool busy: false
    property bool expanded: false
    property Component details: null
    property real inset: g.rowInset
    default property alias actions: trail.data
    signal clicked

    width: parent ? parent.width : 0
    height: s.line + (expanded && loader.item ? loader.item.implicitHeight : 0)
    Behavior on height {
        Anim {
            ms: 180
        }
    }
    clip: true

    Rectangle {
        width: parent.width
        height: line.s.line
        color: line.g.hover
        opacity: line.clickable && area.containsMouse ? 1 : 0
        topLeftRadius: line.roundTop ? line.g.cardRadius : 0
        topRightRadius: line.roundTop ? line.g.cardRadius : 0
        bottomLeftRadius: line.roundBottom && !line.expanded ? line.g.cardRadius : 0
        bottomRightRadius: line.roundBottom && !line.expanded ? line.g.cardRadius : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }
    Rectangle {
        visible: !line.first
        x: line.inset
        width: parent.width - 2 * line.inset
        height: 1
        color: line.g.separator
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 13
        color: "transparent"
        border.width: 2
        border.color: line.g.ring
        visible: line.ring
    }

    MouseArea {
        id: area
        width: parent.width
        height: line.s.line
        hoverEnabled: true
        enabled: line.clickable
        cursorShape: line.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: line.clicked()
    }

    Rectangle {
        id: disc
        x: line.inset
        y: (line.s.line - height) / 2
        width: line.s.disc
        height: width
        radius: width / 2
        color: line.on ? line.s.discOn : line.g.disc
        Behavior on color {
            ColorAnim {}
        }
        MdIcon {
            visible: line.iconSource.toString() === ""
            anchors.centerIn: parent
            glyph: line.glyph
            size: line.s.discIcon
            color: line.on ? line.g.label : line.g.icon
            opacity: line.busy ? 0.4 : 1
        }
        Image {
            visible: line.iconSource.toString() !== ""
            anchors.centerIn: parent
            width: line.s.appIcon
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: line.iconSource
            asynchronous: true
        }
        // busy: a ring that turns
        Rectangle {
            visible: line.busy
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: line.g.value
            opacity: 0.35
        }
        Rectangle {
            visible: line.busy
            width: 6
            height: 6
            radius: 3
            color: line.g.label
            x: parent.width / 2 - 3 + (parent.width / 2 - 1) * Math.cos(spin.a)
            y: parent.height / 2 - 3 + (parent.height / 2 - 1) * Math.sin(spin.a)
        }
        NumberAnimation {
            id: spin
            property real a: 0
            target: spin
            property: "a"
            from: 0
            to: 2 * Math.PI
            duration: 900
            loops: Animation.Infinite
            running: line.busy
        }
    }

    Column {
        x: disc.x + disc.width + line.s.textGap
        y: (line.s.line - height) / 2
        width: trail.x - x - 14
        spacing: line.s.subGap
        SText {
            width: parent.width
            elide: Text.ElideRight
            text: line.title
        }
        SText {
            visible: line.sub !== ""
            width: parent.width
            elide: Text.ElideRight
            size: line.s.subSize
            font.weight: Font.Normal
            text: line.sub
            color: line.subColor
        }
    }

    Row {
        id: trail
        x: line.width - line.inset - width
        y: (line.s.line - height) / 2
        height: line.g.miniButton
        spacing: line.s.buttonGap
        layoutDirection: Qt.LeftToRight
    }

    Loader {
        id: loader
        y: line.s.line
        x: disc.x + disc.width + line.s.textGap
        width: line.width - x - line.inset
        active: line.expanded && line.details !== null
        sourceComponent: line.details
    }
}
