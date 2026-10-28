import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services

// Bluetooth sheet, ref/09 + ref/09c: switch = adapter power, "Saved" devices with
// Connect / Disconnect, "Nearby" while scanning (the sheet scans as long as it
// is open) with Pair. Right click / Delete on a saved device forgets it.
SheetPage {
    id: page

    title: "Bluetooth"
    hasSwitch: Bt.available
    switchOn: Bt.enabled
    onToggled: Bt.toggle()

    Component.onCompleted: {
        Bt.watchers++;
        Bt.autoScan();
    }
    Component.onDestruction: Bt.watchers--
    Connections {
        target: Bt
        function onEnabledChanged() {
            if (Bt.enabled)
                Bt.autoScan();
        }
    }

    function statusOf(d): string {
        if (d.pairing)
            return "Pairing...";
        const s = Bt.stateOf(d);
        if (Bt.busyOf(d))
            return s === BluetoothDeviceState.Connecting ? "Connecting..." : "Disconnecting...";
        if (d.connected)
            return "Connected" + Bt.batteryText(d);
        return (d.paired || d.bonded) ? "Saved" : "Not paired";
    }

    component DeviceRow: SheetRow {
        required property var modelData
        icon: Bt.glyphFor(modelData)
        name: modelData.name
        sub: page.statusOf(modelData)
        on: modelData.connected
        button: modelData.connected ? "Disconnect" : (modelData.paired || modelData.bonded) ? "Connect" : "Pair"
        busy: Bt.busyOf(modelData)
        onActivated: modelData.connected ? Bt.disconnect(modelData) : Bt.connect(modelData)
        onSecondary: if (modelData.paired || modelData.bonded)
            Bt.forget(modelData)
    }

    SheetSection {
        caption: "Saved"
        visible: Bt.enabled && Bt.saved.length > 0
        Repeater {
            model: Bt.saved
            DeviceRow {}
        }
    }

    SheetSection {
        caption: "Nearby"
        visible: Bt.enabled
        status: Bt.discovering ? "Scanning" : ""
        action: "Scan"
        onActionClicked: Bt.scan(true)
        showHint: Bt.nearby.length === 0
        hint: Bt.discovering ? "Looking for devices… put the device in pairing mode" : "Not scanning"
        Repeater {
            model: Bt.nearby
            DeviceRow {}
        }
    }

    SheetSection {
        caption: "Devices"
        visible: !Bt.enabled
        showHint: true
        hint: Bt.available ? "Bluetooth is off" : "No Bluetooth adapter found"
    }
}
