pragma Singleton
import QtQuick
import Quickshell

// Single source for colours, type, secondary motion and island geometry.
// Colours: semantic roles over the active palette (Themes.qml, choice in Settings).
// Geometry: pixels at scale 1, measured 1:1 from ref/*.png (2560x1440).
// Motion: the island morph and its content fades live in Motion.qml (fitted to the
// video); everything else uses ONE curve here (widgets/Anim), only durations differ.
Singleton {
    id: root

    // ---- colours ---------------------------------------------------------
    readonly property string name: Themes.resolve(Settings.theme)
    readonly property var pal: Themes.palettes[name]

    readonly property color island: pal.island
    readonly property color surface: pal.surface
    readonly property color surfaceHigh: pal.surfaceHigh
    readonly property color text: pal.text
    readonly property color textSecondary: pal.textSecondary
    readonly property color textDim: pal.textDim
    readonly property color muted: pal.muted
    readonly property color accent: Settings.accent !== "" ? Settings.accent : pal.accent
    readonly property color onAccent: pal.onAccent
    readonly property color wsOccupied: pal.wsOccupied
    readonly property color wsEmpty: pal.wsEmpty
    readonly property color danger: "#e5484d"
    readonly property var swatches: pal.swatches

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // ---- type ------------------------------------------------------------
    readonly property string fontFamily: "Inter"

    // ---- secondary motion (widgets/Anim) ----------------------------------
    readonly property var curve: [0.33, 1.0, 0.68, 1.0, 1.0, 1.0] // easeOutCubic
    readonly property int duration: 450
    readonly property int fadeIn: 260        // small state changes (active workspace)
    readonly property int fadeOut: 140       // hover discs
    readonly property int hoverHold: 160     // pointer may leave this long before collapsing

    // ---- island ----------------------------------------------------------
    // the layer surface is sized from the hover size and the largest panel
    // (Panels.maxWidth/maxHeight), see island/IslandWindow.qml
    readonly property int earRadius: 8       // concave fillets where the island meets the screen edge
    readonly property int panelRadius: 32

    readonly property QtObject collapsed: QtObject {
        readonly property int width: 316
        readonly property int height: 42
        readonly property int radius: 20
        readonly property real padLeft: 32
        readonly property real padRight: 32
        readonly property real centerY: 20       // content line (slightly above geometric centre)
        readonly property real clockSize: 21
        readonly property real pillWidth: 8
        readonly property real pillHeight: 14
        readonly property real activeWidth: 12
        readonly property real activeHeight: 19
        readonly property real pillStep: 14.5
        readonly property real barWidth: 4
        readonly property real barGap: 2
        readonly property real barHeight: 15.5
        readonly property real volumeSize: 20
        readonly property real statusY: 20      // signal + volume line
        readonly property real statusGap: 8
        readonly property real statusOpacity: 1
    }

    readonly property QtObject hover: QtObject {
        readonly property int width: 958
        readonly property int height: 100
        readonly property int radius: 40
        readonly property real padLeft: 45
        readonly property real padRight: 45
        readonly property real row1Y: 32
        readonly property real row2Y: 66
        readonly property real clockY: 48
        readonly property real clockSize: 30
        readonly property real dateSize: 19
        readonly property real dateGap: 12
        readonly property real titleSize: 18
        readonly property real titleMaxWidth: 300
        readonly property real appIconSize: 22
        readonly property real appIconGap: 11
        readonly property real notifSize: 18
        readonly property real bellSize: 20
        readonly property real pillWidth: 12
        readonly property real pillHeight: 21
        readonly property real activeWidth: 16
        readonly property real activeHeight: 27
        readonly property real pillStep: 19.75
        readonly property real barWidth: 5
        readonly property real barGap: 2
        readonly property real barHeight: 20
        readonly property real volumeSize: 24
        readonly property real statusY: 67
        readonly property real statusGap: 12
        readonly property real statusOpacity: 0.7
        readonly property real trayIconSize: 18
        readonly property real trayGap: 18
        readonly property real systemIconSize: 18
        readonly property real systemGap: 22
        // where the hover-only top row starts while the island is still collapsed
        // (it rides the island edge, ref/03: icons sit close to the corners mid-morph)
        readonly property real topStartLeft: 24
        readonly property real topStartRight: 30
        readonly property real topStartY: 14
    }

    // ---- launcher (ref/16 frame 1, measured 1:1 at 2560x1440) -------------------
    // Same width as the control center, so launcher <-> control center only morphs the height.
    readonly property QtObject launcher: QtObject {
        readonly property int width: 686
        readonly property int headerHeight: 80     // search row; 1 px separator on its last line
        readonly property real centerY: 41         // lens + text line
        readonly property real lensX: 22
        readonly property real lensSize: 20
        readonly property real inputX: 60
        readonly property real inputSize: 18
        readonly property real modeSize: 15        // dim mode name at the right of the field
        readonly property real inset: 20           // separator + rows, left and right
        readonly property int listTop: 96
        readonly property int padBottom: 22
        readonly property int rowHeight: 62
        readonly property int visibleRows: 6
        readonly property real rowRadius: 10
        readonly property real barX: 2             // selection bar inside the highlight
        readonly property real barWidth: 3
        readonly property real barHeight: 30
        readonly property real tileX: 16           // icon tile behind every icon
        readonly property real tileSize: 44
        readonly property real tileRadius: 10
        readonly property real iconSize: 28
        readonly property real glyphSize: 22       // Lucide glyph when a row has no app icon
        readonly property real textX: 74
        readonly property real titleSize: 19
        readonly property real subtitleSize: 15
        readonly property real titleBaseline: 27   // from the row top
        readonly property real subtitleBaseline: 47
        readonly property int highlightMove: 160
        readonly property int stagger: 22          // ms between rows while the panel opens
        readonly property real revealShift: 10     // px rows rise while they fade in
        readonly property color highlight: root.mix(root.island, root.text, 0.105)
        readonly property color separator: root.mix(root.island, root.text, 0.1)
        readonly property color tile: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.065)
    }

    // ---- theme + wallpaper picker (ref/05, ref/06, measured 1:1 at 2560x1440) ----------
    // Shared text lines and carousel motion. The carousel position follows the selection
    // with one soft ease-out; every card reads its signed distance d to that position,
    // so scale, dimming, lift and the selection frame all interpolate while it moves.
    readonly property QtObject picker: QtObject {
        readonly property real inset: 21           // text left/right
        readonly property real headerY: 38         // header line centre (search field / title)
        readonly property real lensX: 22
        readonly property real lensSize: 18
        readonly property real inputX: 57
        readonly property real inputSize: 18
        readonly property real titleSize: 22       // "Wallpaper"
        readonly property real metaSize: 15        // counter, "Enter to apply", file name, card labels
        readonly property real metaGap: 12         // "6/10 · Enter to apply"
        readonly property real frame: 2.5          // selection frame
        readonly property int settle: 420          // carousel ease to the selection (ms)
        readonly property var curve: [0.22, 1.0, 0.36, 1.0, 1, 1] // soft ease-out, no overshoot
        readonly property int tint: 220            // colour cross-fade while the live preview changes theme
        readonly property real wheelStep: 120      // one card per wheel notch
    }

    readonly property QtObject themePicker: QtObject {
        readonly property int width: 1076
        readonly property int height: 297
        readonly property real clipInset: 23       // carousel window, left and right
        readonly property real stripY: 70          // carousel top
        readonly property real stripHeight: 170
        readonly property real cardTop: 22         // resting card top inside the strip (y 92)
        readonly property real cardWidth: 247
        readonly property real cardHeight: 128
        readonly property real step: 259
        readonly property real cardRadius: 13
        readonly property real lift: 10            // the selected card rises (ref/05)
        readonly property real shrink: 0.03        // per step away, at most two steps
        readonly property real dim: 0.34           // black over neighbours, per step (max 1.5 steps)
        readonly property real dotSize: 17
        readonly property real dotStep: 24
        readonly property real dotsY: 54           // dot centres from the card top
        readonly property real labelY: 107         // label centre from the card top
        readonly property real appliedSize: 7      // "current theme" dot (ref/15)
        readonly property real appliedX: 19        // from the right edge
        readonly property real appliedY: 14
        readonly property real footerY: 266
    }

    readonly property QtObject wallpaperPicker: QtObject {
        readonly property int width: 1351
        readonly property int height: 308
        readonly property real stripY: 70
        readonly property real stripHeight: 182    // thumbnails centred on y 161
        readonly property real thumbWidth: 249
        readonly property real thumbHeight: 150
        readonly property real step: 261
        readonly property real radius: 13
        readonly property real shrink: 0.1         // ref/06: 1, .9, .8
        readonly property real dim: 0.2            // black per step away
        readonly property real maxDim: 0.55
        readonly property real currentSize: 10     // "current wallpaper" dot
        readonly property real currentInset: 14
        readonly property real footerY: 278
        readonly property int thumbW: 500          // cached thumbnail, 2x the card
        readonly property int thumbH: 300
    }
}
