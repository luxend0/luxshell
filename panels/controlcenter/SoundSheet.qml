import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Sound sheet: switch = mute of the default output, output volume, output
// device (Use), volume per app (Pipewire playback streams). Space / Enter on a
// slider mutes that output or app.
// withInput (bar menu "sheet-sound", panels/SheetMenu): an input part after the output
// devices: default microphone level (services/Mic; "• <app>" while an app records) and the
// microphones (Use). inputSection / inputSlider: where the menu scrolls and selects when the
// microphone widget opens it ("sheet-sound-input").
SheetPage {
    id: page

    property bool withInput: false
    readonly property Item inputSection: inputPart
    readonly property Item inputSlider: inputLevel

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
    PwObjectTracker {
        objects: page.withInput ? Mixer.sources : []
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
        id: inputPart
        caption: "Input"
        visible: page.withInput
        status: Mic.recording ? Mic.recorders.join(", ") : ""
        dotOn: Theme.danger
        showHint: !Mic.ready
        hint: "No microphone"

        SliderRow {
            id: inputLevel
            label: Mixer.sinkName(Mic.source)
            valueText: page.percent(Mic.source?.audio)
            value: Mic.volume
            trackIcon: Mic.icon
            sliderEnabled: Mic.ready
            onMoved: v => Mic.setVolume(v)
            onSecondary: Mic.toggleMute()
        }
    }

    SheetSection {
        caption: "Microphones"
        visible: page.withInput && Mixer.sources.length > 0
        Repeater {
            model: Mixer.sources
            SheetRow {
                required property var modelData
                readonly property bool isDefault: modelData === Mic.source
                icon: Mixer.sourceIcon(modelData)
                name: Mixer.sinkName(modelData)
                sub: isDefault ? "In use" : "Available"
                on: isDefault
                button: isDefault ? "" : "Use"
                trailingIcon: isDefault ? "check" : ""
                onActivated: if (!isDefault)
                    Mixer.setDefaultSource(modelData)
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
