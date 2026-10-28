pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config

// Bluetooth (BlueZ via Quickshell.Bluetooth): default adapter, saved and nearby
// devices. Reads are passive; the functions below are the only writers and go
// through Exec (dry run). LUXSHELL_FAKE_BT=1 swaps in the device set of the video
// (two saved headphones, a TV that turns up shortly after scanning starts);
// LUXSHELL_FAKE_BT=scanning never finds it. Fake devices react locally.
Singleton {
    id: root

    readonly property bool fake: Env.get("LUXSHELL_FAKE_BT") !== ""
    readonly property bool fakeFinds: fake && Env.get("LUXSHELL_FAKE_BT") !== "scanning"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: fake || !!adapter
    readonly property bool enabled: fake ? fakeAdapter.enabled : (adapter?.enabled ?? false)
    readonly property bool discovering: fake ? fakeAdapter.discovering : (adapter?.discovering ?? false)
    readonly property string adapterName: fake ? "luxos" : (adapter?.name ?? "")
    readonly property bool busy: !fake && !!adapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)

    readonly property var devices: fake ? [...fakeDevices].filter(d => d.paired || d.found) : (adapter?.devices?.values ?? [])
    readonly property var saved: devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !(d.paired || d.bonded) && named(d)).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var connectedDevices: saved.filter(d => d.connected)

    readonly property string status: !available ? "Unavailable" : !enabled ? "Off" : connectedDevices.length === 1 ? connectedDevices[0].name : connectedDevices.length > 1 ? `${connectedDevices.length} devices` : "On"

    // unnamed devices show their address as name ("AA-BB-..."), not worth listing
    function named(d): bool {
        return d.name !== "" && d.name.replace(/-/g, ":").toUpperCase() !== String(d.address).toUpperCase();
    }

    function stateOf(d): int {
        return d.state ?? (d.connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected);
    }
    function busyOf(d): bool {
        const s = stateOf(d);
        return d.pairing || s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting;
    }

    // Lucide-ish glyph for a BlueZ icon name
    function glyphFor(d): string {
        const i = String(d?.icon ?? "");
        if (i.startsWith("audio-head"))
            return "headphones";
        if (i === "audio-card" || i.startsWith("video"))
            return "volume-2"; // TVs and soundbars (ref/09c: speaker with waves)
        if (i.startsWith("audio") || i.includes("speaker"))
            return "speaker";
        if (i === "input-mouse")
            return "mouse";
        if (i === "input-keyboard")
            return "keyboard";
        if (i === "input-gaming")
            return "gamepad";
        if (i.startsWith("phone"))
            return "smartphone";
        if (i === "computer")
            return "laptop";
        return "bluetooth";
    }

    function batteryText(d): string {
        return d.batteryAvailable ? ` · ${Math.round(d.battery * 100)} %` : "";
    }

    function setEnabled(on: bool): void {
        if (fake) {
            fakeAdapter.enabled = on;
            if (!on)
                fakeAdapter.discovering = false;
        }
        else if (adapter && Exec.allow(`bluetooth adapter enabled = ${on}`))
            adapter.enabled = on;
    }
    function toggle(): void {
        setEnabled(!enabled);
    }

    property bool ownScan: false // only stop discovery the shell started itself
    function scan(on: bool): void {
        if (on === discovering)
            return;
        ownScan = on;
        if (fake) {
            fakeAdapter.discovering = on && fakeAdapter.enabled;
            if (fakeAdapter.discovering && fakeFinds)
                fakeFind.restart();
        } else if (adapter && enabled && Exec.allow(`bluetooth discovering = ${on}`)) {
            adapter.discovering = on;
        }
    }
    // the Bluetooth sheet scans while it is open (ref/09: "Scanning" right away)
    function autoScan(): void {
        if (enabled && !discovering)
            scan(true);
    }

    // Unpaired devices pair first; BlueZ connects them once pairing succeeds.
    function connect(d): void {
        if (!d || busyOf(d))
            return;
        if (fake) {
            fakeOp.start(d, true);
            return;
        }
        if (!Exec.allow(`bluetooth connect ${d.name} (${d.address})`))
            return;
        if (d.paired || d.bonded) {
            d.connect();
        } else {
            d.trusted = true;
            d.pair();
        }
    }
    function disconnect(d): void {
        if (!d || busyOf(d))
            return;
        if (fake)
            fakeOp.start(d, false);
        else if (Exec.allow(`bluetooth disconnect ${d.name} (${d.address})`))
            d.disconnect();
    }
    function forget(d): void {
        if (!d)
            return;
        if (fake)
            d.paired = d.bonded = d.connected = false;
        else if (Exec.allow(`bluetooth forget ${d.name} (${d.address})`))
            d.forget();
    }

    // stop a scan the shell started when nobody looks at the device list any more
    property int watchers: 0
    onWatchersChanged: if (watchers === 0 && ownScan && discovering)
        scan(false)

    // ---- fake data ------------------------------------------------------------
    component FakeDevice: QtObject {
        property string name
        property string address
        property string icon
        property bool paired
        property bool bonded: paired
        property bool connected
        property bool pairing: false
        property bool trusted: paired
        property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
        property bool batteryAvailable: false
        property real battery: 0
        property bool found: false // unpaired: listed once a scan found it
    }

    QtObject {
        id: fakeAdapter
        property bool enabled: true
        property bool discovering: false
    }

    readonly property list<QtObject> fakeDevices: [
        FakeDevice {
            name: "Sane\u2019s AirPods Pro"
            address: "F4:2B:8C:11:02:9A"
            icon: "audio-headphones"
            paired: true
            batteryAvailable: true
            battery: 0.82
        },
        FakeDevice {
            name: "WF-1000XM5"
            address: "D2:41:07:3E:6B:10"
            icon: "audio-headphones"
            paired: true
        },
        FakeDevice {
            name: "[TV] Samsung Q80 Series (55)"
            address: "98:7A:14:55:C0:E2"
            icon: "audio-card"
        }
    ]

    // a scan "finds" the unpaired fake devices after a moment
    Timer {
        id: fakeFind
        interval: Motion.ms(1400)
        onTriggered: {
            if (!fakeAdapter.discovering)
                return;
            for (const d of [...root.fakeDevices])
                d.found = true;
        }
    }

    Timer {
        id: fakeOp
        property var device: null
        property bool connecting: true
        interval: 1200
        function start(d, on: bool): void {
            device = d;
            connecting = on;
            if (on && !d.paired)
                d.pairing = true;
            d.state = on ? BluetoothDeviceState.Connecting : BluetoothDeviceState.Disconnecting;
            restart();
        }
        onTriggered: {
            const d = device;
            d.pairing = false;
            if (connecting)
                d.paired = d.bonded = true;
            d.connected = connecting;
            d.state = connecting ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected;
        }
    }
}
