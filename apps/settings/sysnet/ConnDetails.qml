import QtQuick
import qs.config
import qs.services
import qs.apps.settings
import qs.apps.settings.displays

// Unfolded details of one NetworkManager profile (ConnList): connect automatically (switch),
// interface, IPv4 method, last used, DNS (segment Automatic | Custom; "Custom" opens a field
// for the servers, Enter or "Apply" sets them). Every change: services/NetConfig -> Exec.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var conn: null
    property var host: null
    readonly property var d: conn ? (NetConfig.details[conn.uuid] ?? null) : null
    readonly property var servers: d ? d.dns4.concat(d.dns6) : []
    readonly property bool custom: d !== null && (d.ignoreAuto || servers.length > 0)
    property string picked: ""   // the segment the user chose; "" = what the profile says
    readonly property string mode: picked !== "" ? picked : custom ? "custom" : "auto"
    readonly property bool busy: conn ? NetConfig.isBusy(conn.uuid) : false

    topPadding: s.detailPadTop
    bottomPadding: s.detailPadBottom

    function methodLabel(m: string): string {
        return ({
                "auto": "Automatic (DHCP)",
                "manual": "Manual",
                "link-local": "Link-local only",
                "shared": "Shared to other computers",
                "disabled": "Off"
            })[m] ?? (m === "" ? "…" : m);
    }
    function apply(text: string): void {
        const list = NetConfig.parseServers(text);
        if (list.length === 0 || !list.every(x => NetConfig.validIp(x)))
            return;
        NetConfig.setDns(conn, list);
        picked = "";
    }

    component KeyValue: Item {
        property string key: ""
        property string value: ""
        property bool mono: false
        width: root.width
        height: root.s.detailRow
        SText {
            anchors.verticalCenter: parent.verticalCenter
            size: root.s.detailSize
            font.weight: Font.Normal
            text: parent.key
            color: root.g.value
        }
        SText {
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - root.s.detailKey)
            elide: Text.ElideMiddle
            size: root.s.detailSize
            font.family: parent.mono ? Theme.monoFamily : Theme.fontFamily
            font.weight: Font.Normal
            text: parent.value
            color: root.g.label
        }
    }

    // connect automatically
    Item {
        width: root.width
        height: root.s.detailRow
        SText {
            anchors.verticalCenter: parent.verticalCenter
            size: root.s.detailSize
            font.weight: Font.Normal
            text: "Connect automatically"
            color: root.g.value
        }
        SwitchCtl {
            id: auto
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            on: root.conn?.autoconnect ?? false
            hovered: autoArea.containsMouse
            opacity: root.busy ? 0.5 : 1
            MouseArea {
                id: autoArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: NetConfig.setAutoconnect(root.conn, !root.conn.autoconnect)
            }
        }
    }
    KeyValue {
        key: "Interface"
        value: root.conn?.device || root.d?.iface || "any"
        mono: true
    }
    KeyValue {
        visible: root.conn?.kind !== "wireguard"
        key: "IPv4"
        value: root.methodLabel(root.d?.method4 ?? "")
    }
    KeyValue {
        key: "Last used"
        value: root.conn?.active ? "now" : (NetConfig.lastUsed(root.conn?.timestamp ?? 0) || "never")
    }

    // DNS
    Item {
        width: root.width
        height: root.s.detailRow + 6
        SText {
            anchors.verticalCenter: parent.verticalCenter
            size: root.s.detailSize
            font.weight: Font.Normal
            text: "DNS servers"
            color: root.g.value
        }
        Seg {
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            textSize: 14
            active: !root.busy && root.d !== null
            items: [
                {
                    "value": "auto",
                    "label": "Automatic"
                },
                {
                    "value": "custom",
                    "label": "Custom"
                }
            ]
            value: root.mode
            onPicked: v => {
                if (v === "auto" && root.custom)
                    NetConfig.setDns(root.conn, []);
                root.picked = v === "auto" ? "" : v;
                if (v === "custom")
                    Qt.callLater(() => field.edit());
            }
        }
    }
    Item {
        visible: root.mode === "custom"
        width: root.width
        height: root.g.fieldHeight + 12
        FieldCtl {
            id: field
            y: 6
            width: parent.width - applyBtn.width - 10
            host: root.host
            family: Theme.monoFamily
            text: root.servers.join(", ")
            placeholder: "1.1.1.1, 9.9.9.9, 2606:4700:4700::1111"
            valid: t => {
                const l = NetConfig.parseServers(t);
                return l.length === 0 || l.every(x => NetConfig.validIp(x));
            }
            onApplied: t => root.apply(t)
        }
        MiniButton {
            id: applyBtn
            x: parent.width - width
            y: field.y + (field.height - height) / 2
            text: "Apply"
            active: !root.busy && field.ok && NetConfig.parseServers(field.input.text).length > 0 && field.input.text.trim() !== root.servers.join(", ")
            onClicked: root.apply(field.input.text)
        }
    }
    SText {
        visible: root.mode === "custom" && !field.ok
        width: root.width
        size: 13
        font.weight: Font.Normal
        text: "Separate the addresses with commas or spaces, IPv4 or IPv6."
        color: Theme.danger
    }
}
