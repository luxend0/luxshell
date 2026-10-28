import QtQuick
import qs.config

// Horizontal carousel of the theme and wallpaper picker.
//
// `pos` follows `current` with one soft ease-out (Theme.picker.settle/curve), always from
// where it is, so fast key presses, wheel notches and drags blend into one motion.
// Every card gets its signed distance d = index - pos and derives position, scale,
// dimming, lift and frame from it: nothing snaps, the whole strip interpolates.
// Cards further than `reach` steps from pos are not instantiated (thumbnails load
// lazily, large folders stay cheap).
//
// The delegate root needs `property int index` and `property real d`.
// Input: click a side card = picked(i), click the centred card = activated(i),
// wheel = moved(+-1) per notch, horizontal drag scrubs and settles on the nearest card.
Item {
    id: root

    property int count: 0
    property int current: 0
    property real step: 260
    property real reach: 3.6
    property Component delegate: null

    property real pos: current
    property bool dragging: false
    property bool instant: false    // filter changes: jump, no travel through the list

    signal picked(int index)
    signal activated(int index)
    signal moved(int delta)

    clip: true

    // jump to `current` without the ease (new filter result, first frame)
    function jump(): void {
        instant = true;
        pos = Qt.binding(() => root.current);
        instant = false;
    }

    Behavior on pos {
        enabled: !root.dragging && !root.instant
        NumberAnimation {
            duration: Motion.ms(Theme.picker.settle)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.picker.curve
        }
    }

    Repeater {
        model: root.count

        Item {
            id: slot

            required property int index
            readonly property real d: index - root.pos

            x: root.width / 2 + d * root.step - width / 2
            width: root.step
            height: root.height
            visible: Math.abs(d) < root.reach
            z: -Math.abs(d)

            Loader {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                active: slot.visible
                sourceComponent: root.delegate
                onLoaded: {
                    item.index = slot.index;
                    item.d = Qt.binding(() => slot.d);
                }
            }

            TapHandler {
                onTapped: Math.round(slot.d) === 0 ? root.activated(slot.index) : root.picked(slot.index)
            }
        }
    }

    // one card per notch; touchpads send small steps, they accumulate
    WheelHandler {
        property real acc: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : event.angleDelta.y;
            acc += delta;
            const steps = Math.trunc(acc / Theme.picker.wheelStep);
            if (steps === 0)
                return;
            acc -= steps * Theme.picker.wheelStep;
            root.moved(-steps);
        }
    }

    DragHandler {
        property real from: 0
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (active) {
                from = root.pos;
                root.dragging = true;
                return;
            }
            const i = Math.max(0, Math.min(root.count - 1, Math.round(root.pos)));
            root.dragging = false;
            root.picked(i);
            root.pos = Qt.binding(() => root.current); // eases from the drop point
        }
        onTranslationChanged: if (active)
            root.pos = Math.max(-0.4, Math.min(root.count - 0.6, from - translation.x / root.step))
    }
}
