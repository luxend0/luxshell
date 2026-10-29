import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.apps.settings
import qs.apps.settings.sysnet

// System > Sound: output device (list with type icons, the one in use lit), its volume up to
// the volume limit and the left / right balance; input device, its level and a live meter;
// the volume of every app that plays (services/Mixer, like the control center's sheet);
// system sounds (volume click, link to the notification sound); the profile of every sound
// card (services/AudioCards, pactl). Device state is read from Pipewire and changed only
// through Exec (LUXSHELL_DRYRUN=1 logs). Keys: sound* (limit, click).
// While the page shows (or a search lists its rows) it binds the devices and app streams
// (PwObjectTracker) and reads the cards; the input meter runs only while its row exists.
SettingsPage {
    id: page

    pageId: "sound"
    group: "system"
    title: "Sound"
    subtitle: "Output and input devices, volume per app and system sounds."
    icon: 0xF057E // md-volume-high

    readonly property bool live: SettingsApp.open && (SettingsApp.page === pageId || SettingsApp.query.trim() !== "")

    PwObjectTracker {
        objects: page.live ? Mixer.tracked.concat(Mixer.sources) : []
    }
    // profiles change outside luxshell rarely (pavucontrol, plugging in): slowly while shown,
    // at once when sinks or sources come or go (a profile switch does that)
    Timer {
        running: page.live
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: AudioCards.refresh()
    }
    Connections {
        target: Mixer
        function onSinksChanged() {
            if (page.live)
                AudioCards.refresh();
        }
        function onSourcesChanged() {
            if (page.live)
                AudioCards.refresh();
        }
    }

    Component {
        id: deviceList
        DeviceList {}
    }
    Component {
        id: volumeSlider
        VolumeSlider {}
    }
    Component {
        id: levelMeter
        LevelMeter {}
    }
    Component {
        id: appVolumes
        AppVolumes {}
    }
    Component {
        id: cardList
        CardList {}
    }
    Component {
        id: note
        Note {}
    }

    // ---- output volume + balance (per channel, so a balance survives volume changes) -------------
    readonly property var sink: Audio.sink
    function side(ch: var): int {
        const n = PwAudioChannel.toString(ch);
        return n.includes("Left") ? -1 : n.includes("Right") ? 1 : 0;
    }
    function vols(): var {
        return Array.from(sink?.audio?.volumes ?? []);
    }
    function chans(): var {
        return Array.from(sink?.audio?.channels ?? []);
    }
    function master(): real {
        const v = vols();
        return v.length > 0 ? Math.max(...v) : 0;
    }
    function stereo(): bool {
        const c = chans();
        return c.some(x => side(x) < 0) && c.some(x => side(x) > 0);
    }
    function balance(): real {
        const v = vols(), c = chans();
        let l = 0, r = 0;
        c.forEach((ch, i) => {
            if (side(ch) < 0)
                l = Math.max(l, v[i] ?? 0);
            else if (side(ch) > 0)
                r = Math.max(r, v[i] ?? 0);
        });
        if (l <= 0.0001 && r <= 0.0001 || Math.abs(l - r) < 0.0005)
            return 0;
        return l > r ? -(1 - r / l) : 1 - l / r;
    }
    function spread(m: real, b: real): var {
        return chans().map(ch => {
            const s = side(ch);
            return s < 0 ? m * Math.min(1, 1 - b) : s > 0 ? m * Math.min(1, 1 + b) : m;
        });
    }
    function setMaster(v: real): void {
        if (!sink?.audio)
            return;
        const m = Math.max(0, Math.min(Audio.limit, v));
        const b = balance();
        if (!Exec.allow(`volume ${Mixer.sinkName(sink)} ${Math.round(m * 100)} %`))
            return;
        if (sink.audio.muted && m > 0)
            sink.audio.muted = false;
        if (Math.abs(b) < 0.001 || chans().length < 2)
            sink.audio.volume = m;
        else
            sink.audio.volumes = spread(m, b);
    }
    function setBalance(b: real): void {
        if (!sink?.audio || !stereo())
            return;
        const nb = Math.max(-1, Math.min(1, Math.round(b * 100) / 100));
        if (Exec.allow(`balance ${Mixer.sinkName(sink)} ${balanceText(nb)}`))
            sink.audio.volumes = spread(master(), nb);
    }
    function balanceText(b: real): string {
        const p = Math.round(Math.abs(b) * 100);
        return p === 0 ? "Centre" : b < 0 ? `${p} % left` : `${p} % right`;
    }

    readonly property var limitOptions: [
        {
            "value": 100,
            "label": "100 %",
            "detail": "no boost"
        },
        {
            "value": 125,
            "label": "125 %",
            "detail": ""
        },
        {
            "value": 150,
            "label": "150 %",
            "detail": "may distort"
        }
    ]

    sections: [
        {
            "title": "Output",
            "options": [
                {
                    "id": "soundOutput",
                    "kind": "custom",
                    "label": "",
                    "keywords": "output device speaker speakers headphones headset hdmi displayport monitor default sink playback",
                    "component": deviceList
                },
                {
                    "id": "soundVolume",
                    "kind": "custom",
                    "label": "Volume",
                    "keywords": "output volume loudness level mute speaker",
                    "component": volumeSlider,
                    "enabled": () => Audio.ready,
                    "value": () => page.master(),
                    "set": v => {
                        page.setMaster(v);
                        Audio.feedback();
                    },
                    "max": () => Math.max(Audio.limit, Math.min(1.5, page.master())),
                    "muted": () => Audio.muted,
                    "toggleMute": () => Mixer.toggleMute(Audio.sink),
                    "glyph": m => m ? 0xF0581 : 0xF057E // md-volume-off | md-volume-high
                },
                {
                    "id": "soundBalance",
                    "kind": "slider",
                    "label": "Balance",
                    "keywords": "balance left right stereo channel pan",
                    "min": -1,
                    "max": 1,
                    "step": 0.05,
                    "enabled": () => Audio.ready && page.stereo(),
                    "value": () => page.balance(),
                    "set": b => page.setBalance(b),
                    "format": b => page.balanceText(b),
                    "modified": () => Math.abs(page.balance()) > 0.005,
                    "reset": () => page.setBalance(0),
                    "defaultValue": () => 0
                },
                {
                    "id": "soundMaxVolume",
                    "kind": "choice",
                    "key": "soundMaxVolume",
                    "label": "Volume limit",
                    "keywords": "maximum max volume limit boost over amplification 100 150 louder",
                    "options": () => page.limitOptions
                },
                {
                    "id": "soundLimitNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "volume limit boost scroll osd",
                    "text": "Scrolling on the bar's volume and the volume popup stop at the limit, and so does the slider above. Above 100 % Pipewire amplifies in software: loud passages can distort."
                }
            ]
        },
        {
            "title": "Input",
            "options": [
                {
                    "id": "soundInput",
                    "kind": "custom",
                    "label": "",
                    "input": true,
                    "keywords": "input device microphone mic headset webcam default source recording",
                    "component": deviceList
                },
                {
                    "id": "soundInputVolume",
                    "kind": "custom",
                    "label": "Input volume",
                    "keywords": "input microphone mic volume gain level mute",
                    "component": volumeSlider,
                    "enabled": () => Mic.ready,
                    "value": () => Mic.volume,
                    "set": v => Mic.setVolume(v),
                    "max": () => 1,
                    "muted": () => Mic.muted,
                    "toggleMute": () => Mic.toggleMute(),
                    "glyph": m => m ? 0xF036D : 0xF036C // md-microphone-off | md-microphone
                },
                {
                    "id": "soundInputLevel",
                    "kind": "custom",
                    "label": "",
                    "title": "Input level",
                    "keywords": "input level meter microphone mic test peak live recording",
                    "component": levelMeter
                }
            ]
        },
        {
            "title": "Applications",
            "options": [
                {
                    "id": "soundApps",
                    "kind": "custom",
                    "label": "",
                    "keywords": "app application volume mixer per app stream playing mute",
                    "component": appVolumes
                }
            ]
        },
        {
            "title": "System sounds",
            "options": [
                {
                    "id": "soundFeedback",
                    "kind": "switch",
                    "key": "soundFeedback",
                    "label": "Click when the volume changes",
                    "keywords": "volume feedback sound click beep tick system sound scroll"
                },
                {
                    "id": "soundFeedbackTest",
                    "kind": "button",
                    "label": "Volume click",
                    "keywords": "volume feedback sound test play",
                    "value": () => Audio.feedbackFile.split("/").pop(),
                    "action": "Play",
                    "run": () => Audio.playFeedback()
                },
                {
                    "id": "soundNotif",
                    "kind": "link",
                    "label": "Notification sound",
                    "keywords": "notification sound chime message ding",
                    "value": () => Settings.notifSound ? "On" : "Off",
                    "run": () => SettingsApp.navigate("notifications")
                }
            ]
        },
        {
            "title": "Sound cards",
            "options": [
                {
                    "id": "soundCards",
                    "kind": "custom",
                    "label": "",
                    "keywords": "sound card profile hdmi analog digital stereo surround 5.1 7.1 iec958 pro audio off pactl",
                    "component": cardList
                }
            ]
        }
    ]
}
