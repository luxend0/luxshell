import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Network & Bluetooth > Bluetooth): the paired devices (opt.nearby
// false) with battery, Connect / Disconnect and unfolding details (trust, connect
// automatically, address, remove after a second click), or the devices nearby (opt.nearby
// true) with Pair, a search line on top. services/Bt like the control center's Bluetooth
// sheet; every change goes through Exec (LUXSHELL_DRYRUN logs). LUXSHELL_FAKE_BT=1: demo set.
// Keys: Up/Down walk, Enter/Space connect / pair (search line: search), Right / Left unfold /
// fold the details, Delete arms "Remove".
Column {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null
    readonly property bool nearby: opt?.nearby === true
    readonly property var items: !Bt.enabled ? [] : nearby ? Bt.nearby : Bt.saved
    readonly property int head: nearby && Bt.enabled ? 1 : 0 // the search line
    property string open: ""   // address with its details unfolded
    property int cur: 0
    readonly property int count: items.length + head
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && count > 0 ? cur : -1

    function glyphOf(d: var): string {
        return Catalog.glyph(({
                "headphones": 0xF02CB,
                "speaker": 0xF04C3,
                "volume-2": 0xF0502, // TV, soundbar: md-television
                "mouse": 0xF037D,
                "keyboard": 0xF030C,
                "gamepad": 0xF0297,
                "smartphone": 0xF011C,
                "laptop": 0xF0322
            })[Bt.glyphFor(d)] ?? 0xF00AF); // md-bluetooth
    }
    function statusOf(d: var): string {
        if (d.pairing)
            return "Pairing…";
        if (Bt.busyOf(d))
            return Bt.stateOf(d) === BluetoothDeviceState.Connecting ? "Connecting…" : "Disconnecting…";
        const bat = d.batteryAvailable ? ` · battery ${Math.round(d.battery * 100)} %` : "";
        if (d.connected)
            return "Connected" + bat;
        if (d.paired || d.bonded)
            return (Bt.autoConnects(d) ? "Saved · connects automatically" : "Saved") + bat;
        return "Not paired";
    }
    function act(d: var): void {
        if (!d)
            return;
        if (d.connected)
            Bt.disconnect(d);
        else
            Bt.connect(d);
    }
    function toggle(d: var): void {
        if (d && !nearby)
            open = open === d.address ? "" : d.address;
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
        if (c < 0 || c >= count)
            return false;
        cur = c;
        return true;
    }
    function enter(d: int): void {
        cur = d > 0 ? 0 : Math.max(0, count - 1);
    }
    function activate(): bool {
        if (cur < head)
            Bt.scan(!Bt.discovering);
        else
            act(items[cur - head]);
        return true;
    }
    function adjust(d: int): bool {
        const dev = items[cur - head];
        if (!dev || nearby)
            return false;
        if ((d > 0) !== (open === dev.address))
            toggle(dev);
        else
            return d > 0;
        return true;
    }
    function deleteKey(): bool {
        const it = rep.itemAt(cur - head);
        if (!it || nearby)
            return false;
        it.removeButton.arm();
        return true;
    }
    function focusRect(): var {
        let y = head * s.line;
        for (let i = 0; i < cur - head; i++)
            y += rep.itemAt(i)?.height ?? s.line;
        return {
            "y": cur < head ? 0 : y,
            "h": cur < head ? s.line : (rep.itemAt(cur - head)?.height ?? s.line)
        };
    }

    // off / nothing paired
    Line {
        visible: !Bt.enabled || (!root.nearby && root.items.length === 0)
        first: true
        clickable: false
        glyph: Catalog.glyph(Bt.enabled ? 0xF00AF : 0xF00B2) // md-bluetooth | md-bluetooth-off
        title: !Bt.available ? "No Bluetooth adapter" : !Bt.enabled ? "Bluetooth is off" : "No paired devices"
        sub: Bt.enabled && !root.nearby ? "Pair one below, it shows up here" : ""
    }

    // nearby: search line
    Line {
        visible: root.head > 0
        first: true
        roundTop: root.row !== null && root.row.first
        ring: root.cursor === 0 && root.head > 0
        clickable: false
        glyph: Catalog.glyph(0xF0349) // md-magnify
        on: Bt.discovering
        busy: Bt.discovering
        title: Bt.discovering ? "Searching…" : "Search for devices"
        sub: Bt.discovering ? "Put the device in pairing mode" : root.items.length === 0 ? "Nothing found yet" : `${root.items.length} found`
        MiniButton {
            anchors.verticalCenter: parent.verticalCenter
            text: Bt.discovering ? "Stop" : "Search"
            onClicked: {
                root.focusMe(0);
                Bt.scan(!Bt.discovering);
            }
        }
    }

    Repeater {
        id: rep
        model: root.items

        Line {
            id: line
            required property var modelData
            required property int index
            property Item removeButton: remove
            first: index === 0 && root.head === 0
            roundTop: index === 0 && root.head === 0 && root.row !== null && root.row.first
            roundBottom: index === root.items.length - 1 && root.row !== null && root.row.last
            ring: root.cursor === index + root.head
            glyph: root.glyphOf(modelData)
            on: modelData.connected
            busy: Bt.busyOf(modelData)
            title: modelData.name
            sub: root.statusOf(modelData)
            expanded: root.open === modelData.address
            details: detailsComp
            onClicked: {
                root.focusMe(index + root.head);
                if (root.nearby)
                    root.act(modelData);
                else
                    root.toggle(modelData);
            }

            MiniButton {
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.connected ? "Disconnect" : root.nearby ? "Pair" : "Connect"
                active: !Bt.busyOf(line.modelData)
                onClicked: {
                    root.focusMe(line.index + root.head);
                    root.act(line.modelData);
                }
            }
            MiniButton {
                visible: !root.nearby
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(line.expanded ? 0xF0143 : 0xF0140)
                onClicked: {
                    root.focusMe(line.index + root.head);
                    root.toggle(line.modelData);
                }
            }
            ConfirmButton {
                id: remove
                visible: !root.nearby
                anchors.verticalCenter: parent.verticalCenter
                confirm: "Remove"
                onConfirmed: {
                    root.open = "";
                    Bt.forget(line.modelData);
                }
            }

            Component {
                id: detailsComp
                Column {
                    bottomPadding: root.s.detailPadBottom
                    BtSwitch {
                        key: "Trust (reconnects by itself)"
                        on: line.modelData.trusted
                        onToggled: Bt.setTrusted(line.modelData, !line.modelData.trusted)
                    }
                    BtSwitch {
                        key: "Connect automatically"
                        on: Bt.autoConnects(line.modelData)
                        onToggled: Bt.setAutoConnect(line.modelData, !Bt.autoConnects(line.modelData))
                    }
                    Item {
                        width: root.width - root.g.rowInset * 2 - root.s.disc - root.s.textGap
                        height: root.s.detailRow
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.s.detailSize
                            font.weight: Font.Normal
                            text: "Address"
                            color: root.g.value
                        }
                        SText {
                            x: parent.width - width
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.s.detailSize
                            font.family: Theme.monoFamily
                            font.weight: Font.Normal
                            text: line.modelData.address
                            color: root.g.label
                        }
                    }
                }
            }
        }
    }

    component BtSwitch: Item {
        id: sw
        property string key: ""
        property bool on: false
        signal toggled
        width: root.width - root.g.rowInset * 2 - root.s.disc - root.s.textGap
        height: root.s.detailRow
        SText {
            anchors.verticalCenter: parent.verticalCenter
            size: root.s.detailSize
            font.weight: Font.Normal
            text: sw.key
            color: root.g.value
        }
        SwitchCtl {
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            on: sw.on
            hovered: swArea.containsMouse
            MouseArea {
                id: swArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sw.toggled()
            }
        }
    }
}
