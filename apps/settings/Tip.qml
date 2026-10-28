import QtQuick
import qs.config
import qs.widgets

// Small hover tip of the settings window (reset buttons: "Reset to default: 160 ms").
// show(item, text) after a short delay, above the item (below when there is no room).
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property Item target: null
    property string text: ""
    property bool shown: false

    function show(item: Item, t: string): void {
        target = item;
        text = t;
        delay.restart();
    }
    function hide(item: Item): void {
        if (item !== target)
            return;
        delay.stop();
        shown = false;
    }
    Timer {
        id: delay
        interval: 450
        onTriggered: {
            if (!root.target)
                return;
            const p = root.target.mapToItem(root, root.target.width / 2, 0);
            const w = bubble.width;
            bubble.x = Math.max(8, Math.min(root.width - w - 8, p.x - w / 2));
            const above = p.y - bubble.height - 8;
            bubble.y = above > 8 ? above : p.y + root.target.height + 8;
            root.shown = true;
        }
    }

    Rectangle {
        id: bubble
        width: Math.min(440, label.implicitWidth + 2 * root.g.tipPad)
        height: label.implicitHeight + 12
        radius: 9
        color: root.g.tip
        border.width: 1
        border.color: root.g.separator
        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            Anim {
                ms: 120
            }
        }
        SText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 440 - 2 * root.g.tipPad)
            elide: Text.ElideRight
            size: root.g.tipSize
            text: root.text
            color: root.g.label
        }
    }
}
