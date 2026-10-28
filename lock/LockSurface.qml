import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// One lock screen surface (per screen), ref/11: date over a huge clock at the top, avatar,
// user name and "Press Any Key to Enter Password" at the bottom, status glyphs top right,
// all over the blurred, darkened wallpaper.
//
// Any key or a click swaps the hint for the password pill; Enter checks (services/Lock),
// a wrong password shakes the pill empty, Esc drops the input.
//
// Motion: on lock the screen blurs and darkens (from the screenshot of the desktop, the
// wallpaper fades in over it) while the clock group slides down into place; on unlock the
// same runs backwards before the lock is released, so the desktop appears where it blurred.
WlSessionLockSurface {
    id: surface

    readonly property QtObject g: Theme.lock

    color: "black"

    // 0 -> 1 after the surface appears, 1 -> 0 while unlocking
    property real intro: 0
    property real outro: 0
    readonly property real level: intro * (1 - outro)
    // content trails the backdrop a little on the way in
    readonly property real content: Math.max(0, Math.min(1, (intro * g.lockIn - g.contentDelay) / (g.lockIn - g.contentDelay))) * (1 - outro)

    NumberAnimation on intro {
        from: 0
        to: 1
        duration: Motion.ms(surface.g.lockIn)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasized
    }
    NumberAnimation on outro {
        running: Lock.phase === "unlocking"
        to: 1
        duration: Motion.ms(surface.g.unlockOut)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.standard
    }

    Backdrop {
        anchors.fill: parent
        screen: surface.screen
        level: surface.level
    }

    // ---- keyboard + pointer ------------------------------------------------------
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            const ctrl = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
            if (k === Qt.Key_Return || k === Qt.Key_Enter)
                Lock.submit();
            else if (k === Qt.Key_Escape)
                Lock.cancel();
            else if (k === Qt.Key_Backspace)
                Lock.erase(ctrl);
            else if (ctrl && k === Qt.Key_U)
                Lock.erase(true);
            else if (k === Qt.Key_CapsLock) {
                Lock.capsKey();
                Lock.reveal();
            } else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127)
                Lock.type(event.text, (event.modifiers & Qt.ShiftModifier) !== 0);
            else
                Lock.reveal(); // Shift, arrows, F-keys ...: "Press Any Key"
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onPressed: {
                keys.forceActiveFocus();
                Lock.reveal();
            }
        }
    }

    // Measured at 1440 px height; smaller screens get the same layout scaled down.
    Item {
        id: stage
        readonly property real k: surface.height > 0 ? Math.min(1, surface.height / 1440) : 1
        width: surface.width / k
        height: surface.height / k
        scale: k
        transformOrigin: Item.TopLeft

        // ---- date + clock (top) ---------------------------------------------------------
        Item {
            id: top
            width: parent.width
            height: parent.height
            y: -surface.g.rise * (1 - surface.content)
            opacity: surface.content

            Text {
                id: date
                visible: Settings.lockDate // Lock Screen page
                x: Math.round((parent.width - width) / 2)
                y: Math.round(surface.g.dateBaseline - baselineOffset)
                text: Clock.now.toLocaleDateString(Clock.locale, "dddd, MMMM d")
                color: surface.g.fg(surface.g.dateAlpha)
                font.family: surface.g.family
                font.pixelSize: surface.g.dateSize
                font.weight: surface.g.dateWeight
                font.letterSpacing: surface.g.dateSpacing
            }

            Text {
                id: time
                x: Math.round((parent.width - width) / 2)
                y: Math.round(surface.g.clockBaseline - baselineOffset)
                // Lock Screen page: own format, "" = the island's (Clock & Date page)
                text: Clock.formatTime(Clock.now, Settings.lockClockFormat !== "" ? Settings.lockClockFormat : Settings.clockFormat)
                color: surface.g.fg(surface.g.clockAlpha)
                font.family: surface.g.family
                font.pixelSize: surface.g.clockSize
                font.weight: surface.g.clockWeight
                font.letterSpacing: surface.g.clockSpacing
            }
        }

        // ---- user block (bottom) ----------------------------------------------------------
        UserBlock {
            width: parent.width
            height: parent.height
            y: surface.g.rise * 0.6 * (1 - surface.content)
            opacity: surface.content
        }

        StatusIcons {
            anchors.right: parent.right
            anchors.rightMargin: surface.g.statusRight
            y: Math.round(surface.g.statusY - height / 2)
            opacity: surface.content
        }
    }
}
