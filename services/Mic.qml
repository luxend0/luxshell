pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// Default microphone (Pipewire source) for the control center's microphone tile and
// slider. Reading is passive; toggleMute() and setVolume() are the only writers and go
// through Exec (LUXSHELL_DRYRUN only logs).
Singleton {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: !!source?.audio
    readonly property real volume: source?.audio?.volume ?? 0
    readonly property bool muted: source?.audio?.muted ?? false
    readonly property string icon: muted || !ready ? "mic-off" : "mic"

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
