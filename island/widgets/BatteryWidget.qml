import QtQuick
import Quickshell.Services.UPower
import qs.config

// Battery charge (UPower display device); the bar leaves it out on machines without one.
GlyphLabel {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? dev.percentage : 0 // 0..1
    readonly property bool charging: dev ? dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged : false

    icon: charging ? "battery-charging" : pct < 0.15 ? "battery-warning" : pct < 0.4 ? "battery-low" : pct < 0.75 ? "battery-medium" : "battery-full"
    text: Settings.islandBatteryPercent ? `${Math.round(pct * 100)}%` : ""
}
