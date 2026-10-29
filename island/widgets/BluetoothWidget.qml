import QtQuick
import qs.config
import qs.core
import qs.services

// Bluetooth (services/Bt): glyph off / on / connected, dimmed while off; with a connected
// device its battery (Settings.islandBluetoothBattery, BlueZ battery service) and name
// (Settings.islandBluetoothName). Click opens the Bluetooth menu (panel "sheet-bluetooth").
BarToggle {
    id: root

    readonly property bool on: Bt.available && Bt.enabled
    // the device worth naming: one with a battery reading first
    readonly property var device: Bt.connectedDevices.find(d => d.batteryAvailable) ?? Bt.connectedDevices[0] ?? null
    readonly property string name: {
        const n = device ? String(device.name) : "";
        return n.length > 18 ? n.slice(0, 17).trim() + "…" : n;
    }
    readonly property string battery: device && device.batteryAvailable ? `${Math.round(device.battery * 100)}%` : ""

    icon: !on ? "bluetooth-off" : device ? "bluetooth-connected" : "bluetooth"
    color: on ? Theme.text : Theme.menus.off
    text: [Settings.islandBluetoothName ? name : "", Settings.islandBluetoothBattery ? battery : ""].filter(s => s !== "").join(" ")
    wantsRight: false
    onClicked: Ui.open("sheet-bluetooth", root.screen ? root.screen.name : undefined)
}
