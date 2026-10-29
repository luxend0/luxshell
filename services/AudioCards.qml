pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sound cards and their profiles (System > Sound): Quickshell's Pipewire API has no devices,
// so `pactl -f json list cards` is read on demand (the page asks when it shows, after a
// profile change and when sinks / sources come or go), never on a timer of its own.
// setProfile() goes through Exec (LUXSHELL_DRYRUN=1 only logs).
//
//   cards  [{ id, name, label, bus, icon, active, profiles: [{ name, label, available,
//            priority, sinks, sources }] }]   id = Pipewire object id (a node's device.id)
Singleton {
    id: root

    property var cards: []
    property bool loaded: false
    readonly property var names: cards.map(c => c.name) // the page's structure: changes only when cards come or go

    function refresh(): void {
        if (!reader.running)
            reader.running = true;
        else
            again = true;
    }
    property bool again: false

    function cardOf(node: var): var {
        const id = String(node?.properties?.["device.id"] ?? "");
        return id === "" ? null : (cards.find(c => String(c.id) === id) ?? null);
    }
    function byName(name: string): var {
        return cards.find(c => c.name === name) ?? null;
    }
    function profileOf(card: var, name: string): var {
        return card ? (card.profiles.find(p => p.name === name) ?? null) : null;
    }
    // what the dropdown offers: available profiles (plus the active one), best first, Off last
    function choices(card: var): var {
        if (!card)
            return [];
        return card.profiles.filter(p => p.available || p.name === card.active).sort((a, b) => (a.name === "off") - (b.name === "off") || b.priority - a.priority);
    }

    function setProfile(card: var, profile: string): void {
        if (!card || profile === card.active)
            return;
        const label = profileOf(card, profile)?.label ?? profile;
        Exec.runDone(["pactl", "set-card-profile", card.name, profile], `sound card ${card.label}: profile ${label}`, ok => {
            root.refresh();
        });
    }

    Process {
        id: reader
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn(`luxshell: pactl list cards: ${e}`);
                    return;
                }
                const out = list.map(c => {
                    const p = c.properties ?? {};
                    const profiles = Object.entries(c.profiles ?? {}).map(([name, v]) => ({
                                "name": name,
                                "label": v.description ?? name,
                                "available": v.available !== false,
                                "priority": Number(v.priority ?? 0),
                                "sinks": Number(v.sinks ?? 0),
                                "sources": Number(v.sources ?? 0)
                            }));
                    return {
                        "id": String(p["object.id"] ?? c.index),
                        "name": String(c.name),
                        "label": String(p["device.description"] ?? p["device.product.name"] ?? c.name),
                        "bus": String(p["device.bus"] ?? ""),
                        "formFactor": String(p["device.form_factor"] ?? ""),
                        "icon": String(p["device.icon_name"] ?? ""),
                        "active": String(c.active_profile ?? ""),
                        "profiles": profiles
                    };
                });
                // same text: keep the old array (no rebuild of the rows)
                if (JSON.stringify(out) !== JSON.stringify(root.cards))
                    root.cards = out;
                root.loaded = true;
            }
        }
        onExited: if (root.again) {
            root.again = false;
            running = true;
        }
    }
}
