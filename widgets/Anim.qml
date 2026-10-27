import QtQuick
import qs.config

// Secondary animation of the shell: Theme curve, Theme duration unless `ms` is set.
// Set `ms`, not `duration`, so LUXSHELL_SLOWMO applies. The island morph itself
// has its own per-axis timing (config/Motion.qml, island/Island.qml).
NumberAnimation {
    property int ms: Theme.duration
    duration: Motion.ms(ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
