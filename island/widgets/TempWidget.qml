import QtQuick
import qs.config
import qs.services

// CPU and / or GPU temperature (services/Sysmon: hwmon k10temp / zenpower / coretemp and the
// card's amdgpu sensor). Settings.islandTempShow: cpu | gpu | both; the sensors:
// islandTempCpuSensor (tctl | ccd = hottest CCD), islandTempGpuSensor (edge | junction | mem).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject wm: Theme.widgets
    readonly property string show: Settings.islandTempShow
    readonly property bool both: show === "both"
    readonly property real gapC: wm.gaps.status[0]
    readonly property real gapH: wm.gaps.status[1]
    readonly property real wC: (show !== "gpu" ? cpu.wC : 0) + (show !== "cpu" ? gpu.wC : 0) + (both ? gapC : 0)
    readonly property real wH: (show !== "gpu" ? cpu.wH : 0) + (show !== "cpu" ? gpu.wH : 0) + (both ? gapH : 0)

    function deg(v: real): string {
        return isNaN(v) ? "–°" : `${Math.round(v)}°`;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: root.gapC + (root.gapH - root.gapC) * root.t

        InfoLabel {
            id: cpu
            visible: root.show !== "gpu"
            icon: root.both ? "cpu" : "thermometer"
            text: root.deg(Sysmon.cpuTemp)
            sample: "100°"
            t: root.t
            textOpacity: root.textOpacity
        }
        InfoLabel {
            id: gpu
            visible: root.show !== "cpu"
            icon: root.both ? "gpu" : "thermometer"
            text: root.deg(Sysmon.gpuTemp)
            sample: "100°"
            t: root.t
            textOpacity: root.textOpacity
        }
    }

    Component.onCompleted: Sysmon.useTemps()
    Component.onDestruction: Sysmon.releaseTemps()
}
