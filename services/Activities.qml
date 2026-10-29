pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.config
import qs.core

// Live activities: short status messages the island shows instead of the bar
// (overlay priority: below an open panel, above hover). ONE building block for all
// of them (panels/ActivityOverlay.qml); every message is a small data object:
//
//   key      identity ("volume", "mic", "layout", ...); the same key updates in place,
//            a different key swaps the content with a short dip
//   icon     Lucide name (widgets/Icons)
//   label    text where the slider would be (activities without a value)
//   value    0..1 -> slider + percentage; undefined / null -> no slider
//   detail   right-hand text (default: the percentage when value is set)
//   dim      slider fill dimmed (muted sink)
//   timeout  ms on screen (default 1600)
//   swatch   optional colour ("#3b82f6"): a filled disc in that colour instead of the icon
//
//   Activities.show({ key: "caps", icon: "arrow-big-up-dash", label: "Caps Lock", detail: "On" })
//
// Overlay ids: "activity" renders `current`; "osd" (volume) and "brightness" render a
// live preset instead, so `ipc call luxshell flash osd|brightness` works too (aliases).
//
// Triggers (real changes only, never the first reading after start or after a device
// switch): default sink volume/mute, default source volume/mute, default sink switch,
// Hyprland "activelayout". Caps Lock has no event: a keybind calls `ipc call activity capslock`.
// Test path without touching the system: IPC target "activity" (below) and
// LUXSHELL_FAKE_VOLUME / LUXSHELL_FAKE_BRIGHTNESS.
Singleton {
    id: root

    readonly property int defaultTimeout: 1600
    readonly property int settleMs: 1500 // first readings of a (new) device are not changes

    property var current: null
    readonly property var aliases: ({
            "volume": "osd",
            "brightness": "brightness"
        })

    function show(a: var): void {
        if (!a || !a.key)
            return;
        const id = aliases[a.key] ?? "activity";
        if (id === "activity")
            current = normalize(a);
        Ui.flash(id, Motion.ms(a.timeout > 0 ? a.timeout : defaultTimeout));
    }

    // what the overlay with this id shows
    function live(id: string): var {
        return id === "osd" ? volume : id === "brightness" ? brightness : current;
    }

    function normalize(a: var): var {
        const has = a.value !== undefined && a.value !== null && !isNaN(a.value);
        const v = has ? Math.max(0, Math.min(1, Number(a.value))) : null;
        return {
            "key": String(a.key),
            "icon": a.icon ?? "",
            "label": a.label ?? "",
            "value": v,
            "detail": a.detail !== undefined && a.detail !== null ? String(a.detail) : (has ? Math.round(v * 100) + "%" : ""),
            "dim": !!a.dim,
            "timeout": a.timeout ?? 0,
            "swatch": a.swatch ?? "" // colour shown instead of the icon (colour picker), "" = icon
        };
    }

    // ---- presets --------------------------------------------------------------------
    function envReal(name: string): real {
        const v = parseFloat(Env.get(name));
        return isNaN(v) ? -1 : Math.max(0, Math.min(1, v));
    }

    // volume: default sink, or the fake (env / ipc) when set
    property real fakeVolume: envReal("LUXSHELL_FAKE_VOLUME")
    property int fakeMuted: -1
    readonly property real vol: fakeVolume >= 0 ? fakeVolume : Audio.volume
    readonly property bool volMuted: fakeMuted >= 0 ? fakeMuted === 1 : Audio.muted
    readonly property var volume: normalize({
        "key": "volume",
        "icon": volMuted || vol <= 0.001 ? "volume-x" : vol < 0.34 ? "volume" : vol < 0.67 ? "volume-1" : "volume-2",
        "label": "Volume",
        "value": vol,
        "dim": volMuted
    })

    readonly property var brightness: normalize({
        "key": "brightness",
        "icon": Brightness.ready && Brightness.value < 0.34 ? "sun-dim" : "sun",
        "label": "Brightness",
        "value": Brightness.ready ? Brightness.value : null,
        "detail": Brightness.ready ? null : "n/a"
    })

    // microphone: default source
    readonly property var source: Pipewire.defaultAudioSource
    property int fakeMic: -1
    readonly property bool micMuted: fakeMic >= 0 ? fakeMic === 1 : (source?.audio?.muted ?? false)
    function micToggle(): var {
        return {
            "key": "mic",
            "icon": micMuted ? "mic-off" : "mic",
            "label": "Microphone",
            "detail": micMuted ? "Muted" : "On"
        };
    }
    function micLevel(): var {
        return {
            "key": "mic-level",
            "icon": micMuted ? "mic-off" : "mic",
            "label": "Microphone",
            "value": source?.audio?.volume ?? 0,
            "dim": micMuted
        };
    }

    function output(node: var): var {
        const name = node?.description || node?.nickname || node?.name || "Output";
        return {
            "key": "output",
            "icon": /head|ear|bud|kopfh/i.test(name) ? "headphones" : "speaker",
            "label": name,
            "detail": "Output"
        };
    }

    function layout(name: string): var {
        return {
            "key": "layout",
            "icon": "keyboard",
            "label": "Keyboard",
            "detail": name
        };
    }

    function caps(on: bool): var {
        return {
            "key": "caps",
            "icon": on ? "arrow-big-up-dash" : "arrow-big-up",
            "label": "Caps Lock",
            "detail": on ? "On" : "Off"
        };
    }

    // ---- triggers -----------------------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    property bool sinkArmed: false
    property bool sourceArmed: false
    property bool started: false // a device switch only counts once we were settled

    onSinkChanged: {
        if (started && sink && sinkArmed)
            show(output(sink));
        sinkArmed = false;
        sinkSettle.restart();
    }
    onSourceChanged: {
        sourceArmed = false;
        sourceSettle.restart();
    }

    Timer {
        id: sinkSettle
        interval: root.settleMs
        onTriggered: {
            root.sinkArmed = !!root.sink?.audio;
            root.started = root.started || root.sinkArmed;
        }
    }
    Timer {
        id: sourceSettle
        interval: root.settleMs
        onTriggered: root.sourceArmed = !!root.source?.audio
    }
    // binds the source node (Audio.qml binds the sink); read only
    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            if (root.sinkArmed && root.fakeVolume < 0)
                root.show(root.volume);
        }
        function onMutedChanged() {
            if (root.sinkArmed && root.fakeMuted < 0)
                root.show(root.volume);
        }
    }
    Connections {
        target: root.source?.audio ?? null
        function onVolumesChanged() {
            if (root.sourceArmed)
                root.show(root.micLevel());
        }
        function onMutedChanged() {
            if (root.sourceArmed && root.fakeMic < 0)
                root.show(root.micToggle());
        }
    }

    // one event per keyboard device: only a new layout name counts
    property string lastLayout: ""
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout")
                return;
            const name = ev.data.split(",").slice(1).join(",").trim();
            if (name === "" || name === root.lastLayout)
                return;
            root.lastLayout = name;
            root.show(root.layout(name));
        }
    }

    // a brightness OSD (keybind: ipc call luxshell flash brightness) reads the hardware anew
    Connections {
        target: Ui
        function onOverlayChanged() {
            if (Ui.overlay === "brightness")
                Brightness.refresh(true);
        }
    }

    // Caps Lock: the LED is updated after the key press reached the compositor
    Process {
        id: capsRead
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.show(root.caps(parseInt(text) > 0))
        }
    }
    Timer {
        id: capsDelay
        interval: 120
        onTriggered: capsRead.running = true
    }

    // ---- test path / keybind hooks: qs -c luxshell ipc call activity <fn> ----------------
    // Simulated values replace the readings for display only; the system is never touched.
    IpcHandler {
        target: "activity"

        // generic: push '{"key":"x","icon":"mic-off","label":"Microphone","detail":"Muted"}'
        // ("show" would collide with the `qs ipc show` subcommand)
        function push(json: string): void {
            try {
                root.show(JSON.parse(json));
            } catch (e) {
                console.warn(`luxshell: activity push: ${e}`);
            }
        }
        // simulated default-sink change (v < 0: back to the real sink, nothing shown)
        function volume(v: real): void {
            root.fakeVolume = v < 0 ? -1 : Math.min(1, v);
            if (v >= 0)
                root.show(root.volume);
        }
        function mute(on: bool): void {
            root.fakeMuted = on ? 1 : 0;
            root.show(root.volume);
        }
        function mic(muted: bool): void {
            root.fakeMic = muted ? 1 : 0;
            root.show(root.micToggle());
        }
        function brightness(v: real): void {
            Brightness.simulate(v);
            root.show(root.brightness);
        }
        function layout(name: string): void {
            root.lastLayout = name;
            root.show(root.layout(name));
        }
        // "" reads the LED (keybind on Caps_Lock), "on" / "off" for tests
        function capslock(state: string): void {
            if (state === "")
                capsDelay.restart();
            else
                root.show(root.caps(state === "on" || state === "1" || state === "true"));
        }
        function state(): string {
            return JSON.stringify({
                "overlay": Ui.overlay,
                "current": root.current,
                "volume": root.volume,
                "brightness": root.brightness,
                "mic": root.micToggle(),
                "armed": {
                    "sink": root.sinkArmed,
                    "source": root.sourceArmed
                },
                "layout": root.lastLayout
            });
        }
    }
}
