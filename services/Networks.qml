pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config

// Network details for the control center (Net.qml stays the small bar view).
// NetworkManager via Quickshell.Networking, event driven. Every write goes
// through Exec (LUXSHELL_DRYRUN=1 only logs). LUXSHELL_FAKE_WIFI=1 adds a demo
// Wi-Fi adapter with a few networks (screenshots on the wired desktop).
Singleton {
    id: root

    readonly property bool fake: Env.get("LUXSHELL_FAKE_WIFI") === "1"
    readonly property var devices: Networking.devices?.values ?? []

    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wiredUp: wired.find(d => d.connected) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null

    readonly property bool wifiAvailable: fake || (!!wifiDevice && Networking.wifiHardwareEnabled)
    readonly property bool wifiEnabled: fake ? fakeWifiOn : Networking.wifiEnabled
    readonly property bool scanning: wifiEnabled && (fake || (wifiDevice?.scannerEnabled ?? false))

    // strongest entry per SSID; connected first, then known, then signal
    readonly property var wifiNetworks: {
        if (!wifiEnabled)
            return [];
        const list = fake ? fakeNetworks : (wifiDevice?.networks.values ?? []);
        const best = {};
        for (const n of list) {
            if (n.name === "")
                continue;
            const cur = best[n.name];
            if (!cur || n.connected || (!cur.connected && n.signalStrength > cur.signalStrength))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    readonly property var wifiConnected: wifiNetworks.find(n => n.connected) ?? null

    // NetworkManager profile name ("Wired connection 1"), else the interface
    function connectionName(net: var): string {
        if (!net)
            return "";
        const s = net.nmSettings ?? [];
        return s.length > 0 && s[0].id ? s[0].id : net.name;
    }

    // "1 Gb/s", "100 Mb/s", "" if unknown
    function speed(dev: var): string {
        const mbit = dev?.linkSpeed ?? 0;
        return mbit <= 0 ? "" : mbit >= 1000 ? `${+(mbit / 1000).toFixed(1)} Gb/s` : `${mbit} Mb/s`;
    }

    // "Connected · 1 Gb/s" (main tile + network sheet)
    function wiredStatus(dev: var): string {
        if (!dev)
            return "Disconnected";
        if (!dev.connected)
            return dev.hasLink === false ? "Cable unplugged" : "Disconnected";
        const s = speed(dev);
        return s !== "" ? `Connected · ${s}` : "Connected";
    }

    function strength(n: var): real {
        const s = n?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }
    // fan glyph of widgets/Glyphs, 1..3 arcs
    function strengthIcon(n: var): string {
        return `wifi-${Math.max(1, Math.min(3, Math.round(strength(n) * 3)))}`;
    }

    function secured(n: var): bool {
        return n.security !== undefined && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function setWifi(on: bool): void {
        if (fake) {
            fakeWifiOn = on;
            return;
        }
        if (!wifiDevice) {
            console.info("luxshell: no Wi-Fi hardware, nothing to toggle");
            return;
        }
        if (Exec.allow(`wifi enabled = ${on}`))
            Networking.wifiEnabled = on;
    }

    // the network sheet scans while it is open
    function setScanning(on: bool): void {
        if (fake || !wifiDevice || wifiDevice.scannerEnabled === on)
            return;
        if (Exec.allow(`wifi scanner = ${on}`))
            wifiDevice.scannerEnabled = on;
    }

    // true when the caller has to ask for a password first
    function needsPassword(n: var): bool {
        return !n.connected && !n.known && secured(n);
    }

    function activate(n: var): void {
        if (fake) {
            console.info(`luxshell[fake]: wifi ${n.connected ? "disconnect" : "connect"} ${n.name}`);
            return;
        }
        if (n.connected) {
            if (Exec.allow(`wifi disconnect ${n.name}`))
                n.disconnect();
        } else if (Exec.allow(`wifi connect ${n.name}`)) {
            n.connect();
        }
    }

    function connectWithPassword(n: var, psk: string): void {
        if (fake) {
            console.info(`luxshell[fake]: wifi connect ${n.name} with password`);
            return;
        }
        if (Exec.allow(`wifi connect ${n.name} (password)`))
            n.connectWithPsk(psk);
    }

    // wired: connected -> disconnect the device, else bring its profile up
    function toggleWired(dev: var): void {
        if (dev.connected) {
            if (Exec.allow(`disconnect ${dev.name}`))
                dev.disconnect();
        } else if (dev.network && Exec.allow(`connect ${dev.name}`)) {
            dev.network.connect();
        }
    }

    // ---- demo data (LUXSHELL_FAKE_WIFI=1) ----------------------------------
    property bool fakeWifiOn: true
    readonly property var fakeNetworks: [
        {
            "name": "Atlantis 5G",
            "signalStrength": 0.92,
            "connected": true,
            "known": true,
            "stateChanging": false,
            "security": WifiSecurityType.Wpa2Psk
        },
        {
            "name": "Atlantis",
            "signalStrength": 0.74,
            "connected": false,
            "known": true,
            "stateChanging": false,
            "security": WifiSecurityType.Wpa2Psk
        },
        {
            "name": "FRITZ!Box 7590 KL",
            "signalStrength": 0.48,
            "connected": false,
            "known": false,
            "stateChanging": false,
            "security": WifiSecurityType.Sae
        },
        {
            "name": "Cafe Lumen Guest",
            "signalStrength": 0.22,
            "connected": false,
            "known": false,
            "stateChanging": false,
            "security": WifiSecurityType.Open
        }
    ]
}
