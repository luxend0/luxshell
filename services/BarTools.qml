pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core

// Actions of the island's tool buttons (island/widgets/ToolButton.qml):
//   screenshot(mode)  services/Screenshot ("region" = slurp, "screen" = whole output)
//   pickColor()       hyprpicker -a (copies the value), then an activity with the value and a
//                     swatch (services/Activities). Format: Settings.islandPickerFormat.
// Both fold the island away first (it stays expanded while the pointer is on it and would
// otherwise be in the picture / under the picker's frozen frame): Ui.preview("collapsed")
// until the tool has the pointer, then the previous state comes back.
// Through Exec: LUXSHELL_DRYRUN only logs; the picker then shows a sample value.
Singleton {
    id: root

    property string lastColor: ""
    property string prevForced: ""
    property bool folded: false

    function fold(): void {
        if (!folded) {
            prevForced = Ui.forced;
            folded = true;
        }
        Ui.preview("collapsed");
    }
    function unfold(): void {
        if (!folded)
            return;
        folded = false;
        if (Ui.forced === "collapsed")
            Ui.preview(prevForced === "" ? "auto" : prevForced);
    }

    function screenshot(mode: string): void {
        fold();
        Screenshot.takeMode(mode === "screen" ? "screen" : "region");
        unfoldLater.restart(); // slurp / grim own the pointer by then
    }
    Timer {
        id: unfoldLater
        interval: Motion.ms(450) + 600
        onTriggered: root.unfold()
    }

    readonly property string format: ["hex", "rgb", "hsl"].includes(Settings.islandPickerFormat) ? Settings.islandPickerFormat : "hex"

    function pickColor(): void {
        if (picker.running || pickDelay.running)
            return;
        fold();
        pickDelay.restart();
    }
    Timer {
        id: pickDelay
        interval: Motion.ms(450) // island morph back into the collapsed bar
        onTriggered: {
            if (Exec.allow(`color picker: hyprpicker -a -f ${root.format}`)) {
                picker.command = ["hyprpicker", "-a", "-f", root.format];
                picker.running = true;
                return;
            }
            root.unfold();
            root.showColor(root.sample(), true);
        }
    }
    // dry run: a fixed sample in the chosen format
    function sample(): string {
        return format === "rgb" ? "59, 130, 246" : format === "hsl" ? "217, 91%, 60%" : "#3B82F6";
    }
    // colour of the value for the swatch ("transparent" = only the ring)
    function swatchOf(v: string): string {
        if (/^#?[0-9a-f]{6}$/i.test(v))
            return v.startsWith("#") ? v : "#" + v;
        const n = v.match(/[\d.]+/g);
        if (!n || n.length < 3)
            return "transparent";
        if (format === "rgb")
            return Qt.rgba(n[0] / 255, n[1] / 255, n[2] / 255, 1).toString();
        if (format === "hsl")
            return Qt.hsla(n[0] / 360, n[1] / 100, n[2] / 100, 1).toString();
        return "transparent";
    }
    function showColor(v: string, dry: bool): void {
        lastColor = v;
        Activities.show({
            "key": "color",
            "icon": "", // the swatch takes the icon's place
            "label": v,
            "detail": dry ? "Dry run" : "Copied",
            "swatch": swatchOf(v),
            "timeout": 2600
        });
    }

    Process {
        id: picker
        stdout: StdioCollector {
            onStreamFinished: {
                // hyprpicker prints the value (and copies it, -a); nothing on Esc
                const v = text.trim().split("\n").pop().trim();
                if (v !== "")
                    root.showColor(v, false);
            }
        }
        onRunningChanged: if (running)
            unfoldLater.restart()
        onExited: root.unfold()
    }
}
