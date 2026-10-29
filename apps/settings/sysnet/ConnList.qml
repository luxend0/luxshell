import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Network & Bluetooth): saved NetworkManager profiles
// (services/NetConfig, nmcli). opt.vpn: the VPN / WireGuard profiles with Connect /
// Disconnect, else Ethernet and Wi-Fi. Each line unfolds its details: connect automatically,
// interface, IPv4, last used, and the DNS servers of the profile (automatic or own servers,
// IPv4 and IPv6 mixed, a connected profile takes them at once). The bin forgets the profile
// after a second click. Every change goes through Exec (nmcli; LUXSHELL_DRYRUN logs).
// Keys: Up/Down walk, Right / Left unfold / fold, Enter/Space connect (VPN) or unfold,
// Delete arms "Forget" (a second Delete forgets).
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null
    readonly property bool vpn: opt?.vpn === true
    readonly property var items: vpn ? NetConfig.vpns : NetConfig.saved
    property string open: ""      // uuid with its details unfolded
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 0 ? cur : -1

    function glyphOf(c: var): string {
        return Catalog.glyph(({
                "ethernet": 0xF0200, // md-ethernet
                "wifi": 0xF05A9, // md-wifi
                "wireguard": 0xF030B, // md-key-variant
                "vpn": 0xF0582 // md-vpn
            })[c.kind] ?? 0xF0317); // md-lan
    }
    function subOf(c: var): string {
        const parts = [NetConfig.typeLabel(c)];
        if (c.activating)
            parts.push("Connecting…");
        else if (c.active)
            parts.push(c.device !== "" ? `Connected · ${c.device}` : "Connected");
        else if (c.timestamp > 0)
            parts.push(`last used ${NetConfig.lastUsed(c.timestamp)}`);
        else
            parts.push("never used");
        if (!c.autoconnect)
            parts.push("manual");
        return parts.join(" · ");
    }
    function toggle(c: var): void {
        if (!c)
            return;
        open = open === c.uuid ? "" : c.uuid;
        if (open !== "")
            NetConfig.loadDetails(c.uuid);
    }
    function connectToggle(c: var): void {
        if (!c || NetConfig.isBusy(c.uuid))
            return;
        if (c.active)
            NetConfig.down(c);
        else
            NetConfig.up(c);
    }
    function focusMe(i: int): void {
        cur = i;
        if (host && row) {
            host.focusRoot();
            host.focusRow(row.flatIndex);
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
    function adjust(d: int): bool {
        const c = items[cur];
        if (!c)
            return false;
        if (d > 0 && open !== c.uuid)
            toggle(c);
        else if (d < 0 && open === c.uuid)
            toggle(c);
        else
            return d > 0;
        return true;
    }
    function activate(): bool {
        const c = items[cur];
        if (vpn)
            connectToggle(c);
        else
            toggle(c);
        return true;
    }
    function deleteKey(): bool {
        const it = rep.itemAt(cur);
        if (!it)
            return false;
        it.forgetButton.arm();
        return true;
    }
    function focusRect(): var {
        let y = 0;
        for (let i = 0; i < cur; i++)
            y += rep.itemAt(i)?.height ?? s.line;
        return {
            "y": y,
            "h": rep.itemAt(cur)?.height ?? s.line
        };
    }

    Line {
        visible: root.items.length === 0
        first: true
        clickable: false
        glyph: Catalog.glyph(root.vpn ? 0xF0582 : 0xF0317)
        title: !NetConfig.loaded ? "Reading NetworkManager…" : root.vpn ? "No VPN or WireGuard connections" : "No saved connections"
        sub: NetConfig.loaded && root.vpn ? "Import one with: nmcli connection import type wireguard file wg0.conf" : ""
    }

    Repeater {
        id: rep
        model: root.items

        Line {
            id: line
            required property var modelData
            required property int index
            property Item forgetButton: forget
            first: index === 0
            roundTop: index === 0 && root.row !== null && root.row.first
            roundBottom: index === root.items.length - 1 && root.row !== null && root.row.last
            ring: root.cursor === index
            glyph: root.glyphOf(modelData)
            on: modelData.active
            busy: NetConfig.isBusy(modelData.uuid) || modelData.activating
            title: modelData.name
            sub: root.subOf(modelData)
            expanded: root.open === modelData.uuid
            details: detailsComp
            onClicked: {
                root.focusMe(index);
                root.toggle(modelData);
            }

            MiniButton {
                visible: root.vpn
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.active ? "Disconnect" : "Connect"
                active: !NetConfig.isBusy(line.modelData.uuid)
                onClicked: {
                    root.focusMe(line.index);
                    root.connectToggle(line.modelData);
                }
            }
            MiniButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(line.expanded ? 0xF0143 : 0xF0140) // md-chevron-up | down
                onClicked: {
                    root.focusMe(line.index);
                    root.toggle(line.modelData);
                }
            }
            ConfirmButton {
                id: forget
                anchors.verticalCenter: parent.verticalCenter
                confirm: "Forget"
                active: !NetConfig.isBusy(line.modelData.uuid)
                onConfirmed: {
                    if (root.open === line.modelData.uuid)
                        root.open = "";
                    NetConfig.forget(line.modelData);
                }
            }

            Component {
                id: detailsComp
                ConnDetails {
                    conn: line.modelData
                    host: root.host
                }
            }
        }
    }
}
