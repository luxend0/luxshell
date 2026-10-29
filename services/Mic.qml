pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// Default microphone (Pipewire source) for the control center's microphone tile and
// slider. Reading is passive; toggleMute() and setVolume() are the only writers and go
// through Exec (LUXSHELL_DRYRUN only logs).
//
// recorders: apps recording from a microphone right now, from services/Privacy (active links
// from a source into an app's capture stream; desktop-audio monitors, level meters and
// luxshell itself do not count; LUXSHELL_FAKE_PRIVACY="mic:<app>:<icon>" for screenshots).
// recording = any. The bar's microphone widget turns red on it, the sound menu names them.
Singleton {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: !!source?.audio
    readonly property real volume: source?.audio?.volume ?? 0
    readonly property bool muted: source?.audio?.muted ?? false
    readonly property string icon: muted || !ready ? "mic-off" : "mic"

    readonly property var recorders: Privacy.entries.filter(e => e.kind === "mic").map(e => e.app).filter((v, i, a) => v !== "" && a.indexOf(v) === i)
    readonly property bool recording: recorders.length > 0

    function toggleMute(): void {
        if (ready && Exec.allow(`microphone ${muted ? "unmute" : "mute"}`))
            source.audio.muted = !muted;
    }

    function setVolume(v: real): void {
        const to = Math.max(0, Math.min(1, v));
        if (ready && Exec.allow(`microphone volume ${Math.round(to * 100)} %`))
            source.audio.volume = to;
    }

    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }
}
