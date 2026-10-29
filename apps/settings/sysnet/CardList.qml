import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Sound > Sound cards): every sound card (services/AudioCards,
// pactl) with its profile, e.g. HDMI vs. analog, stereo vs. surround, output + input, or Off.
// The dropdown offers the profiles the card can use now (best first); a pick goes through Exec
// (pactl set-card-profile). Keys: Up/Down walk the cards, Enter/Space open the profiles.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    readonly property var items: AudioCards.cards
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 0 ? cur : -1

    function glyphOf(c: var): string {
        const s = `${c.name} ${c.icon} ${c.formFactor}`.toLowerCase();
        if (s.includes("webcam") || s.includes("camera"))
            return Catalog.glyph(0xF05A0); // md-webcam
        if (s.includes("bluez"))
            return Catalog.glyph(0xF02CB); // md-headphones
        if (s.includes("hdmi") || c.profiles.some(p => p.name.includes("hdmi")))
            return Catalog.glyph(0xF0379); // md-monitor
        if (c.profiles.every(p => p.sinks === 0))
            return Catalog.glyph(0xF036C); // md-microphone
        return Catalog.glyph(0xF04C3); // md-speaker
    }
    function subOf(c: var): string {
        const hdmi = c.profiles.some(p => p.name.includes("hdmi"));
        const bus = hdmi ? "HDMI / DisplayPort" : c.bus === "usb" ? "USB" : c.bus === "pci" ? "Built-in" : c.bus === "bluetooth" ? "Bluetooth" : c.bus;
        const n = AudioCards.choices(c).filter(p => p.name !== "off").length;
        return [bus, c.active === "off" ? "Off" : `${n} profile${n === 1 ? "" : "s"}`].filter(x => x !== "").join(" · ");
    }
    function openProfiles(i: int, anchor: Item): void {
        const c = items[i];
        if (!c || !host)
            return;
        const name = c.name;
        host.openMenu(anchor, {
            "kind": "choice",
            "options": () => AudioCards.choices(AudioCards.byName(name)).map(p => ({
                        "value": p.name,
                        "label": p.label,
                        "detail": p.name === "off" ? "" : [p.sinks > 0 ? "output" : "", p.sources > 0 ? "input" : ""].filter(x => x !== "").join(" + ")
                    })),
            "value": () => AudioCards.byName(name)?.active ?? "",
            "set": v => AudioCards.setProfile(AudioCards.byName(name), v)
        });
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
        const it = rep.itemAt(cur);
        if (it)
            openProfiles(cur, it);
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
        glyph: Catalog.glyph(0xF04C3)
        title: AudioCards.loaded ? "No sound cards" : "Reading the sound cards…"
        sub: AudioCards.loaded ? "pactl lists none" : ""
    }

    Repeater {
        id: rep
        model: root.items

        Line {
            id: line
            required property var modelData
            required property int index
            readonly property var prof: AudioCards.profileOf(modelData, modelData.active)
            first: index === 0
            roundTop: index === 0 && root.row !== null && root.row.first
            roundBottom: index === root.items.length - 1 && root.row !== null && root.row.last
            ring: root.cursor === index
            glyph: root.glyphOf(modelData)
            on: modelData.active !== "off"
            title: modelData.label
            sub: root.subOf(modelData)
            onClicked: {
                root.cur = index;
                if (root.host && root.row) {
                    root.host.focusRoot();
                    root.host.focusRow(root.row.flatIndex);
                }
                root.openProfiles(index, line);
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 300)
                    elide: Text.ElideRight
                    size: 15
                    text: line.prof?.label ?? line.modelData.active
                    color: root.g.value
                }
                MdIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Catalog.glyph(0xF0140) // md-chevron-down
                    size: root.g.arrowSize + 3
                    color: root.g.value
                }
            }
        }
    }
}
