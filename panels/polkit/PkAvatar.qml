import QtQuick
import QtQuick.Effects
import qs.config

// Avatar disc of the polkit prompt, the lock screen's disc (lock/Avatar.qml: translucent fill,
// fine lighter ring): the user's picture when one is readable (~/.face, AccountsService),
// otherwise the initial of the name.
Item {
    id: root

    property real size: 76
    property string name: ""
    property string picture: ""     // file path, "" = initial
    readonly property QtObject g: Theme.lock
    readonly property bool hasPicture: picture !== "" && photo.status === Image.Ready

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, root.g.avatarFill)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, root.g.avatarRing)
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.size * 0.02
        visible: !root.hasPicture
        text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
        color: root.g.fg(0.95)
        font.family: root.g.family
        font.pixelSize: Math.max(8, root.size * Theme.polkit.initialScale)
        font.weight: Font.DemiBold
    }

    Image {
        id: photo
        anchors.fill: parent
        visible: false
        source: root.picture !== "" ? "file://" + root.picture : ""
        sourceSize.width: 160
        sourceSize.height: 160
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.hasPicture
        source: photo
        maskEnabled: true
        maskSource: mask
    }
}
