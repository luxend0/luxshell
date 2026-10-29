pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// Output devices and per-app playback streams (Pipewire). Audio.qml keeps the
// default sink for the bar; this adds the lists for the sound sheet. Node
// properties are only filled while a PwObjectTracker binds the nodes, the
// sound sheet owns that tracker. Every write goes through Exec.
// LUXSHELL_FAKE_MIXER=1 lists two demo streams (they react locally).
Singleton {
    id: root

    readonly property bool fake: Env.get("LUXSHELL_FAKE_MIXER") === "1"
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream).sort((a, b) => sinkName(a).localeCompare(sinkName(b)))
    // app playback (media.class Stream/Output/Audio)
    readonly property var streams: fake ? [...fakeStreams] : nodes.filter(n => n.audio && n.isSink && n.isStream)
    // what the sound sheet has to track (fake streams are no Pipewire objects)
    readonly property var tracked: fake ? sinks : nodes.filter(n => n.audio && n.isSink)
    // input side (sound sheet with its input part, panels/SheetMenu): microphones (Audio/Source)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream).sort((a, b) => sinkName(a).localeCompare(sinkName(b)))

    function sinkName(n: var): string {
        return n ? (n.description || n.nickname || n.name) : "";
    }

    // desktop entry name when one matches ("Vesktop"), else what the stream says
    function appName(n: var): string {
        const p = n.properties ?? {};
        const raw = p["application.name"] || n.description || n.name;
        const bin = String(p["application.process.binary"] ?? "").replace(/\.bin$/, "");
        const entry = DesktopEntries.heuristicLookup(p["application.icon-name"] || bin || raw);
        return entry?.name || raw;
    }

    // themed icon path, "" if nothing resolves
    function appIcon(n: var): string {
        const p = n.properties ?? {};
        for (const name of [p["application.icon-name"], p["application.process.binary"], p["application.name"], n.name]) {
            if (!name)
                continue;
            const entry = DesktopEntries.heuristicLookup(String(name).replace(/\.bin$/, ""));
            const path = Quickshell.iconPath(entry?.icon || String(name).toLowerCase(), true);
            if (path !== "")
                return path;
        }
        return "";
    }

    // glyph of widgets/Glyphs / Icons
    function sinkIcon(n: var): string {
        const s = `${n?.name ?? ""} ${n?.description ?? ""}`.toLowerCase();
        if (s.includes("headset") || s.includes("headphone") || s.includes("bluez"))
            return "headphones";
        if (s.includes("hdmi") || s.includes("displayport"))
            return "monitor";
        return "speaker";
    }

    function sourceIcon(n: var): string {
        const s = `${n?.name ?? ""} ${n?.description ?? ""}`.toLowerCase();
        return s.includes("headset") || s.includes("headphone") || s.includes("bluez") ? "headphones" : "mic";
    }

    function setDefaultSource(n: var): void {
        if (n && Exec.allow(`default source = ${sinkName(n)}`))
            Pipewire.preferredDefaultAudioSource = n;
    }

    function setDefault(n: var): void {
        if (n && Exec.allow(`default sink = ${sinkName(n)}`))
            Pipewire.preferredDefaultAudioSink = n;
    }

    function setVolume(n: var, v: real): void {
        if (!n?.audio)
            return;
        const value = Math.max(0, Math.min(1, v));
        if (fake && n.fakeStream) {
            n.audio.volume = value;
            n.audio.muted = false;
            return;
        }
        if (!Exec.allow(`volume ${n.name} ${Math.round(value * 100)} %`))
            return;
        if (n.audio.muted)
            n.audio.muted = false;
        n.audio.volume = value;
    }

    function toggleMute(n: var): void {
        if (!n?.audio)
            return;
        if (fake && n.fakeStream)
            n.audio.muted = !n.audio.muted;
        else if (Exec.allow(`mute ${n.name} = ${!n.audio.muted}`))
            n.audio.muted = !n.audio.muted;
    }

    // ---- demo data (LUXSHELL_FAKE_MIXER=1) ----------------------------------
    component FakeStream: QtObject {
        readonly property bool fakeStream: true
        property string name
        property string description
        property var properties: ({})
        property QtObject audio: QtObject {
            property real volume: 1
            property bool muted: false
        }
    }

    readonly property list<QtObject> fakeStreams: [
        FakeStream {
            name: "spotify"
            description: "Spotify"
            properties: ({
                    "application.name": "Spotify",
                    "application.icon-name": "spotify"
                })
            Component.onCompleted: audio.volume = 0.72
        },
        FakeStream {
            name: "firefox"
            description: "Firefox"
            properties: ({
                    "application.name": "Firefox",
                    "application.icon-name": "firefox"
                })
            Component.onCompleted: audio.volume = 0.45
        }
    ]
}
