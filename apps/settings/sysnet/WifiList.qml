import QtQuick
import Quickshell.Networking
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Network & Bluetooth > Wi-Fi): the networks around, from
// services/Networks like the control center's network sheet (strongest per name; connected,
// then saved, then by signal), scanning while the page shows. A new secured network unfolds a
// password field in its line; Enter or "Join" connects (Exec, LUXSHELL_DRYRUN logs).
// LUXSHELL_FAKE_WIFI=1: demo adapter and networks. Keys: Up/Down walk, Enter/Space connect
// (or open the password field), Esc in the field folds it.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null
    readonly property var items: Networks.wifiNetworks
    property string asking: "" // network name with the password field open
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 0 ? cur : -1

    function glyphOf(n: var): string {
        const lvl = Math.max(1, Math.min(4, Math.ceil(Networks.strength(n) * 4)));
        const sec = Networks.secured(n);
        return Catalog.glyph([0, sec ? 0xF0921 : 0xF091F, sec ? 0xF0924 : 0xF0922, sec ? 0xF0927 : 0xF0925, sec ? 0xF092A : 0xF0928][lvl]);
    }
    function subOf(n: var): string {
        const st = n.connected ? "Connected" : n.known ? "Saved" : Networks.secured(n) ? "Secured" : "Open";
        return `${st} · ${Math.round(Networks.strength(n) * 100)} %`;
    }
    function act(n: var): void {
        if (!n)
            return;
        if (!Networks.needsPassword(n)) {
            asking = "";
            Networks.activate(n);
        } else {
            asking = asking === n.name ? "" : n.name;
        }
    }

    function navigate(d: int, mods: int): bool {
        const c = cur + d;
        if (c < 0 || c >= items.length)
            return false;
        cur = c;
        return true;
    }
    function enter(d: int): void {
        cur = d > 0 ? 0 : Math.max(0, items.length - 1);
    }
    function activate(): bool {
        act(items[cur]);
        return true;
    }
    function focusRect(): var {
        return {
            "y": cur * s.line,
            "h": s.line
        };
    }

    Line {
        visible: root.items.length === 0
        first: true
        clickable: false
        glyph: Catalog.glyph(Networks.wifiAvailable && Networks.wifiEnabled ? 0xF05A9 : 0xF05AA)
        title: !Networks.wifiAvailable ? "No Wi-Fi adapter" : !Networks.wifiEnabled ? "Wi-Fi is off" : "Looking for networks…"
        sub: !Networks.wifiAvailable ? "This computer has no wireless network card" : ""
    }

    Repeater {
        model: root.items

        Line {
            id: line
            required property var modelData
            required property int index
            readonly property bool open: root.asking === modelData.name
            first: index === 0
            roundTop: index === 0 && root.row !== null && root.row.first
            roundBottom: index === root.items.length - 1 && root.row !== null && root.row.last
            ring: root.cursor === index
            glyph: root.glyphOf(modelData)
            on: modelData.connected
            busy: modelData.stateChanging ?? false
            title: modelData.name
            sub: root.subOf(modelData)
            expanded: open
            details: pwComp
            onClicked: {
                root.cur = index;
                if (root.host && root.row) {
                    root.host.focusRoot();
                    root.host.focusRow(root.row.flatIndex);
                }
                root.act(modelData);
            }

            MiniButton {
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.connected ? "Disconnect" : line.open ? "Cancel" : "Connect"
                onClicked: {
                    root.cur = line.index;
                    root.act(line.modelData);
                }
            }

            Component {
                id: pwComp
                Item {
                    implicitHeight: root.s.pwHeight
                    function join(t: string): void {
                        if (t.length < 8)
                            return;
                        Networks.connectWithPassword(line.modelData, t);
                        root.asking = "";
                    }
                    FieldCtl {
                        id: pw
                        y: 2
                        width: parent.width - joinBtn.width - 10
                        host: root.host
                        placeholder: "Password"
                        valid: t => t.length === 0 || t.length >= 8
                        Component.onCompleted: {
                            input.echoMode = TextInput.Password;
                            input.forceActiveFocus();
                        }
                        onApplied: t => parent.join(t)
                    }
                    MiniButton {
                        id: joinBtn
                        x: parent.width - width
                        y: 2 + (pw.height - height) / 2
                        text: "Join"
                        active: pw.input.text.length >= 8
                        onClicked: parent.join(pw.input.text)
                    }
                }
            }
        }
    }
}
