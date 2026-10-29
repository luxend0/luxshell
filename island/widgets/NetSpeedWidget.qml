import QtQuick
import qs.config
import qs.services

// Live download / upload rate of the default-route interface (services/Sysmon: /proc/net/dev,
// same interval as cpu/ram), unit chosen automatically (B/s .. GB/s, or bits).
// Settings.islandNetSpeedShow: both | down | up; islandNetSpeedBits; islandNetSpeedIface
// ("" = default route).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject wm: Theme.widgets
    readonly property string show: Settings.islandNetSpeedShow
    readonly property bool bits: Settings.islandNetSpeedBits
    readonly property bool both: show === "both"
    readonly property string sample: bits ? "88.8 Mb/s" : "88.8 MB/s" // widest text Sysmon.rate() gives
    readonly property real gapC: wm.gaps.status[0]
    readonly property real gapH: wm.gaps.status[1]
    readonly property real wC: (show !== "up" ? down.wC : 0) + (show !== "down" ? up.wC : 0) + (both ? gapC : 0)
    readonly property real wH: (show !== "up" ? down.wH : 0) + (show !== "down" ? up.wH : 0) + (both ? gapH : 0)

    function fmt(v: real): string {
        return Sysmon.netReady ? Sysmon.rate(v, root.bits) : (root.bits ? "– b/s" : "– B/s");
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: root.gapC + (root.gapH - root.gapC) * root.t

        InfoLabel {
            id: down
            visible: root.show !== "up"
            icon: "arrow-down"
            iconScale: Theme.barInfo.arrowScale
            text: root.fmt(Sysmon.rxRate)
            sample: root.sample
            t: root.t
            textOpacity: root.textOpacity
        }
        InfoLabel {
            id: up
            visible: root.show !== "down"
            icon: "arrow-up"
            iconScale: Theme.barInfo.arrowScale
            text: root.fmt(Sysmon.txRate)
            sample: root.sample
            t: root.t
            textOpacity: root.textOpacity
        }
    }

    Component.onCompleted: Sysmon.useNet()
    Component.onDestruction: Sysmon.releaseNet()
}
