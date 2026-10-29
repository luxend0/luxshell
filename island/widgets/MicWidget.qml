import QtQuick
import qs.config
import qs.core
import qs.services

// Default microphone (services/Mic): mic / mic-off, red (Theme.menus.recording = the power
// red) while an app records (Pipewire capture stream fed by a microphone,
// Settings.islandMicRecording), optional input level (Settings.islandMicPercent).
// Click = mute / unmute (through Exec), right click = sound menu on its input part
// (panel "sheet-sound-input").
BarToggle {
    id: root

    readonly property bool red: Settings.islandMicRecording && Mic.recording

    icon: Mic.icon
    color: red ? Theme.menus.recording : Mic.ready ? Theme.text : Theme.menus.off
    text: Settings.islandMicPercent && Mic.ready ? (Mic.muted ? "Off" : `${Math.round(Mic.volume * 100)}%`) : ""
    onClicked: Mic.toggleMute()
    onRightClicked: Ui.open("sheet-sound-input", root.screen ? root.screen.name : undefined)
}
