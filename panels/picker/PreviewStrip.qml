import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Bottom left of the theme picker: the collapsed island's workspace capsules and clock,
// in the theme being previewed. While the picker is open the bar itself is hidden, so
// this is where the accent shows on the workspaces before Enter (ref/15). Colours
// cross-fade when the highlighted theme changes.
Row {
    id: root

    property string screen: ""
    readonly property var c: Theme.collapsed
    readonly property var shellScreen: Quickshell.screens.find(s => s.name === root.screen) ?? null
    readonly property int active: Hypr.activeFor(shellScreen)

    spacing: 14
    height: c.activeHeight

    Row {
        height: root.height
        spacing: root.c.pillStep - root.c.pillWidth

        Repeater {
            model: Hypr.count

            Rectangle {
                required property int index
                readonly property bool on: index + 1 === root.active
                y: (root.height - height) / 2
                width: on ? root.c.activeWidth : root.c.pillWidth
                height: on ? root.c.activeHeight : root.c.pillHeight
                radius: width / 2
                color: on ? Theme.accent : Hypr.occupied(index + 1) ? Theme.wsOccupied : Theme.wsEmpty
                Behavior on color {
                    ColorAnimation {
                        duration: Motion.ms(Theme.picker.tint)
                    }
                }
            }
        }
    }

    Txt {
        y: (root.height - height) / 2
        text: Clock.time
        color: Theme.text
        font.pixelSize: Theme.picker.metaSize
        font.weight: Font.Medium
        Behavior on color {
            ColorAnimation {
                duration: Motion.ms(Theme.picker.tint)
            }
        }
    }
}
