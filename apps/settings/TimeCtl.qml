import QtQuick
import qs.config
import qs.widgets

// "HH:MM" (24 h) field: type over it (Enter applies), wheel or Left/Right (row) step
// by `step` minutes, wrapping at midnight.
FieldCtl {
    id: root

    property string value: "00:00"
    property int step: 15
    signal changed(string v)

    implicitWidth: g.timeWidth
    text: value
    inputMask: "99:99"
    horizontalAlignment: TextInput.AlignHCenter
    valid: t => /^([01]?\d|2[0-3]):[0-5]\d$/.test(t.replace(/\s/g, ""))

    function minutes(t: string): int {
        const m = /^(\d{1,2}):(\d{2})$/.exec(t.replace(/\s/g, ""));
        return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : 0;
    }
    function format(min: int): string {
        const m = ((min % 1440) + 1440) % 1440;
        return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
    }
    function shift(d: int): void {
        const m = minutes(value);
        // snap to the step grid first (07:10 + 15 -> 07:15)
        const n = d > 0 ? Math.floor(m / step) * step + step : Math.ceil(m / step) * step - step;
        changed(format(n));
    }

    onApplied: t => changed(format(minutes(t)))

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.shift(event.angleDelta.y > 0 ? 1 : -1)
    }
}
