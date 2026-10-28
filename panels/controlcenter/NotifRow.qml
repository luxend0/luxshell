import QtQuick
import qs.config
import qs.services
import qs.widgets

// One notification inside the control center card. Works on Quickshell
// Notification objects and on the plain fake objects (same field names).
Rectangle {
    id: row

    required property var modelData
    required property int index
    signal dismiss
    signal invoke

    readonly property string iconSource: {
        const n = modelData;
        const src = n.image || n.appIcon || "";
        if (src === "")
            return "";
        return /^(\/|file:|image:|qrc:)/.test(src) ? src : Apps.iconPath(src);
    }

    width: ListView.view ? ListView.view.width : 300
    height: Math.max(66, text.implicitHeight + 24)
    radius: 22
    color: hover.hovered ? Theme.mix(Theme.cc.hover, Theme.surfaceHigh, 0.4) : Theme.cc.hover
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    readonly property bool ccControl: true
    function key(k: int): bool {
        if (k === Qt.Key_Return || k === Qt.Key_Enter)
            invoke();
        else if (k === Qt.Key_Delete || k === Qt.Key_Backspace)
            dismiss();
        else
            return false;
        return true;
    }
    readonly property bool selected: Cc.isCurrent(row)
    onSelectedChanged: if (selected && ListView.view)
        ListView.view.positionViewAtIndex(ListView.view.indexAt(x + 1, y + 1), ListView.Contain)

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? row.dismiss() : row.invoke()
    }

    Item {
        id: iconBox
        x: 14
        y: 14
        width: 36
        height: 36
        Image {
            id: img
            anchors.fill: parent
            source: row.iconSource
            sourceSize.width: 72
            sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
        Disc {
            anchors.fill: parent
            visible: !img.visible
            icon: "bell"
            iconSize: 16
        }
    }

    Column {
        id: text
        x: 62
        y: 12
        width: row.width - x - 44
        spacing: 2
        Text {
            width: parent.width
            text: row.modelData.appName || "Notification"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.textDim
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: row.modelData.summary
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Theme.text
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.modelData.body ?? ""
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: Theme.textSecondary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Chip {
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 10
        width: 26
        icon: "x"
        iconSize: 13
        opacity: hover.hovered ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
        onClicked: row.dismiss()
    }

    FocusRing {
        gap: -3
    }
}
