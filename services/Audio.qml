pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// Default sink volume (Pipewire). Reading is passive; step() is the only writer.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink?.audio
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string icon: muted || volume <= 0.001 ? "volume-x" : volume < 0.34 ? "volume" : volume < 0.67 ? "volume-1" : "volume-2"

    function step(delta: real): void {
        if (!ready)
            return;
        const v = Math.max(0, Math.min(1, sink.audio.volume + delta));
        if (Exec.allow(`volume ${Math.round(v * 100)} %`)) // LUXSHELL_DRYRUN: log only
            sink.audio.volume = v;
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
