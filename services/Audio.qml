pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Default sink volume (Pipewire). Reading is passive; step() is the only writer.
// step() stops at Settings.soundMaxVolume (100 %, or a boost up to 150 %) and plays the
// feedback click (Settings.soundFeedback) once the scrolling ends.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink?.audio
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string icon: muted || volume <= 0.001 ? "volume-x" : volume < 0.34 ? "volume" : volume < 0.67 ? "volume-1" : "volume-2"
    // highest volume scrolling and the Sound page reach (1 = 100 %)
    readonly property real limit: Math.max(1, Math.min(1.5, Settings.soundMaxVolume / 100))

    function step(delta: real): void {
        if (!ready)
            return;
        // a volume above the limit (set elsewhere) only goes down
        const top = Math.max(limit, sink.audio.volume);
        const v = Math.max(0, Math.min(delta > 0 ? limit : top, sink.audio.volume + delta));
        if (delta > 0 && sink.audio.volume >= limit - 0.0005)
            return;
        if (Exec.allow(`volume ${Math.round(v * 100)} %`)) // LUXSHELL_DRYRUN: log only
            sink.audio.volume = v;
        feedback();
    }

    // ---- feedback click (Settings.soundFeedback) ---------------------------------------
    readonly property string feedbackFile: "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
    // call after a volume change by the user; a burst (scrolling) clicks once at its end
    function feedback(): void {
        if (Settings.soundFeedback)
            feedbackDelay.restart();
    }
    function playFeedback(): void {
        const target = Env.get("LUXSHELL_SOUND_TARGET");
        if (target !== "") // tests on a null sink, like the notification sound
            Quickshell.execDetached(["pw-play", "--target", target, feedbackFile]);
        else
            Exec.run(["pw-play", feedbackFile], "volume feedback");
    }
    Timer {
        id: feedbackDelay
        interval: 180
        onTriggered: root.playFeedback()
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
