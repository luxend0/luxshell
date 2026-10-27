pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Network state from NetworkManager (Quickshell.Networking, D-Bus, no polling).
// Read only. bars: 0 offline, 1..4 Wi-Fi strength, 4 wired.
Singleton {
    id: root

    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null

    readonly property string kind: wired ? "ethernet" : wifi ? "wifi" : "offline"
    readonly property real strength: {
        if (wired)
            return 1;
        const s = wifiNetwork?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }
    readonly property int bars: kind === "ethernet" ? 4 : kind === "wifi" ? Math.max(1, Math.min(4, Math.ceil(strength * 4))) : 0
    readonly property string label: wired ? "Ethernet" : wifiNetwork?.name ?? "Offline"
}
