pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout of the main keyboard (Hyprland): read once from `hyprctl devices`,
// then from its "activelayout" events (virtual keyboards such as wtype send their own, those
// are ignored). code: short form ("German" -> "DE").
Singleton {
    id: root

    property string name: ""
    property string keyboard: "" // main keyboard; events of other (virtual) keyboards are ignored
    readonly property string code: short(name)

    readonly property var codes: ({
            "german": "DE",
            "english": "EN",
            "english (us)": "US",
            "english (uk)": "UK",
            "french": "FR",
            "spanish": "ES",
            "italian": "IT",
            "dutch": "NL",
            "polish": "PL",
            "russian": "RU",
            "ukrainian": "UA",
            "swedish": "SE",
            "norwegian": "NO",
            "danish": "DK",
            "finnish": "FI",
            "portuguese": "PT",
            "turkish": "TR",
            "czech": "CZ",
            "swiss": "CH",
            "japanese": "JP",
            "korean": "KR"
        })
    function short(n: string): string {
        const k = n.toLowerCase().trim();
        if (k === "")
            return "";
        if (codes[k])
            return codes[k];
        const base = k.replace(/\s*\(.*\)$/, "");
        return codes[base] ?? n.slice(0, 2).toUpperCase();
    }

    Component.onCompleted: devices.running = true

    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main) {
                        root.keyboard = main.name ?? "";
                        root.name = main.active_keymap ?? "";
                    }
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const d = event.data;
            const i = d.indexOf(",");
            if (i >= 0 && (root.keyboard === "" || d.slice(0, i) === root.keyboard))
                root.name = d.slice(i + 1);
        }
    }
}
