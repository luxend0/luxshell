pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU load and memory in use for the island widgets, read from /proc every
// Settings.islandSysmonInterval seconds (at least 2), only while a widget uses it.
Singleton {
    id: root

    property int users: 0
    property real cpu: 0      // 0..1 since the previous sample
    property real ram: 0      // 0..1 (MemTotal - MemAvailable) / MemTotal
    property bool ready: false
    property var last: null

    function use(): void {
        users++;
        if (users === 1)
            sample();
    }
    function release(): void {
        users = Math.max(0, users - 1);
    }

    function sample(): void {
        stat.reload();
        mem.reload();
    }

    Timer {
        running: root.users > 0
        repeat: true
        interval: Math.max(2, Settings.islandSysmonInterval) * 1000
        onTriggered: root.sample()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const line = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = line[3] + (line[4] || 0);
            const total = line.reduce((a, b) => a + b, 0);
            if (root.last) {
                const dt = total - root.last.total;
                if (dt > 0)
                    root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / dt));
                root.ready = true;
            }
            root.last = {
                "idle": idle,
                "total": total
            };
        }
    }
    FileView {
        id: mem
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const t = text();
            const get = k => {
                const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m"));
                return m ? Number(m[1]) : 0;
            };
            const total = get("MemTotal");
            if (total > 0)
                root.ram = Math.max(0, Math.min(1, (total - get("MemAvailable")) / total));
        }
    }

    // ==== GPU, temperatures, network speed (gpu / temps / netspeed widgets) ==================
    // Same interval as cpu/ram, each part only while a widget uses it (useGpu() ...). Paths are
    // found once (discover()): the amdgpu card with the most VRAM (/sys/class/drm/card*/device
    // with gpu_busy_percent), hwmon by name (k10temp / zenpower / coretemp for the CPU, the
    // card's own amdgpu hwmon for the GPU). Then only FileViews, no processes.
    //   gpuBusy 0..1, vramUsed / vramTotal bytes, cpuTemp / gpuTemp °C (NaN = no sensor),
    //   rxRate / txRate bytes/s on netIface (Settings.islandNetSpeedIface, "" = default route)
    property int gpuUsers: 0
    property int tempUsers: 0
    property int netUsers: 0
    property bool discovered: false
    property string gpuDevice: ""      // /sys/class/drm/cardN/device ("" = no amdgpu card)
    property var cpuSensors: ({})      // label -> temp*_input path ("Tctl", "Tccd1", "Package id 0" ...)
    property var gpuSensors: ({})      // "edge" | "junction" | "mem" -> path
    property real gpuBusy: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property bool gpuReady: false
    property var cpuTemps: ({})        // path -> °C of the read cpu sensors
    property real gpuTemp: NaN
    readonly property real cpuTemp: {
        let best = NaN;
        for (const p of cpuTempPaths) {
            const v = cpuTemps[p];
            if (v !== undefined && !(best >= v))
                best = v;
        }
        return best;
    }
    // cpu sensor: "tctl" = Tctl / Tdie / Package (control temperature), "ccd" = hottest CCD
    readonly property var cpuTempPaths: {
        const s = cpuSensors;
        const keys = Object.keys(s);
        if (Settings.islandTempCpuSensor === "ccd") {
            const ccd = keys.filter(k => /^Tccd\d+$/.test(k));
            if (ccd.length > 0)
                return ccd.map(k => s[k]);
        }
        for (const k of ["Tctl", "Tdie", "Package id 0"])
            if (s[k])
                return [s[k]];
        return keys.length > 0 ? [s[keys[0]]] : [];
    }
    readonly property string gpuTempPath: gpuSensors[Settings.islandTempGpuSensor] ?? gpuSensors.edge ?? ""

    property real rxRate: 0
    property real txRate: 0
    property bool netReady: false
    property string netIface: ""
    property var netLast: null         // { iface, rx, tx, at }

    function useGpu(): void {
        gpuUsers++;
        startExtra();
    }
    function releaseGpu(): void {
        gpuUsers = Math.max(0, gpuUsers - 1);
    }
    function useTemps(): void {
        tempUsers++;
        startExtra();
    }
    function releaseTemps(): void {
        tempUsers = Math.max(0, tempUsers - 1);
    }
    function useNet(): void {
        netUsers++;
        startExtra();
    }
    function releaseNet(): void {
        netUsers = Math.max(0, netUsers - 1);
    }
    function startExtra(): void {
        if (!discovered) {
            if (!discover.running)
                discover.running = true;
            return;
        }
        sampleExtra();
    }

    function sampleExtra(): void {
        if (!discovered)
            return;
        if (gpuUsers > 0 && gpuDevice !== "") {
            gpuBusyFile.reload();
            vramUsedFile.reload();
        }
        if (tempUsers > 0) {
            for (let i = 0; i < cpuTempFiles.count; i++)
                cpuTempFiles.objectAt(i)?.reload();
            if (gpuTempPath !== "")
                gpuTempFile.reload();
        }
        if (netUsers > 0) {
            if (Settings.islandNetSpeedIface.trim() === "")
                routeFile.reload();
            netDevFile.reload();
        }
    }

    Timer {
        running: root.discovered && root.gpuUsers + root.tempUsers + root.netUsers > 0
        repeat: true
        interval: Math.max(2, Settings.islandSysmonInterval) * 1000
        onTriggered: root.sampleExtra()
    }

    // one shell run at the first use: "gpu|<device>|<vram total>", "temp|<hwmon name>|<device>|<label>|<input>"
    Process {
        id: discover
        command: ["sh", "-c", 'for d in /sys/class/drm/card[0-9]*/device; do [ -r "$d/gpu_busy_percent" ] || continue; ' + 'printf "gpu|%s|%s\n" "$(readlink -f "$d")" "$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)"; done; ' + 'for h in /sys/class/hwmon/hwmon*; do n=$(cat "$h/name" 2>/dev/null); case $n in k10temp|zenpower|coretemp|amdgpu) ;; *) continue ;; esac; ' + 'dev=$(readlink -f "$h/device" 2>/dev/null); for i in "$h"/temp*_input; do [ -r "$i" ] || continue; l=$(cat "${i%_input}_label" 2>/dev/null || basename "${i%_input}"); ' + 'printf "temp|%s|%s|%s|%s\n" "$n" "$dev" "$l" "$i"; done; done']
        stdout: StdioCollector {
            onStreamFinished: {
                let gpu = "", most = -1;
                const temps = [];
                for (const line of text.split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "gpu" && p.length >= 3 && Number(p[2]) > most) {
                        most = Number(p[2]);
                        gpu = p[1];
                    } else if (p[0] === "temp" && p.length >= 5) {
                        temps.push({
                            "name": p[1],
                            "dev": p[2],
                            "label": p[3],
                            "path": p.slice(4).join("|")
                        });
                    }
                }
                const cpu = {}, gs = {};
                const amd = temps.filter(t => t.name === "amdgpu");
                const own = amd.filter(t => t.dev === gpu);
                for (const t of (own.length > 0 ? own : amd))
                    if (gs[t.label] === undefined)
                        gs[t.label] = t.path;
                for (const t of temps.filter(t => t.name !== "amdgpu"))
                    if (cpu[t.label] === undefined)
                        cpu[t.label] = t.path;
                root.gpuDevice = gpu;
                root.vramTotal = Math.max(0, most);
                root.cpuSensors = cpu;
                root.gpuSensors = gs;
                root.discovered = true;
                root.sampleExtra();
            }
        }
    }

    FileView {
        id: gpuBusyFile
        path: root.gpuDevice !== "" ? root.gpuDevice + "/gpu_busy_percent" : ""
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v)) {
                root.gpuBusy = Math.max(0, Math.min(1, v / 100));
                root.gpuReady = true;
            }
        }
    }
    FileView {
        id: vramUsedFile
        path: root.gpuDevice !== "" ? root.gpuDevice + "/mem_info_vram_used" : ""
        printErrors: false
        onLoaded: {
            const v = Number(text().trim());
            if (!isNaN(v))
                root.vramUsed = v;
        }
    }
    Instantiator {
        id: cpuTempFiles
        model: root.cpuTempPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: {
                const v = parseInt(text());
                if (isNaN(v))
                    return;
                const n = Object.assign({}, root.cpuTemps);
                n[modelData] = v / 1000;
                root.cpuTemps = n;
            }
        }
    }
    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            root.gpuTemp = isNaN(v) ? NaN : v / 1000;
        }
    }
    onGpuTempPathChanged: {
        gpuTemp = NaN;
        if (tempUsers > 0 && gpuTempPath !== "")
            gpuTempFile.reload();
    }
    onCpuTempPathsChanged: if (tempUsers > 0)
        Qt.callLater(sampleExtra)

    // default route: the IPv4 route 0.0.0.0/0 with the lowest metric
    FileView {
        id: routeFile
        path: "/proc/net/route"
        printErrors: false
        onLoaded: {
            let best = "", metric = Infinity;
            for (const line of text().split("\n").slice(1)) {
                const f = line.trim().split(/\s+/);
                if (f.length >= 8 && f[1] === "00000000" && f[7] === "00000000" && Number(f[6]) < metric) {
                    metric = Number(f[6]);
                    best = f[0];
                }
            }
            root.defaultIface = best;
        }
    }
    property string defaultIface: ""
    FileView {
        id: netDevFile
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            const want = Settings.islandNetSpeedIface.trim() || root.defaultIface;
            const rows = {};
            let busiest = "", most = -1;
            for (const line of text().split("\n").slice(2)) {
                const i = line.indexOf(":");
                if (i < 0)
                    continue;
                const name = line.slice(0, i).trim();
                const f = line.slice(i + 1).trim().split(/\s+/).map(Number);
                rows[name] = {
                    "rx": f[0],
                    "tx": f[8]
                };
                if (name !== "lo" && f[0] + f[8] > most) {
                    most = f[0] + f[8];
                    busiest = name;
                }
            }
            const iface = rows[want] ? want : busiest; // no default route (IPv6 only, offline): the busiest link
            const r = rows[iface];
            const now = Date.now();
            const last = root.netLast;
            root.netIface = iface;
            if (!r) {
                root.netLast = null;
                return;
            }
            if (last && last.iface === iface && now > last.at && r.rx >= last.rx && r.tx >= last.tx) {
                const dt = (now - last.at) / 1000;
                root.rxRate = (r.rx - last.rx) / dt;
                root.txRate = (r.tx - last.tx) / dt;
                root.netReady = true;
            }
            root.netLast = {
                "iface": iface,
                "rx": r.rx,
                "tx": r.tx,
                "at": now
            };
        }
    }

    // "1.2 MB/s", "840 KB/s", "0 B/s" (bits: "9.6 Mb/s"); three significant digits at most
    function rate(bytes: real, bits: bool): string {
        let v = Math.max(0, bytes) * (bits ? 8 : 1);
        const units = bits ? ["b/s", "Kb/s", "Mb/s", "Gb/s"] : ["B/s", "KB/s", "MB/s", "GB/s"];
        let u = 0;
        while (v >= 999.5 && u < units.length - 1) {
            v /= 1000;
            u++;
        }
        const num = u === 0 || v >= 99.95 ? String(Math.round(v)) : v.toFixed(1);
        return `${num} ${units[u]}`;
    }
}
