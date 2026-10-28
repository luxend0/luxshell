import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Sound sheet: switch = mute of the default output, output volume, output
// device (Use), volume per app (Pipewire playback streams). Space / Enter on a
// slider mutes that output or app.
SheetPage {
    id: page

    title: "Sound"
    hasSwitch: Audio.ready
    switchOn: Audio.ready && !Audio.muted
    onToggled: Mixer.toggleMute(Audio.sink)

    function percent(audio): string {
        return !audio ? "" : audio.muted ? "Muted" : `${Math.round(audio.volume * 100)} %`;
    }

    // binds sinks + playback streams while the sheet is open (fills their properties)
    PwObjectTracker {
        objects: Mixer.tracked
    }

    SheetSection {
        caption: "Output"
        showHint: !Audio.ready
        hint: "No output device"

        SliderRow {
            label: Mixer.sinkName(Audio.sink)
            valueText: page.percent(Audio.sink?.audio)
            value: Audio.volume
            trackIcon: Audio.icon
            sliderEnabled: Audio.ready
            onMoved: v => Mixer.setVolume(Audio.sink, v)
            onSecondary: Mixer.toggleMute(Audio.sink)
        }
    }

    SheetSection {
        caption: "Devices"
        visible: Mixer.sinks.length > 0
        Repeater {
            model: Mixer.sinks
            SheetRow {
                required property var modelData
                readonly property bool isDefault: modelData === Audio.sink
                icon: Mixer.sinkIcon(modelData)
                name: Mixer.sinkName(modelData)
                sub: isDefault ? "In use" : "Available"
                on: isDefault
                button: isDefault ? "" : "Use"
                trailingIcon: isDefault ? "check" : ""
                onActivated: if (!isDefault)
                    Mixer.setDefault(modelData)
            }
        }
    }

    SheetSection {
        caption: "Applications"
        showHint: Mixer.streams.length === 0
        hint: "No apps playing"
        Repeater {
            model: Mixer.streams
            SliderRow {
                required property var modelData
                label: Mixer.appName(modelData)
                valueText: page.percent(modelData.audio)
                iconSource: Mixer.appIcon(modelData)
                glyph: "music"
                value: modelData.audio?.volume ?? 0
                trackIcon: modelData.audio?.muted ? "volume-x" : "volume-2"
                onMoved: v => Mixer.setVolume(modelData, v)
                onSecondary: Mixer.toggleMute(modelData)
            }
        }
    }
}
