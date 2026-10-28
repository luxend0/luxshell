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

    // ---- control center (ref/08, ref/09, ref/09c; measured 1:1 at 2560x1440) ----------
    // Main page: panel 686x686, cards 648 wide. Sub pages (network, Bluetooth, sound,
    // display) are sheets over the dimmed main page, morphing out of the control
    // that opened them (panels/ControlCenter.qml).
    readonly property QtObject cc: QtObject {
        readonly property int width: 686
        readonly property int height: 686
        readonly property int radius: 38         // panel bottom corners
        readonly property int pad: 19            // panel edge -> cards, all four sides
        readonly property int gapX: 14           // tile | tile | round
        readonly property int gapY: 15           // between rows / cards
        readonly property int row: 80            // tile, round button, slider card height
        readonly property int tileWidth: 270     // row 1: Wi-Fi | Focus | lock
        readonly property int wideTile: 317      // row 2: Bluetooth | Game Mode share the full width
        readonly property int disc: 56           // icon disc inside a tile, centred in an 80 square
        readonly property int textX: 84          // tile left -> title / subtitle
        readonly property int titleY: 30         // cap centres inside a tile
        readonly property int subY: 51
        readonly property int titleSize: 19
        readonly property int subSize: 15
        readonly property int iconSize: 20
        readonly property int cardRadius: 28
        readonly property int labelX: 20         // "Sound", "Display", "Notifications"
        readonly property int labelY: 20
        readonly property int labelSize: 17
        readonly property int captionSize: 15    // "Notifications"
        readonly property int bodySize: 17       // "No notifications"
        readonly property int trackX: 15
        readonly property int trackY: 37
        readonly property int trackHeight: 32
        readonly property int trackIconX: 26     // icon centre from the track's left end
        readonly property int chip: 32           // chevron disc, top right of a slider card
        readonly property int chipY: 3
        readonly property color stroke: root.mix(root.surface, root.surfaceHigh, 0.3)   // 1px card outline
        readonly property color hover: root.mix(root.surface, root.surfaceHigh, 0.28)
        readonly property color track: Qt.darker(root.surface, 2.2)                      // empty slider track
        readonly property color chipColor: root.mix(root.surface, root.surfaceHigh, 0.67)

        // sheet (ref/09 + ref/09c): coordinates relative to the sheet, sizes in px
        readonly property QtObject sheet: QtObject {
            readonly property int inset: 29          // panel edge -> sheet, left and right
            readonly property int radius: 30
            readonly property int maxHeight: 628     // panel height - 2 * inset; taller content scrolls
            readonly property real dim: 0.55         // black over the main page while a sheet is open
            readonly property int headerHeight: 75   // header block (back, title, switch)
            readonly property real headerY: 44       // back disc, title and switch centre
            readonly property int backX: 20
            readonly property int backSize: 34
            readonly property int titleX: 70
            readonly property int titleSize: 22
            readonly property int switchWidth: 58
            readonly property int switchHeight: 30
            readonly property int switchRight: 19
            readonly property int knob: 24
            readonly property int captionX: 21
            readonly property real captionY: 26      // section top -> caption cap centre
            readonly property int captionGap: 52     // section top -> first row
            readonly property int captionSize: 15
            readonly property int statusRight: 23    // "• Scanning" right edge -> sheet edge
            readonly property int statusSize: 15
            readonly property int dot: 7
            readonly property int rowX: 20
            readonly property int rowHeight: 65
            readonly property int rowGap: 6
            readonly property int rowRadius: 16
            readonly property int discX: 10
            readonly property int disc: 44
            readonly property int discIcon: 18
            readonly property int nameX: 71
            readonly property real nameY: 22
            readonly property int nameSize: 18
            readonly property int subX: 70
            readonly property real subY: 42.5
            readonly property int subSize: 15
            readonly property int pillHeight: 36
            readonly property int pillRight: 8
            readonly property real pillPad: 17.5
            readonly property int pillSize: 15
            readonly property int hintX: 20
            readonly property int hintHeight: 27
            readonly property real hintY: 10.5
            readonly property int hintSize: 17
            readonly property int padBottom: 17
            readonly property int sliderRow: 78      // label line + track (sound, apps, displays)
            // open: dim leads, the sheet grows out of its tile; close mirrors it
            readonly property int dimMs: 300
            readonly property int openDelay: 30
            readonly property int openMs: 340
            readonly property int closeMs: 260
            readonly property int resizeMs: 240
            readonly property color rowColor: root.mix(root.surface, root.surfaceHigh, 0.625)      // #1a1a1a
            readonly property color rowHover: root.mix(root.surface, root.surfaceHigh, 0.8)
            readonly property color discColor: root.mix(root.surfaceHigh, root.text, 0.065)       // #303030
            readonly property color pillColor: root.mix(root.surfaceHigh, root.text, 0.03)        // #292929
            readonly property color captionColor: root.mix(root.textDim, root.surface, 0.3)        // "Saved", "Nearby"
            readonly property color subColor: root.mix(root.textDim, root.surface, 0.27)           // "Saved" under a name
            readonly property color hintColor: root.mix(root.textDim, root.surface, 0.13)          // "Looking for devices..."
            readonly property color textColor: root.mix(root.text, root.surface, 0.12)             // title, names (video: ~#d0d0d0)
        }
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

    // ---- workspace overview (Expose; no video frame, drawn in the style of ref/04-06) ----
    // Every open window as a live preview card, grouped by workspace (small number + hairline
    // above each group). Groups sit side by side and wrap into rows at maxCols cards; the
    // panel grows with the window count up to maxCols x maxLines, taller content scrolls.
    // Header and footer lines are the pickers' (Theme.picker): search left, counter right,
    // "Enter to focus" bottom right.
    readonly property QtObject overview: QtObject {
        readonly property int minWidth: 686        // = launcher / control center (header fits)
        readonly property real pad: 24             // panel edge -> cards, left and right
        readonly property real headerY: 38         // search line centre (picker header)
        readonly property real lensX: 24
        readonly property real inputX: 57
        readonly property int gridTop: 74          // first group heading line
        readonly property int headingHeight: 30    // heading line above a group's cards
        readonly property real headingY: 9         // heading text centre inside that line
        readonly property real headingSize: 15
        readonly property real ruleGap: 12         // number -> hairline
        readonly property int cardWidth: 288
        readonly property int thumbHeight: 180     // preview box (16:10), window fitted inside
        readonly property int labelHeight: 42      // icon + title under the preview
        readonly property real labelY: 21          // label centre below the preview
        readonly property int colGap: 16           // cards side by side
        readonly property int lineGap: 14          // card lines inside one group
        readonly property int groupGap: 40         // groups side by side
        readonly property int rowGap: 24           // rows of groups
        readonly property int maxCols: 5
        readonly property int maxLines: 3          // visible card lines before scrolling
        readonly property real edgeFade: 36        // grid edge fades out while more cards are off view
        readonly property int footerHeight: 54
        readonly property real footerY: 27         // footer line centre from the panel bottom
        readonly property real cardRadius: 13
        readonly property real frame: 2.5          // selection frame (= picker)
        readonly property real dim: 0.36           // black over every card but the selected one
        readonly property real shrink: 0.035       // unselected cards are this much smaller
        readonly property real iconSize: 18
        readonly property real titleSize: 15
        readonly property real placeholderIcon: 52 // app icon while the preview has no frame yet
        readonly property real dotSize: 8          // focused window (like the applied-wallpaper dot)
        readonly property real dotInset: 13
        readonly property real closeSize: 26       // close disc, top right of a hovered card
        readonly property real closeInset: 8
        readonly property int select: 170          // frame / dim / scale follow the selection
        readonly property int relayout: 380        // cards slide to new slots (= island panel morph, emphasized)
        readonly property int stagger: 16          // ms between cards while the panel opens
        readonly property int reveal: 280
        readonly property real revealShift: 14
        readonly property color box: root.mix(root.surface, root.surfaceHigh, 0.45)
        readonly property color rule: root.mix(root.island, root.text, 0.1)
        readonly property color closeDisc: root.mix(root.island, root.surfaceHigh, 0.85)
    }

    // ---- media (services/Media, island/bar/MediaLabel, panels/MediaPanel) ------------------
    // Collapsed island: unchanged (video). Hover: the chip replaces the window title in row 1
    // while a player has a track (same slot, same type as the title). Click on the chip opens
    // the media panel; it shares width and radius with the control center and the launcher.
    readonly property QtObject media: QtObject {
        // hover chip
        readonly property real chipCover: 24
        readonly property real chipCoverRadius: 6
        readonly property real chipGap: 11          // cover -> title, like icon -> window title
        readonly property real chipArtistGap: 9     // title -> artist on one line
        readonly property real chipMaxWidth: 296     // ends ~40 px before the clock group (hover)
        readonly property real chipButton: 26        // play/pause disc (prev/next join on chip hover)
        readonly property real chipGlyph: 12
        readonly property real chipButtonsGap: 8
        readonly property real chipPad: 8            // highlight around the chip on hover
        readonly property int swap: 260              // window title <-> chip cross-fade
        readonly property int reveal: 200            // prev/next on chip hover

        // panel (686 x 236, radius as the control center)
        readonly property int width: 686
        readonly property int height: 236
        readonly property int emptyHeight: 128
        readonly property int radius: 38
        readonly property real pad: 24
        readonly property real cover: 188
        readonly property real coverRadius: 20
        readonly property real columnGap: 28
        readonly property real pillHeight: 28
        readonly property real pillIcon: 16
        readonly property real pillSize: 14
        readonly property real pillPad: 11
        readonly property real titleY: 78            // cap centres from the panel top
        readonly property real artistY: 106
        readonly property real titleSize: 24
        readonly property real artistSize: 17
        readonly property real trackY: 136           // seek track centre
        readonly property real trackHeight: 6
        readonly property real trackHover: 10
        readonly property real timeY: 156
        readonly property real timeSize: 13
        readonly property real controlsY: 190        // centre of the transport row
        readonly property real playDisc: 52
        readonly property real playGlyph: 20
        readonly property real skipDisc: 42
        readonly property real skipGlyph: 20
        readonly property real skipGap: 14
        readonly property real volumeWidth: 120
        readonly property real volumeIcon: 18
        readonly property int coverFade: 320         // cover cross-fade on a new track
        readonly property int enter: 420             // cover settles while the panel opens
        // glow: a blurred copy of the cover behind it, plus a faint wash over the panel.
        // Both are darkened (brightness shift), so bright covers glow moderately and dark
        // ones barely: the island stays black at its edges.
        readonly property real glowSpread: 1.42      // halo size / cover size
        readonly property real glowOpacity: 0.55
        readonly property real glowBrightness: -0.12
        readonly property real washSpread: 1.0       // wash size / panel width
        readonly property real washOpacity: 0.22
        readonly property real washBrightness: -0.3
        readonly property var glowSaturation: ({ "soft": -0.45, "color": 0, "mono": -1 })
        readonly property color track: root.mix(root.island, root.text, 0.17)
        readonly property color pill: root.mix(root.island, root.text, 0.1)
        readonly property color pillHover: root.mix(root.island, root.text, 0.16)
        readonly property color chipHover: root.mix(root.island, root.text, 0.09)
        readonly property color skipHover: root.mix(root.island, root.text, 0.1)
    }
}
