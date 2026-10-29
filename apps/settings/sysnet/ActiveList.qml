import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.apps.settings

// Bare custom row (System > Network & Bluetooth > Connection): every connected device
// (Ethernet, Wi-Fi, VPN; services/NetConfig, nmcli) with its profile name, speed or signal,
// and below it the addresses: IPv4, IPv6, gateway, DNS servers in use, MAC address.
// A click on an address copies it. Keys: Up/Down walk the addresses, Enter/Space copy.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null

    readonly property var items: NetConfig.devices
    // flat list of the address lines (keyboard)
    readonly property var lines: {
        const out = [];
        items.forEach((d, i) => infoOf(d).forEach((x, j) => out.push({
                        "dev": i,
                        "line": j,
                        "value": x.value
                    })));
        return out;
    }
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && lines.length > 0 ? cur : -1

    function glyphOf(d: var): string {
        if (d.type === "ethernet")
            return Catalog.glyph(0xF0200); // md-ethernet
        if (d.type === "wifi")
            return Catalog.glyph(0xF05A9); // md-wifi
        if (d.type === "wireguard")
            return Catalog.glyph(0xF030B); // md-key-variant
        if (d.type === "tun" || d.type === "vpn")
            return Catalog.glyph(0xF0582); // md-vpn
        return Catalog.glyph(0xF0317); // md-lan
    }
    function typeLabel(d: var): string {
        return ({
                "ethernet": "Ethernet",
                "wifi": "Wi-Fi",
                "wireguard": "WireGuard",
                "tun": "VPN",
                "vpn": "VPN",
                "bridge": "Bridge"
            })[d.type] ?? d.type;
    }
    function subOf(d: var): string {
        const parts = [typeLabel(d), d.device];
        const live = Networks.devices.find(x => x.name === d.device);
        if (d.type === "ethernet" && live) {
            const sp = Networks.speed(live);
            if (sp !== "")
                parts.push(sp);
        } else if (d.type === "wifi") {
            const w = Networks.wifiConnected;
            if (w)
                parts.push(`${Math.round(Networks.strength(w) * 100)} % signal`);
        }
        return parts.join(" · ");
    }
    // global addresses first, link-local (fe80::) last
    function v6(list: var): var {
        return list.slice().sort((a, b) => a.startsWith("fe80") - b.startsWith("fe80"));
    }
    function infoOf(d: var): var {
        const out = [];
        if (d.ip4.length > 0)
            out.push({
                "key": "IPv4 address",
                "value": d.ip4.join(", ")
            });
        const six = v6(d.ip6).filter(a => !a.startsWith("fe80"));
        if (six.length > 0)
            out.push({
                "key": "IPv6 address",
                "value": six[0] + (six.length > 1 ? `  +${six.length - 1}` : "")
            });
        const gw = [d.gw4, d.gw6].filter(x => x !== "");
        if (gw.length > 0)
            out.push({
                "key": "Gateway",
                "value": gw.join(", ")
            });
        const dns = d.dns4.concat(d.dns6);
        out.push({
            "key": "DNS servers",
            "value": dns.length > 0 ? dns.join(", ") : "none"
        });
        if (d.hwaddr !== "")
            out.push({
                "key": "MAC address",
                "value": d.hwaddr
            });
        return out;
    }
    function copy(text: string): void {
        const t = text.replace(/\s+\+\d+$/, "");
        Quickshell.clipboardText = t;
        SettingsApp.toast(`Copied ${t}`, null);
    }

    function navigate(d: int, mods: int): bool {
        const c = cur + d;
        if (c < 0 || c >= lines.length)
            return false;
        cur = c;
        return true;
    }
    function enter(d: int): void {
        cur = d > 0 ? 0 : Math.max(0, lines.length - 1);
    }
    function activate(): bool {
        const l = lines[cur];
        if (l)
            copy(l.value);
        return true;
    }
    function focusRect(): var {
        const l = lines[cur];
        if (!l)
            return null;
        let y = 0;
        for (let i = 0; i < l.dev; i++)
            y += s.line + infoOf(items[i]).length * s.infoRow + 8;
        return {
            "y": y + s.line + l.line * s.infoRow,
            "h": s.infoRow
        };
    }

    Line {
        visible: root.items.length === 0
        first: true
        clickable: false
        glyph: Catalog.glyph(0xF05AA) // md-wifi-off
        title: NetConfig.loaded ? "Not connected" : "Reading NetworkManager…"
        sub: NetConfig.loaded ? "No network device is connected" : ""
    }

    Repeater {
        model: root.items

        Column {
            id: block
            required property var modelData
            required property int index
            readonly property var info: root.infoOf(modelData)
            readonly property int base: root.lines.findIndex(l => l.dev === index)
            width: root.width
            bottomPadding: 8

            Line {
                first: block.index === 0
                clickable: false
                glyph: root.glyphOf(block.modelData)
                on: true
                title: block.modelData.connection
                sub: root.subOf(block.modelData)
            }

            Repeater {
                model: block.info
                Item {
                    id: info
                    required property var modelData
                    required property int index
                    readonly property bool ringed: root.cursor >= 0 && root.cursor === block.base + index
                    width: root.width
                    height: root.s.infoRow

                    Rectangle {
                        x: root.g.rowInset + root.s.disc + root.s.textGap - 10
                        width: parent.width - x - root.g.rowInset + 10
                        height: parent.height
                        radius: 10
                        color: root.g.hover
                        opacity: copyArea.containsMouse ? 1 : 0
                        Behavior on opacity {
                            Anim {
                                ms: Theme.fadeOut
                            }
                        }
                    }
                    Rectangle {
                        visible: info.ringed
                        x: root.g.rowInset + root.s.disc + root.s.textGap - 10
                        width: parent.width - x - root.g.rowInset + 10
                        height: parent.height
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: root.g.ring
                    }
                    SText {
                        x: root.g.rowInset + root.s.disc + root.s.textGap
                        anchors.verticalCenter: parent.verticalCenter
                        size: root.s.detailSize
                        font.weight: Font.Normal
                        text: info.modelData.key
                        color: root.g.value
                    }
                    SText {
                        x: parent.width - root.g.rowInset - width
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - root.g.rowInset - root.s.disc - root.s.textGap - root.s.detailKey - root.g.rowInset)
                        elide: Text.ElideMiddle
                        size: root.s.detailSize
                        font.family: Theme.monoFamily
                        font.weight: Font.Normal
                        text: info.modelData.value
                        color: root.g.label
                    }
                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.host && root.row) {
                                root.host.focusRoot();
                                root.host.focusRow(root.row.flatIndex);
                            }
                            root.cur = block.base + info.index;
                            root.copy(info.modelData.value);
                        }
                    }
                }
            }
        }
    }
}
