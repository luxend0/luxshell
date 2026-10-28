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

    // ---- live activities (OSD, notifications) ---------------------------------
    // OSD measured 1:1 from ref/10-volume-osd.png (2560x1440): island 376 x 60, bottom
    // radius ~30; speaker glyph 18 px at x 17, slider x 53..298 (8 px), "100%" 15 px
    // right-aligned 16 px from the edge, centre line y 30. Activities without a value
    // (mic muted, layout, caps lock) use the same bar: label where the slider starts,
    // detail where the percentage sits; long labels widen it up to maxWidth.
    readonly property QtObject osd: QtObject {
        readonly property int width: 376
        readonly property int maxWidth: 520
        readonly property int height: 60
        readonly property int radius: 30
        readonly property real centerY: 30
        readonly property real padLeft: 17
        readonly property real iconSize: 18
        readonly property real sliderX: 53
        readonly property real sliderWidth: 245
        readonly property real sliderHeight: 8
        readonly property real padRight: 16
        readonly property real valueSize: 15
        readonly property real labelSize: 15
        readonly property real gap: 22             // slider/label -> value/detail
        readonly property int valueMove: 160       // slider follows a new value
        readonly property int swapOut: 90          // content dip when the activity changes
        readonly property int swapIn: 180
        readonly property color valueColor: root.mix(root.island, root.text, 0.5)
        readonly property color track: root.mix(root.island, root.text, 0.16)
        readonly property color dimFill: root.mix(root.island, root.text, 0.38) // muted sink
    }

    // Notification peek: lives IN the collapsed bar (same height), grows a little in
    // width: app icon left, title next to it; long titles scroll once (marquee).
    readonly property QtObject peek: QtObject {
        readonly property int height: 42
        readonly property int radius: 20
        readonly property int minWidth: 340
        readonly property int maxWidth: 460
        readonly property real padLeft: 15
        readonly property real padRight: 22
        readonly property real iconSize: 22
        readonly property real gap: 10
        readonly property real titleSize: 16
        readonly property real badgeSize: 14
        readonly property real badgeTextSize: 10
        readonly property int marqueeDelay: 900
        readonly property real marqueeSpeed: 0.045  // px per ms
        readonly property int enter: 320            // icon pop + title slide
        readonly property real dismissDrag: 22      // px up that dismisses the peek
    }

    // Full notification card (hover / click on the peek).
    readonly property QtObject card: QtObject {
        readonly property int width: 520
        readonly property int maxHeight: 460
        readonly property int radius: 32
        readonly property real pad: 22
        readonly property real iconSize: 24
        readonly property real appSize: 14
        readonly property real titleSize: 17
        readonly property real bodySize: 15
        readonly property int bodyLines: 4
        readonly property real imageSize: 52
        readonly property real actionHeight: 34
        readonly property real actionSize: 14
        readonly property real rowSize: 14         // older notifications of the same app
        readonly property int groupRows: 3
        readonly property int expand: 260          // compact <-> card content cross-fade
        readonly property real dismissDrag: 70
        readonly property color action: root.mix(root.island, root.text, 0.12)
        readonly property color actionHover: root.mix(root.island, root.text, 0.2)
        readonly property color separator: root.mix(root.island, root.text, 0.1)
    }
}
