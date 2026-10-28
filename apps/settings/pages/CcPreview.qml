import QtQuick
import qs.config
import qs.services
import qs.panels.controlcenter

// Custom row of the Control Center page: the real main page (panels/controlcenter/MainPage)
// scaled down on a piece of island, so every change to the tile and slider lists shows at
// once, items gliding to their new slots. Read only: the controls take no input here.
Item {
    id: root

    property var opt: null
    property var row: null
    readonly property real k: Theme.ccLayout.previewScale

    implicitHeight: island.height + 6

    // the display slider shows the real brightness, as the panel does when it opens
    Component.onCompleted: Brightness.refresh(false)

    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(Theme.cc.width * root.k)
        height: Math.round(CcLayout.height * root.k)
        color: Theme.island
        bottomLeftRadius: Theme.cc.radius * root.k
        bottomRightRadius: Theme.cc.radius * root.k
        border.width: 1
        border.color: Theme.settings.separator
        clip: true

        Item {
            width: Theme.cc.width
            height: CcLayout.height
            scale: root.k
            transformOrigin: Item.TopLeft

            MainPage {
                anchors.fill: parent
            }
        }

        // read only, but drawn enabled (disabled sliders hide their fill): this lid takes
        // every click, wheel and hover
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
            HoverHandler {
                blocking: true
            }
        }
    }
}
