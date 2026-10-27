import QtQuick
import qs.config

// The one animation of the shell: Theme curve, Theme duration unless overridden.
NumberAnimation {
    duration: Theme.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
