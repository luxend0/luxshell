import QtQuick
import qs.config

// Colour twin of widgets/Anim: Theme curve, fadeIn unless `ms` is set
// (set `ms`, not `duration`, so LUXSHELL_SLOWMO applies).
ColorAnimation {
    property int ms: Theme.fadeIn
    duration: Motion.ms(ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
