pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// What a monitor can do, read from its EDID (/sys/class/drm/card*-<output>/edid, read only).
// `hyprctl monitors all -j` has the active format and colour preset, but not whether the panel
// takes 10 bit or HDR, so Settings > Displays asks this before it offers them:
//   caps["DP-3"] = { bpc: 10, hdr: true, hlg: false, wide: true, maxNits: 418,
//                    vrr: true, vrrMin: 48, vrrMax: 180, name: "CQ32G4" }
//   bpc      colour depth the panel declares (EDID 1.4 video input byte; 0 = not declared)
//   hdr/hlg  CTA-861 HDR static metadata block lists SMPTE ST 2084 (PQ) / HLG
//   wide     colorimetry block lists BT.2020
//   vrr      adaptive sync announced (AMD FreeSync VSDB, HDMI Forum VRR); vrrMin/Max from the
//            range limits descriptor
// Virtual outputs (headless, nested) have no EDID: of() gives null. Read at start and on hotplug.
Singleton {
    id: root

    property var caps: ({})

    function of(output: string): var {
        return caps[output] ?? null;
    }
    function refresh(): void {
        if (!reader.running)
            reader.running = true;
    }

    // "card1-DP-3" -> "DP-3 <hex>" per connector with an EDID (sysfs reports size 0, so read it)
    Process {
        id: reader
        running: true
        command: ["sh", "-c", 'for f in /sys/class/drm/card*-*/edid; do [ -r "$f" ] || continue; d=${f%/edid}; n=${d##*/}; n=${n#card*-}; h=$(od -An -v -tx1 "$f" 2>/dev/null | tr -d " \\n"); [ -n "$h" ] && echo "$n $h"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const [name, hex] = line.trim().split(" ");
                    if (!name || !hex)
                        continue;
                    const c = root.parse(hex);
                    if (c)
                        out[name] = c;
                }
                if (JSON.stringify(out) !== JSON.stringify(root.caps))
                    root.caps = out;
            }
        }
    }

    function parse(hex: string): var {
        const b = [];
        for (let i = 0; i + 1 < hex.length; i += 2)
            b.push(parseInt(hex.substr(i, 2), 16));
        if (b.length < 128 || b[0] !== 0 || b[1] !== 0xff)
            return null;
        const c = {
            "bpc": 0,
            "hdr": false,
            "hlg": false,
            "wide": false,
            "maxNits": 0,
            "vrr": false,
            "vrrMin": 0,
            "vrrMax": 0,
            "name": ""
        };
        // video input definition: digital (bit 7), bits 6..4 = colour depth
        if (b[20] & 0x80)
            c.bpc = [0, 6, 8, 10, 12, 14, 16, 0][(b[20] >> 4) & 7];
        // display descriptors: range limits (0xFD), product name (0xFC)
        for (let i = 0; i < 4; i++) {
            const o = 54 + 18 * i;
            if (b[o] !== 0 || b[o + 1] !== 0)
                continue;
            if (b[o + 3] === 0xfd) {
                const fl = b[o + 4];
                c.vrrMin = b[o + 5] + ((fl & 1) ? 255 : 0);
                c.vrrMax = b[o + 6] + ((fl & 2) ? 255 : 0);
            } else if (b[o + 3] === 0xfc) {
                c.name = String.fromCharCode(...b.slice(o + 5, o + 18)).split("\n")[0].trim();
            }
        }
        // CTA-861 extensions: data blocks
        for (let e = 1; e <= b[126] && 128 * (e + 1) <= b.length; e++) {
            const x = b.slice(128 * e, 128 * (e + 1));
            if (x[0] !== 0x02)
                continue;
            const end = Math.min(x[2], 127);
            let i = 4;
            while (i < end) {
                const tag = x[i] >> 5, len = x[i] & 31;
                if (tag === 7 && len >= 2) {
                    const ext = x[i + 1];
                    if (ext === 6) { // HDR static metadata
                        c.hdr = (x[i + 2] & 4) !== 0;
                        c.hlg = (x[i + 2] & 8) !== 0;
                        if (len >= 4 && x[i + 4] > 0)
                            c.maxNits = Math.round(50 * Math.pow(2, x[i + 4] / 32));
                    } else if (ext === 5) { // colorimetry
                        c.wide = (x[i + 2] & 0xe0) !== 0;
                    }
                } else if (tag === 3 && len >= 3) { // vendor specific: OUI little endian
                    const oui = x[i + 1] | (x[i + 2] << 8) | (x[i + 3] << 16);
                    if (oui === 0x00001a) // AMD FreeSync
                        c.vrr = true;
                    else if (oui === 0xc45dd8 && len >= 9 && (x[i + 9] & 0x3f) > 0) // HDMI Forum, VRRmin
                        c.vrr = true;
                }
                i += 1 + len;
            }
        }
        return c;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name.startsWith("monitoradded") || event.name.startsWith("monitorremoved"))
                hotplug.restart();
        }
    }
    Timer {
        id: hotplug
        interval: 1500 // the kernel needs a moment for the new EDID
        onTriggered: root.refresh()
    }
}
