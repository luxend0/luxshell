import QtQuick
import qs.config
import qs.services
import qs.widgets

// Bottom group of ref/11: avatar disc, user name, and below it either the hint
// ("Press Any Key to Enter Password") or the password pill. Positions count from the
// bottom edge (Theme.lock); fills the surface.
Item {
    id: root

    readonly property QtObject g: Theme.lock
    readonly property bool entering: Lock.phase !== "idle"

    Avatar {
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.g.avatarCenter - height / 2)
        size: root.g.avatarSize
    }

    Text {
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.g.nameBaseline - baselineOffset)
        text: Lock.user
        color: root.g.fg(root.g.nameAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.nameSize
        font.weight: root.g.nameWeight
        font.letterSpacing: root.g.nameSpacing
    }

    Text {
        id: hint
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.g.hintBaseline - baselineOffset)
        text: "Press Any Key to Enter Password"
        color: root.g.fg(root.g.hintAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.hintSize
        font.weight: root.g.hintWeight
        font.letterSpacing: root.g.hintSpacing
        opacity: root.entering ? 0 : 1
        Behavior on opacity {
            Anim {
                ms: root.g.pillIn * 0.7
            }
        }
    }

    PasswordPill {
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.g.pillCenter - height / 2)
        shown: root.entering
    }

    // caps lock / PAM message under the pill
    Text {
        readonly property string note: Lock.message !== "" ? Lock.message : Lock.caps ? "Caps Lock is on" : ""
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.g.noteBaseline - baselineOffset)
        text: note
        color: root.g.fg(root.g.hintAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.noteSize
        font.weight: Font.Medium
        opacity: root.entering && note !== "" ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: root.g.pillIn
            }
        }
    }
}
