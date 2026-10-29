import QtQuick
import qs.config
import qs.services
import qs.apps.settings
import qs.apps.settings.sysnet

// System > Network & Bluetooth. Network: the connected devices with addresses (IPv4, IPv6,
// gateway, DNS, MAC; services/NetConfig reads nmcli), Wi-Fi on/off and the networks around
// (services/Networks, like the control center's sheet), the saved profiles (connect
// automatically, details with own DNS servers, forget after a second click) and the VPN /
// WireGuard profiles (connect / disconnect). Bluetooth: adapter on/off, visible, name, the
// paired devices (battery, connect, trust, connect automatically, remove) and the devices
// nearby (search, pair), services/Bt like the control center's sheet.
// Every change goes through Exec (nmcli, BlueZ; LUXSHELL_DRYRUN=1 logs); nmcli may ask polkit.
// While the page shows it re-reads nmcli every 15 s and after each change, scans for Wi-Fi
// and Bluetooth devices; nothing runs while it is closed. Key: btAutoConnect.
// Test data: LUXSHELL_FAKE_NM=1 (profiles, addresses), LUXSHELL_FAKE_WIFI=1, LUXSHELL_FAKE_BT=1.
SettingsPage {
    id: page

    pageId: "network"
    group: "system"
    title: "Network & Bluetooth"
    subtitle: "Connections, addresses, Wi-Fi, VPN and Bluetooth devices."
    icon: 0xF05A9 // md-wifi

    readonly property bool shown: SettingsApp.open && SettingsApp.page === pageId
    readonly property bool live: shown || (SettingsApp.open && SettingsApp.query.trim() !== "")

    Timer {
        running: page.live
        repeat: true
        triggeredOnStart: true
        interval: 15000
        onTriggered: NetConfig.refresh()
    }
    // a device that connects or drops: read the addresses again
    Connections {
        target: Net
        function onKindChanged() {
            if (page.live)
                NetConfig.refresh();
        }
        function onLabelChanged() {
            if (page.live)
                NetConfig.refresh();
        }
    }
    Connections {
        target: NetConfig
        function onFailed(text) {
            SettingsApp.toast(text.length > 90 ? text.slice(0, 88) + "…" : text, null);
        }
    }
    // scan for networks and Bluetooth devices while the page shows (like the control center's sheets)
    property bool watching: false
    onShownChanged: {
        if (shown && !watching) {
            watching = true;
            Bt.watchers++;
            Bt.autoScan();
            Networks.setScanning(true);
        } else if (!shown && watching) {
            watching = false;
            Bt.watchers--;
            Networks.setScanning(false);
        }
    }
    Connections {
        target: Bt
        function onEnabledChanged() {
            if (page.shown && Bt.enabled)
                Bt.autoScan();
        }
    }

    Component {
        id: activeList
        ActiveList {}
    }
    Component {
        id: wifiList
        WifiList {}
    }
    Component {
        id: connList
        ConnList {}
    }
    Component {
        id: btList
        BtList {}
    }

    sections: [
        {
            "title": "Connection",
            "options": [
                {
                    "id": "netActive",
                    "kind": "custom",
                    "label": "",
                    "keywords": "network connection ethernet wifi ip address ipv4 ipv6 gateway router dns mac hardware address connected",
                    "component": activeList
                }
            ]
        },
        {
            "title": "Wi-Fi",
            "options": [
                {
                    "id": "netWifi",
                    "kind": "switch",
                    "label": "Wi-Fi",
                    "keywords": "wifi wi-fi wlan wireless radio on off",
                    "resettable": false,
                    "enabled": () => Networks.wifiAvailable,
                    "value": () => Networks.wifiEnabled,
                    "set": on => Networks.setWifi(on)
                },
                {
                    "id": "netWifiList",
                    "kind": "custom",
                    "label": "",
                    "keywords": "wifi wi-fi wlan wireless networks ssid join password connect scan",
                    "component": wifiList
                }
            ]
        },
        {
            "title": "Saved connections",
            "options": [
                {
                    "id": "netSaved",
                    "kind": "custom",
                    "label": "",
                    "keywords": "saved connections profiles nmcli auto connect autoconnect forget delete details dns servers custom",
                    "component": connList
                }
            ]
        },
        {
            "title": "VPN",
            "options": [
                {
                    "id": "netVpn",
                    "kind": "custom",
                    "label": "",
                    "vpn": true,
                    "keywords": "vpn wireguard wg openvpn tunnel connect disconnect",
                    "component": connList
                }
            ]
        },
        {
            "title": "Bluetooth",
            "options": [
                {
                    "id": "btPower",
                    "kind": "switch",
                    "label": "Bluetooth",
                    "keywords": "bluetooth adapter on off power radio",
                    "resettable": false,
                    "enabled": () => Bt.available && !Bt.busy,
                    "value": () => Bt.enabled,
                    "set": on => Bt.setEnabled(on)
                },
                {
                    "id": "btVisible",
                    "kind": "switch",
                    "label": "Visible to other devices",
                    "keywords": "bluetooth visible discoverable visibility find this computer",
                    "resettable": false,
                    "enabled": () => Bt.available && Bt.enabled,
                    "value": () => Bt.discoverable,
                    "set": on => Bt.setDiscoverable(on)
                },
                {
                    "id": "btName",
                    "kind": "text",
                    "label": "Name",
                    "keywords": "bluetooth adapter name alias computer name visible as",
                    "resettable": false,
                    "placeholder": "luxos",
                    "enabled": () => Bt.available,
                    "value": () => Bt.adapterName,
                    "valid": t => t.trim().length > 0 && t.length <= 248,
                    "apply": t => Bt.setAdapterName(t)
                },
                {
                    "id": "btDevices",
                    "kind": "custom",
                    "label": "",
                    "keys": ["btAutoConnect"], // "Reset page" clears the auto-connect list (Undo in the toast)
                    "keywords": "bluetooth devices paired saved headphones battery connect disconnect trust trusted auto connect remove forget",
                    "component": btList
                }
            ]
        },
        {
            "title": "Nearby devices",
            "options": [
                {
                    "id": "btNearby",
                    "kind": "custom",
                    "label": "",
                    "nearby": true,
                    "keywords": "bluetooth nearby search scan discover pair new device",
                    "component": btList
                }
            ]
        }
    ]
}
