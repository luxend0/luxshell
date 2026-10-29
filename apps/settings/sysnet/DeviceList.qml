import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Sound): the output or input devices (Pipewire sinks / sources of
// services/Mixer), icon by type (speaker, headphones, HDMI display, microphone, headset,
// webcam), bus and profile as sub line, the one in use lit with a check; a click or "Use"
// makes a device the default (Mixer.setDefault / setDefaultSource, through Exec).
// Option fields: input (bool). Keys: Up/Down walk, Enter/Space use.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    readonly property bool input: opt?.input === true
    readonly property var items: input ? Mixer.sources : Mixer.sinks
    readonly property var current: input ? Mic.source : Audio.sink
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 0 ? cur : -1

    function prop(n: var, k: string): string {
        return String(n?.properties?.[k] ?? "");
    }
    // what the node and its card say about the kind of device (a webcam's microphone names
    // "webcam" only on its card)
    function hay(n: var): string {
        const c = AudioCards.cardOf(n);
        return `${n?.name ?? ""} ${n?.description ?? ""} ${prop(n, "device.form_factor")} ${prop(n, "device.bus")} ${prop(n, "device.icon-name")} ${prop(n, "device.api")} ${c?.formFactor ?? ""} ${c?.icon ?? ""}`.toLowerCase();
    }
    function glyphOf(n: var): string {
        const s = hay(n);
        if (input) {
            if (s.includes("webcam") || s.includes("camera"))
                return Catalog.glyph(0xF05A0); // md-webcam
            if (s.includes("headset") || s.includes("bluez") || s.includes("bluetooth"))
                return Catalog.glyph(0xF02CE); // md-headset
            return Catalog.glyph(0xF036C); // md-microphone
        }
        if (s.includes("headset"))
            return Catalog.glyph(0xF02CE);
        if (s.includes("headphone") || s.includes("bluez") || s.includes("bluetooth"))
            return Catalog.glyph(0xF02CB); // md-headphones
        if (s.includes("hdmi") || s.includes("displayport"))
            return Catalog.glyph(0xF0379); // md-monitor
        return Catalog.glyph(0xF04C3); // md-speaker
    }
    function busOf(n: var): string {
        const s = hay(n);
        if (s.includes("bluez") || prop(n, "device.bus") === "bluetooth")
            return "Bluetooth";
        if (s.includes("hdmi"))
            return "HDMI";
        if (s.includes("displayport"))
            return "DisplayPort";
        const b = prop(n, "device.bus");
        return b === "usb" ? "USB" : b === "pci" ? "Built-in" : b === "" ? "" : b;
    }
    function subOf(n: var): string {
        const parts = [busOf(n), prop(n, "device.profile.description")].filter(x => x !== "");
        const tail = parts.join(" · ");
        return n === current ? (tail !== "" ? `In use · ${tail}` : "In use") : tail;
    }
    function pick(n: var): void {
        if (!n || n === current)
            return;
        if (input)
            Mixer.setDefaultSource(n);
        else
            Mixer.setDefault(n);
    }

    function summary(): string {
        return Mixer.sinkName(current);
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
        pick(items[cur]);
        return true;
    }
    function focusRect(): var {
        return {
            "y": cur * Theme.sysnet.line,
            "h": Theme.sysnet.line
        };
    }

    Line {
        visible: root.items.length === 0
        first: true
        clickable: false
        glyph: root.input ? Catalog.glyph(0xF036D) : Catalog.glyph(0xF0581) // md-microphone-off | md-volume-off
        title: root.input ? "No microphone" : "No output device"
        sub: "Pipewire reports none"
    }

    Repeater {
        model: root.items

        Line {
            id: line
            required property var modelData
            required property int index
            readonly property bool isCurrent: modelData === root.current
            first: index === 0
            roundTop: index === 0 && root.row !== null && root.row.first
            roundBottom: index === root.items.length - 1 && root.row !== null && root.row.last
            ring: root.cursor === index
            glyph: root.glyphOf(modelData)
            on: isCurrent
            title: Mixer.sinkName(modelData)
            sub: root.subOf(modelData)
            onClicked: {
                root.cur = index;
                if (root.host && root.row) {
                    root.host.focusRoot();
                    root.host.focusRow(root.row.flatIndex);
                }
                root.pick(modelData);
            }

            MdIcon {
                visible: line.isCurrent
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(0xF012C) // md-check
                size: 22
                color: root.g.label
            }
            MiniButton {
                visible: !line.isCurrent
                anchors.verticalCenter: parent.verticalCenter
                text: "Use"
                onClicked: {
                    root.cur = line.index;
                    root.pick(line.modelData);
                }
            }
        }
    }
}
