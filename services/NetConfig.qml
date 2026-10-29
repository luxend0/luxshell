pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// NetworkManager profiles and addresses for System > Network & Bluetooth. Quickshell.Networking
// (services/Net, Networks) has neither saved profiles nor IP / gateway / DNS, so nmcli is read
// on demand: when the page shows, every 15 s while it shows, after each change. Not a poller of
// its own. Every change goes through Exec.runDone (LUXSHELL_DRYRUN=1 only logs); polkit may ask
// for a password (luxshell's own agent answers that).
//
//   connections  [{ uuid, name, type, kind: ethernet|wifi|vpn|wireguard|other, device,
//                   autoconnect, active, activating, timestamp }]   (loopback left out)
//   devices      connected devices [{ device, type, hwaddr, connection, uuid, ip4: [], gw4,
//                   dns4: [], ip6: [], gw6, dns6: [] }]
//   details      { uuid: { method4, method6, dns4: [], dns6: [], ignoreAuto, iface, vpnType } }
//                (loadDetails(uuid), when a profile unfolds)
//   busy         { uuid: true } while a change runs
//
// LUXSHELL_FAKE_NM=1: demo profiles (wired, three Wi-Fi, WireGuard, OpenVPN) and two
// connected devices; changes are logged by Exec and then applied to the demo data only.
Singleton {
    id: root

    readonly property bool fake: Env.get("LUXSHELL_FAKE_NM") === "1"

    property var connections: []
    property var devices: []
    property var details: ({})
    property var busy: ({})
    property bool loaded: false
    signal failed(string text)

    readonly property var vpns: connections.filter(c => c.kind === "vpn" || c.kind === "wireguard")
    readonly property var saved: connections.filter(c => c.kind !== "vpn" && c.kind !== "wireguard")

    function kindOf(type: string): string {
        if (type === "802-3-ethernet" || type === "ethernet")
            return "ethernet";
        if (type === "802-11-wireless" || type === "wifi")
            return "wifi";
        if (type === "vpn" || type === "wireguard")
            return type;
        return "other";
    }
    function typeLabel(c: var): string {
        const d = details[c.uuid];
        switch (c.kind) {
        case "ethernet":
            return "Ethernet";
        case "wifi":
            return "Wi-Fi";
        case "wireguard":
            return "WireGuard";
        case "vpn":
            {
                const t = String(d?.vpnType ?? "").split(".").pop();
                return t ? (t === "openvpn" ? "OpenVPN" : t === "openconnect" ? "OpenConnect" : t === "vpnc" ? "Cisco VPN" : t.toUpperCase()) : "VPN";
            }
        }
        return String(c.type);
    }
    function deviceOf(c: var): var {
        return devices.find(d => d.uuid === c.uuid) ?? null;
    }
    function isBusy(uuid: string): bool {
        return busy[uuid] === true;
    }
    // "3 days ago", "" when never used
    function lastUsed(ts: real): string {
        if (!(ts > 0))
            return "";
        const s = Date.now() / 1000 - ts;
        if (s < 120)
            return "just now";
        if (s < 3600)
            return `${Math.round(s / 60)} min ago`;
        if (s < 86400)
            return `${Math.round(s / 3600)} h ago`;
        const d = Math.round(s / 86400);
        return d === 1 ? "yesterday" : d < 60 ? `${d} days ago` : `${Math.round(d / 30)} months ago`;
    }

    // ---- reading ---------------------------------------------------------------------------
    function refresh(): void {
        if (fake) {
            loaded = true;
            return;
        }
        if (!listProc.running)
            listProc.running = true;
        if (!devProc.running)
            devProc.running = true;
    }
    function loadDetails(uuid: string): void {
        if (fake || uuid === "")
            return;
        const p = detailProc.createObject(root, {
            "uuid": uuid
        });
        p.command = ["nmcli", "-t", "-f", "connection.interface-name,connection.autoconnect,ipv4.method,ipv4.dns,ipv4.ignore-auto-dns,ipv6.method,ipv6.dns,ipv6.ignore-auto-dns,vpn.service-type", "connection", "show", uuid];
        p.running = true;
    }

    // terse output: fields split at ":", "\:" and "\\" escaped
    function terse(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }
    // "FIELD:value" (multiline mode): split at the first colon only, values keep theirs
    function field(line: string): var {
        const i = line.indexOf(":");
        return i < 0 ? [line, ""] : [line.slice(0, i), line.slice(i + 1).replace(/\\:/g, ":")];
    }
    function list(v: string): var {
        return String(v ?? "").split(/[,\s]+/).map(x => x.trim()).filter(x => x !== "" && x !== "--");
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,AUTOCONNECT,ACTIVE,TIMESTAMP,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    const f = root.terse(line);
                    if (f.length < 8 || f[2] === "loopback")
                        continue;
                    out.push({
                        "name": f[0],
                        "uuid": f[1],
                        "type": f[2],
                        "kind": root.kindOf(f[2]),
                        "device": f[3] === "--" ? "" : f[3],
                        "autoconnect": f[4] === "yes",
                        "active": f[5] === "yes",
                        "activating": f[7] === "activating",
                        "timestamp": Number(f[6]) || 0
                    });
                }
                // active first, then the most recently used
                out.sort((a, b) => (b.active - a.active) || (b.timestamp - a.timestamp) || a.name.localeCompare(b.name));
                if (JSON.stringify(out) !== JSON.stringify(root.connections))
                    root.connections = out;
                root.loaded = true;
            }
        }
        onExited: root.loaded = true // nmcli missing or NetworkManager down: empty lists, no "Reading…"
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-m", "multiline", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.HWADDR,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS", "device", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = [];
                let d = null;
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    const [k, v] = root.field(line);
                    const key = k.replace(/\[\d+\]$/, "");
                    if (key === "GENERAL.DEVICE") {
                        d = {
                            "device": v,
                            "type": "",
                            "hwaddr": "",
                            "connection": "",
                            "uuid": "",
                            "state": 0,
                            "ip4": [],
                            "gw4": "",
                            "dns4": [],
                            "ip6": [],
                            "gw6": "",
                            "dns6": []
                        };
                        all.push(d);
                        continue;
                    }
                    if (!d || v === "" || v === "--")
                        continue;
                    switch (key) {
                    case "GENERAL.TYPE":
                        d.type = v;
                        break;
                    case "GENERAL.HWADDR":
                        d.hwaddr = v;
                        break;
                    case "GENERAL.CONNECTION":
                        d.connection = v;
                        break;
                    case "GENERAL.CON-UUID":
                        d.uuid = v;
                        break;
                    case "GENERAL.STATE":
                        d.state = parseInt(v) || 0;
                        break;
                    case "IP4.ADDRESS":
                        d.ip4.push(v);
                        break;
                    case "IP4.GATEWAY":
                        d.gw4 = v;
                        break;
                    case "IP4.DNS":
                        d.dns4.push(v);
                        break;
                    case "IP6.ADDRESS":
                        d.ip6.push(v);
                        break;
                    case "IP6.GATEWAY":
                        d.gw6 = v;
                        break;
                    case "IP6.DNS":
                        d.dns6.push(v);
                        break;
                    }
                }
                // connected (state 100) and real: no loopback, no bridges of containers without a profile
                const out = all.filter(x => x.state === 100 && x.type !== "loopback" && x.uuid !== "");
                if (JSON.stringify(out) !== JSON.stringify(root.devices))
                    root.devices = out;
            }
        }
    }

    Component {
        id: detailProc
        Process {
            id: dp
            property string uuid: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = {};
                    for (const line of text.split("\n")) {
                        if (line.trim() === "")
                            continue;
                        const [k, v] = root.field(line);
                        m[k] = v;
                    }
                    const d = {
                        "iface": m["connection.interface-name"] ?? "",
                        "method4": m["ipv4.method"] ?? "",
                        "method6": m["ipv6.method"] ?? "",
                        "dns4": root.list(m["ipv4.dns"]),
                        "dns6": root.list(m["ipv6.dns"]),
                        "ignoreAuto": m["ipv4.ignore-auto-dns"] === "yes",
                        "vpnType": m["vpn.service-type"] ?? ""
                    };
                    const all = Object.assign({}, root.details);
                    all[dp.uuid] = d;
                    root.details = all;
                }
            }
            onExited: destroy()
        }
    }

    // ---- changes (Exec) ------------------------------------------------------------------------
    function mark(uuid: string, on: bool): void {
        const b = Object.assign({}, busy);
        if (on)
            b[uuid] = true;
        else
            delete b[uuid];
        busy = b;
    }
    // one nmcli call; fake: apply(conn) on the demo data; then re-read
    function act(c: var, argv: var, what: string, apply: var): void {
        mark(c.uuid, true);
        Exec.runDone(argv, what, (ok, text) => {
            if (!ok)
                root.failed(text.split("\n")[0] || `${argv[0]} failed`);
            if (root.fake && ok && apply)
                root.fakeApply(c.uuid, apply);
            root.mark(c.uuid, false);
            root.refresh();
            root.loadDetails(c.uuid);
        });
    }

    function setAutoconnect(c: var, on: bool): void {
        act(c, ["nmcli", "connection", "modify", c.uuid, "connection.autoconnect", on ? "yes" : "no"], `${c.name}: auto-connect ${on ? "on" : "off"}`, x => x.autoconnect = on);
    }
    function forget(c: var): void {
        act(c, ["nmcli", "connection", "delete", c.uuid], `forget ${c.name}`, x => x.forgotten = true);
    }
    function up(c: var): void {
        act(c, ["nmcli", "connection", "up", c.uuid], `connect ${c.name}`, x => {
            x.active = true;
            x.timestamp = Math.round(Date.now() / 1000);
        });
    }
    function down(c: var): void {
        act(c, ["nmcli", "connection", "down", c.uuid], `disconnect ${c.name}`, x => x.active = false);
    }

    // DNS of a profile: [] = automatic (from DHCP / router advertisements), else the servers
    // (IPv4 and IPv6 mixed); a connected profile gets them at once (nmcli device reapply)
    function validIp(s: string): bool {
        const v4 = /^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$/;
        return v4.test(s) || (/^[0-9a-fA-F:]+$/.test(s) && s.includes(":") && s.split("::").length <= 2 && s.length >= 2);
    }
    function parseServers(t: string): var {
        return String(t).split(/[,\s]+/).map(x => x.trim()).filter(x => x !== "");
    }
    function setDns(c: var, servers: var): void {
        const v4 = servers.filter(s => !s.includes(":"));
        const v6 = servers.filter(s => s.includes(":"));
        const own = servers.length > 0;
        const argv = ["nmcli", "connection", "modify", c.uuid, "ipv4.ignore-auto-dns", own ? "yes" : "no", "ipv4.dns", v4.join(","), "ipv6.ignore-auto-dns", own ? "yes" : "no", "ipv6.dns", v6.join(",")];
        const dev = deviceOf(c);
        mark(c.uuid, true);
        Exec.runDone(argv, `${c.name}: DNS ${own ? servers.join(", ") : "automatic"}`, (ok, text) => {
            if (!ok) {
                root.failed(text.split("\n")[0] || "nmcli failed");
            } else if (root.fake) {
                root.fakeDns(c.uuid, servers);
            } else if (dev) {
                Exec.runDone(["nmcli", "device", "reapply", dev.device], `${dev.device}: apply the new DNS`, (ok2, t2) => {
                    if (!ok2)
                        root.failed(t2.split("\n")[0] || "nmcli device reapply failed");
                    root.refresh();
                });
            }
            root.mark(c.uuid, false);
            root.refresh();
            root.loadDetails(c.uuid);
        });
    }

    // ---- demo data (LUXSHELL_FAKE_NM=1) --------------------------------------------------------
    function fakeApply(uuid: string, fn: var): void {
        const list = connections.map(x => Object.assign({}, x));
        const c = list.find(x => x.uuid === uuid);
        if (!c)
            return;
        fn(c);
        connections = list.filter(x => !x.forgotten);
        if (c.forgotten || !c.active)
            devices = devices.filter(d => d.uuid !== uuid);
        if (c.active && !devices.some(d => d.uuid === uuid) && (c.kind === "vpn" || c.kind === "wireguard"))
            devices = devices.concat([{
                    "device": c.kind === "wireguard" ? "wg0" : "tun0",
                    "type": c.kind === "wireguard" ? "wireguard" : "tun",
                    "hwaddr": "",
                    "connection": c.name,
                    "uuid": c.uuid,
                    "state": 100,
                    "ip4": ["10.66.0.7/32"],
                    "gw4": "",
                    "dns4": ["10.66.0.1"],
                    "ip6": [],
                    "gw6": "",
                    "dns6": []
                }]);
    }
    function fakeDns(uuid: string, servers: var): void {
        const all = Object.assign({}, details);
        all[uuid] = Object.assign({}, all[uuid] ?? {}, {
            "dns4": servers.filter(s => !s.includes(":")),
            "dns6": servers.filter(s => s.includes(":")),
            "ignoreAuto": servers.length > 0
        });
        details = all;
        devices = devices.map(d => d.uuid !== uuid ? d : Object.assign({}, d, {
                "dns4": servers.length > 0 ? servers.filter(s => !s.includes(":")) : ["192.168.178.1"],
                "dns6": servers.length > 0 ? servers.filter(s => s.includes(":")) : []
            }));
    }

    Component.onCompleted: {
        if (!fake)
            return;
        const now = Math.round(Date.now() / 1000);
        connections = [
            {
                "name": "Wired connection 1",
                "uuid": "7c1f3a52-0b8e-3d4f-9a61-2e5d8c0b1f01",
                "type": "802-3-ethernet",
                "kind": "ethernet",
                "device": "enp42s0",
                "autoconnect": true,
                "active": true,
                "activating": false,
                "timestamp": now - 40
            },
            {
                "name": "Atlantis 5G",
                "uuid": "a2b9c1d4-5e6f-4a7b-8c9d-0e1f2a3b4c02",
                "type": "802-11-wireless",
                "kind": "wifi",
                "device": "wlan0",
                "autoconnect": true,
                "active": true,
                "activating": false,
                "timestamp": now - 300
            },
            {
                "name": "Atlantis",
                "uuid": "b3c0d2e5-6f70-4b8c-9d0e-1f2a3b4c5d03",
                "type": "802-11-wireless",
                "kind": "wifi",
                "device": "",
                "autoconnect": true,
                "active": false,
                "activating": false,
                "timestamp": now - 3 * 86400
            },
            {
                "name": "Cafe Lumen Guest",
                "uuid": "c4d1e3f6-7081-4c9d-0e1f-2a3b4c5d6e04",
                "type": "802-11-wireless",
                "kind": "wifi",
                "device": "",
                "autoconnect": false,
                "active": false,
                "activating": false,
                "timestamp": now - 23 * 86400
            },
            {
                "name": "Home WireGuard",
                "uuid": "d5e2f407-8192-4dae-1f2a-3b4c5d6e7f05",
                "type": "wireguard",
                "kind": "wireguard",
                "device": "",
                "autoconnect": false,
                "active": false,
                "activating": false,
                "timestamp": now - 86400
            },
            {
                "name": "Office VPN",
                "uuid": "e6f30518-92a3-4ebf-2a3b-4c5d6e7f8006",
                "type": "vpn",
                "kind": "vpn",
                "device": "",
                "autoconnect": false,
                "active": false,
                "activating": false,
                "timestamp": now - 12 * 86400
            }
        ];
        devices = [
            {
                "device": "enp42s0",
                "type": "ethernet",
                "hwaddr": "D8:43:AE:00:5C:21",
                "connection": "Wired connection 1",
                "uuid": "7c1f3a52-0b8e-3d4f-9a61-2e5d8c0b1f01",
                "state": 100,
                "ip4": ["192.168.178.42/24"],
                "gw4": "192.168.178.1",
                "dns4": ["192.168.178.1"],
                "ip6": ["2001:db8:770d:1300::42/64", "fe80::da43:aeff:fe00:5c21/64"],
                "gw6": "fe80::1",
                "dns6": []
            },
            {
                "device": "wlan0",
                "type": "wifi",
                "hwaddr": "3C:A9:F4:12:7E:90",
                "connection": "Atlantis 5G",
                "uuid": "a2b9c1d4-5e6f-4a7b-8c9d-0e1f2a3b4c02",
                "state": 100,
                "ip4": ["192.168.178.57/24"],
                "gw4": "192.168.178.1",
                "dns4": ["1.1.1.1", "9.9.9.9"],
                "ip6": [],
                "gw6": "",
                "dns6": []
            }
        ];
        const d = {};
        for (const c of connections)
            d[c.uuid] = {
                "iface": c.device,
                "method4": "auto",
                "method6": c.kind === "wireguard" ? "ignore" : "auto",
                "dns4": [],
                "dns6": [],
                "ignoreAuto": false,
                "vpnType": c.kind === "vpn" ? "org.freedesktop.NetworkManager.openvpn" : ""
            };
        d["a2b9c1d4-5e6f-4a7b-8c9d-0e1f2a3b4c02"].dns4 = ["1.1.1.1", "9.9.9.9"];
        d["a2b9c1d4-5e6f-4a7b-8c9d-0e1f2a3b4c02"].ignoreAuto = true;
        details = d;
        loaded = true;
    }
}
