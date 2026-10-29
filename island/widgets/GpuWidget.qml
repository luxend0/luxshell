import QtQuick
import qs.config
import qs.services

// GPU load and / or VRAM in use (services/Sysmon: amdgpu sysfs, same interval as cpu/ram).
// Settings.islandGpuShow: load | vram | both; islandGpuVram: gb (used, GiB) | pct.
InfoLabel {
    readonly property string show: Settings.islandGpuShow
    readonly property bool pct: Settings.islandGpuVram === "pct"
    readonly property bool none: Sysmon.discovered && Sysmon.gpuDevice === ""
    readonly property string loadText: Sysmon.gpuReady ? `${Math.round(Sysmon.gpuBusy * 100)}%` : "–%"
    readonly property string vramText: {
        if (!Sysmon.gpuReady || Sysmon.vramTotal <= 0)
            return pct ? "–%" : "–G";
        if (pct)
            return `${Math.round(Sysmon.vramUsed / Sysmon.vramTotal * 100)}%`;
        const g = Sysmon.vramUsed / 1073741824;
        return `${g >= 9.95 ? Math.round(g) : g.toFixed(1)}G`;
    }
    readonly property string vramSample: pct ? "100%" : "88.8G"

    icon: "gpu"
    text: none ? "–" : show === "vram" ? vramText : show === "both" ? `${loadText} · ${vramText}` : loadText
    sample: show === "vram" ? vramSample : show === "both" ? `100% · ${vramSample}` : "100%"

    Component.onCompleted: Sysmon.useGpu()
    Component.onDestruction: Sysmon.releaseGpu()
}
