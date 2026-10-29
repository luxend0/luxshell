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
    readonly property string fontFamily: Settings.fontFamily !== "" ? Settings.fontFamily : "Inter"
    // Settings "Font size" (15 px = 1): scales the settings app's text; modules
    // with sizes measured from the video keep them unless they multiply by it
    readonly property real fontScale: Math.max(0.6, Math.min(1.6, Settings.fontSize / 15)) * textScale
    // Settings "Text size" (lookFontScale): every text size in the blocks below goes through
    // tx(), so island, panels, OSD and lock follow it live (1 = sizes of the video)
    readonly property real textScale: Math.max(0.7, Math.min(1.5, Settings.lookFontScale))
    function tx(px: real): real {
        return px * textScale;
    }
    // monospace text (launcher command/calculator line, hex fields); "" = the interface font
    readonly property string monoFamily: Settings.lookMonoFont !== "" ? Settings.lookMonoFont : fontFamily

    // ---- secondary motion (widgets/Anim) ----------------------------------
    readonly property var curve: [0.33, 1.0, 0.68, 1.0, 1.0, 1.0] // easeOutCubic
    readonly property int duration: 450
    readonly property int fadeIn: 260        // small state changes (active workspace)
    readonly property int fadeOut: 140       // hover discs
    readonly property int hoverHold: Settings.hoverHold // pointer may leave this long before collapsing (default 160)

    // ---- shape (Settings look*, island/IslandShape) ------------------------
    // "Corner radius" (lookRadiusScale): island, panel and card radii in the blocks below go
    // through rad(), so they all follow one factor live (1 = video, 0 = square corners)
    readonly property real radiusScale: Math.max(0, Math.min(2, Settings.lookRadiusScale))
    function rad(px: real): real {
        return px * radiusScale;
    }

    // ---- island ----------------------------------------------------------
    // the layer surface is sized from the hover size and the largest panel
    // (Panels.maxWidth/maxHeight), see island/IslandWindow.qml
    readonly property int earRadius: Settings.lookEars ? 8 : 0 // concave fillets where the island meets the screen edge (Settings.lookEars)
    readonly property int panelRadius: Math.round(root.rad(32))

    readonly property QtObject collapsed: QtObject {
        readonly property int width: 316
        readonly property int height: 42
        readonly property int radius: Math.round(root.rad(20))
        readonly property real padLeft: 32
        readonly property real padRight: 32
        readonly property real centerY: 20       // content line (slightly above geometric centre)
        readonly property real clockSize: root.tx(21)
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
        readonly property int radius: Math.round(root.rad(40))
        readonly property real padLeft: 45
        readonly property real padRight: 45
        readonly property real row1Y: 32
        readonly property real row2Y: 66
        readonly property real clockY: 48
        readonly property real clockSize: root.tx(30)
        readonly property real dateSize: root.tx(19)
        readonly property real dateGap: 12
        readonly property real titleSize: root.tx(18)
        readonly property real titleMaxWidth: 300
        readonly property real appIconSize: 22
        readonly property real appIconGap: 11
        readonly property real notifSize: root.tx(18)
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
        readonly property real inputSize: root.tx(18)
        readonly property real modeSize: root.tx(15)        // dim mode name at the right of the field
        readonly property real inset: 20           // separator + rows, left and right
        readonly property int listTop: 96
        readonly property int padBottom: 22
        readonly property int rowHeight: 62
        readonly property int visibleRows: 6
        readonly property real rowRadius: root.rad(10)
        readonly property real barX: 2             // selection bar inside the highlight
        readonly property real barWidth: 3
        readonly property real barHeight: 30
        readonly property real tileX: 16           // icon tile behind every icon
        readonly property real tileSize: 44
        readonly property real tileRadius: root.rad(10)
        readonly property real iconSize: 28
        readonly property real glyphSize: 22       // Lucide glyph when a row has no app icon
        readonly property real textX: 74
        readonly property real titleSize: root.tx(19)
        readonly property real subtitleSize: root.tx(15)
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
    // Main page: panel 686 wide, cards 648 wide; it ends after the Display slider (the
    // notifications moved to their own panel, Theme.nc), so it is 4 rows high. Sub pages
    // (network, Bluetooth, sound, display) are sheets over the dimmed main page, morphing
    // out of the control that opened them; the panel grows while a sheet needs more room
    // (up to maxHeight) and shrinks back once it closes (panels/ControlCenter.qml).
    readonly property QtObject cc: QtObject {
        readonly property int width: 686
        readonly property int height: 2 * pad + 4 * row + 3 * gapY   // 403: Wi-Fi .. Display
        readonly property int maxHeight: 686     // with a sheet open: sheet.maxHeight + 2 * sheet.inset
        readonly property int radius: Math.round(root.rad(38))         // panel bottom corners
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
        readonly property int titleSize: Math.round(root.tx(19))
        readonly property int subSize: Math.round(root.tx(15))
        readonly property int iconSize: 20
        readonly property int cardRadius: Math.round(root.rad(28))
        readonly property int labelX: 20         // "Sound", "Display"
        readonly property int labelY: 20
        readonly property int labelSize: Math.round(root.tx(17))
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
            readonly property int radius: Math.round(root.rad(30))
            readonly property int maxHeight: 628     // cc.maxHeight - 2 * inset; taller content scrolls
            readonly property real shrinkAt: 0.35    // closing: the panel shrinks back once the sheet is this far home
            readonly property real dim: 0.55         // black over the main page while a sheet is open
            readonly property int headerHeight: 75   // header block (back, title, switch)
            readonly property real headerY: 44       // back disc, title and switch centre
            readonly property int backX: 20
            readonly property int backSize: 34
            readonly property int titleX: 70
            readonly property int titleSize: Math.round(root.tx(22))
            readonly property int switchWidth: 58
            readonly property int switchHeight: 30
            readonly property int switchRight: 19
            readonly property int knob: 24
            readonly property int captionX: 21
            readonly property real captionY: 26      // section top -> caption cap centre
            readonly property int captionGap: 52     // section top -> first row
            readonly property int captionSize: Math.round(root.tx(15))
            readonly property int statusRight: 23    // "• Scanning" right edge -> sheet edge
            readonly property int statusSize: Math.round(root.tx(15))
            readonly property int dot: 7
            readonly property int rowX: 20
            readonly property int rowHeight: 65
            readonly property int rowGap: 6
            readonly property int rowRadius: Math.round(root.rad(16))
            readonly property int discX: 10
            readonly property int disc: 44
            readonly property int discIcon: 18
            readonly property int nameX: 71
            readonly property real nameY: 22
            readonly property int nameSize: Math.round(root.tx(18))
            readonly property int subX: 70
            readonly property real subY: 42.5
            readonly property int subSize: Math.round(root.tx(15))
            readonly property int pillHeight: 36
            readonly property int pillRight: 8
            readonly property real pillPad: 17.5
            readonly property int pillSize: Math.round(root.tx(15))
            readonly property int hintX: 20
            readonly property int hintHeight: 27
            readonly property real hintY: 10.5
            readonly property int hintSize: Math.round(root.tx(17))
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
        readonly property real inputSize: root.tx(18)
        readonly property real titleSize: root.tx(22)       // "Wallpaper"
        readonly property real metaSize: root.tx(15)        // counter, "Enter to apply", file name, card labels
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
        readonly property real cardRadius: root.rad(13)
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
        readonly property real radius: root.rad(13)
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
        readonly property int radius: Math.round(root.rad(30))
        readonly property real centerY: 30
        readonly property real padLeft: 17
        readonly property real iconSize: 18
        readonly property real sliderX: 53
        readonly property real sliderWidth: 245
        readonly property real sliderHeight: 8
        readonly property real padRight: 16
        readonly property real valueSize: root.tx(15)
        readonly property real labelSize: root.tx(15)
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
        readonly property int radius: Math.round(root.rad(20))
        readonly property int minWidth: 340
        readonly property int maxWidth: 460
        readonly property real padLeft: 15
        readonly property real padRight: 22
        readonly property real iconSize: 22
        readonly property real gap: 10
        readonly property real titleSize: root.tx(16)
        readonly property real badgeSize: 14
        readonly property real badgeTextSize: root.tx(10)
        readonly property int marqueeDelay: 900
        readonly property real marqueeSpeed: 0.045  // px per ms
        readonly property int enter: 320            // icon pop + title slide
        readonly property real dismissDrag: 22      // px up that dismisses the peek
    }

    // Full notification card (hover / click on the peek).
    readonly property QtObject card: QtObject {
        readonly property int width: 520
        readonly property int maxHeight: 460
        readonly property int radius: Math.round(root.rad(32))
        readonly property real pad: 22
        readonly property real iconSize: 24
        readonly property real appSize: root.tx(14)
        readonly property real titleSize: root.tx(17)
        readonly property real bodySize: root.tx(15)
        readonly property int bodyLines: 4
        readonly property real imageSize: 52
        readonly property real actionHeight: 34
        readonly property real actionSize: root.tx(14)
        readonly property real rowSize: root.tx(14)         // older notifications of the same app
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
        readonly property real headingSize: root.tx(15)
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
        readonly property real cardRadius: root.rad(13)
        readonly property real frame: 2.5          // selection frame (= picker)
        readonly property real dim: 0.36           // black over every card but the selected one
        readonly property real shrink: 0.035       // unselected cards are this much smaller
        readonly property real iconSize: 18
        readonly property real titleSize: root.tx(15)
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
        readonly property real chipCoverRadius: root.rad(6)
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
        readonly property int radius: Math.round(root.rad(38))
        readonly property real pad: 24
        readonly property real cover: 188
        readonly property real coverRadius: root.rad(20)
        readonly property real columnGap: 28
        readonly property real pillHeight: 28
        readonly property real pillIcon: 16
        readonly property real pillSize: root.tx(14)
        readonly property real pillPad: 11
        readonly property real titleY: 78            // cap centres from the panel top
        readonly property real artistY: 106
        readonly property real titleSize: root.tx(24)
        readonly property real artistSize: root.tx(17)
        readonly property real trackY: 136           // seek track centre
        readonly property real trackHeight: 6
        readonly property real trackHover: 10
        readonly property real timeY: 156
        readonly property real timeSize: root.tx(13)
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

    // ---- lock screen (ref/11, measured 1:1 at 2560x1440) ------------------------
    // Date over a huge clock at the top, user block (avatar, name, hint) at the bottom,
    // status glyphs top right, all over the blurred + darkened wallpaper (lock/*).
    // Text is placed by BASELINE; the user block counts from the BOTTOM edge, so taller
    // screens keep both groups at their edge, lower ones get the whole layout scaled
    // (lock/LockSurface: k = height / 1440). Colours are Theme.text at an alpha
    // (measured over the ~#101010 backdrop), so themes tint the lock screen too.
    readonly property QtObject lock: QtObject {
        function fg(alpha: real): color {
            return Qt.rgba(root.text.r, root.text.g, root.text.b, alpha);
        }
        readonly property string family: root.fontFamily === "Inter" ? "Inter Display" : root.fontFamily // optical size for large type (SF Pro Display in the video); another shell font replaces it
        readonly property real dateSize: 34            // "Sunday, October 25": cap height 24.5, ink 303 wide
        readonly property int dateWeight: Font.Medium
        readonly property real dateSpacing: 0.3
        readonly property real dateBaseline: 198
        readonly property real dateAlpha: 0.84         // ~#c8c8c8
        readonly property real clockSize: 190          // "21:06": digits 142 high, stems 24, ink 446 wide
        readonly property int clockWeight: Font.DemiBold
        readonly property real clockSpacing: -1.2
        readonly property real clockBaseline: 380.5
        readonly property real clockAlpha: 0.86        // ~#cdcdcd
        readonly property real avatarSize: 79          // disc centre 1154 = 286 above the bottom
        readonly property real avatarCenter: 286
        readonly property real avatarFill: 0.15        // white over the backdrop (~#343434)
        readonly property real avatarRing: 0.3
        readonly property real nameSize: root.tx(26)            // "user0": figures 18.5 high, ink 68 wide
        readonly property int nameWeight: Font.DemiBold
        readonly property real nameSpacing: -0.6
        readonly property real nameBaseline: 196       // y 1244
        readonly property real nameAlpha: 0.96
        readonly property real hintSize: root.tx(20)            // "Press Any Key to Enter Password": cap 15, ink 306 wide
        readonly property int hintWeight: Font.DemiBold
        readonly property real hintSpacing: -0.35
        readonly property real hintBaseline: 138       // y 1302
        readonly property real hintAlpha: 0.54         // ~#868686
        // password pill: takes the hint's place once a key is pressed or the screen clicked
        readonly property real pillWidth: 264
        readonly property real pillHeight: 40
        readonly property real pillCenter: 142         // pill centre above the bottom (hint line centre)
        readonly property real pillFill: 0.13
        readonly property real pillStroke: 0.1
        readonly property real pillTextSize: root.tx(17)
        readonly property real dotSize: 9
        readonly property real dotGap: 7
        readonly property real capsSize: 20            // Lucide arrow-big-up at the right end of the pill
        readonly property real noteSize: root.tx(16)            // caps lock / PAM message under the pill
        readonly property real noteBaseline: 92
        readonly property real shake: 14               // px, first swing of the error shake
        // status glyphs (top right): battery x 2449..2487 (volume glyph without battery), Wi-Fi 2506..2526
        readonly property real statusY: 29
        readonly property real statusRight: 34
        readonly property real statusGap: 19
        readonly property real batteryWidth: 34
        readonly property real batteryHeight: 17
        readonly property real wifiWidth: 21
        readonly property real wifiHeight: 17.5
        readonly property real volumeSize: 22
        // backdrop
        readonly property int blurMax: 64
        readonly property real blur: 1.0
        readonly property real dim: 0.55               // dimColor over the blurred wallpaper
        readonly property color dimColor: "#101010"     // lifts pure black a little (ref/11 never goes below ~#080808)
        readonly property real saturation: -0.35
        // motion (Motion.ms applies)
        readonly property int lockIn: 700              // backdrop blurs + darkens, content settles
        readonly property int contentDelay: 120
        readonly property real rise: 26                // px the clock group slides down into place
        readonly property int unlockOut: 380
        readonly property int pillIn: 240
        readonly property int idleMs: 12000            // empty field falls back to the hint
        readonly property int forgetMs: 30000          // a half typed password is dropped after this
    }

    // ---- settings app (ref/12, measured 1:1 at 2560x1440) ------------------------
    // Own window (apps/settings, FloatingWindow 1072 x 724, Hyprland centres it in the
    // work area). Sidebar left, scrolling page right. Colours are palette mixes fitted
    // to noir: window = island black, cards barely lifted, controls one step up.
    readonly property QtObject settings: QtObject {
        readonly property int width: 1072
        readonly property int height: 724
        readonly property int radius: Math.round(root.rad(32))
        readonly property int sidebarWidth: 292      // faintly lifted column behind search + list
        // search field
        readonly property int searchX: 14
        readonly property int searchY: 14
        readonly property int searchWidth: 264
        readonly property int searchHeight: 43
        readonly property int searchRadius: Math.round(root.rad(12))
        readonly property real lensX: 23             // lens centre from the field's left edge
        readonly property int lensSize: 15
        readonly property int searchTextX: 43
        // sidebar rows
        readonly property int sideX: 14
        readonly property int sideWidth: 264
        readonly property real sideTop: 75           // first row top (row centres 100.5 + i * 57.4)
        readonly property real sideStep: 57.4
        readonly property int sideRowHeight: 51
        readonly property int sideRadius: Math.round(root.rad(14))
        readonly property int sideDiscX: 10
        readonly property int sideDisc: 40
        readonly property int sideIconSize: 23
        readonly property int sideTextX: 61
        readonly property int highlightMove: 180
        // back / forward
        readonly property int navX: 315
        readonly property int navY: 16
        readonly property int navWidth: 40
        readonly property int navHeight: 34
        readonly property int navGap: 8
        readonly property int navRadius: Math.round(root.rad(10))
        readonly property int navIconSize: 19
        // page column
        readonly property int pageTop: 64            // scroll viewport top (cards start here)
        readonly property int cardX: 324
        readonly property int cardWidth: 719
        readonly property int cardRadius: Math.round(root.rad(16))
        readonly property int headerHeight: 206
        readonly property real headerDiscY: 67       // centres from the header card top
        readonly property int headerDisc: 78
        readonly property int headerIconSize: 48
        readonly property real headerTitleY: 131
        readonly property real headerSubY: 166
        readonly property int titleSize: 24
        readonly property int gap: 17                // header -> untitled group
        readonly property int labelBlock: 51         // titled group: caption line above the card
        readonly property real labelY: 24.5
        readonly property int labelSize: 14
        readonly property int rowHeight: 59
        readonly property int sliderRowHeight: 88    // label line + track ("Font size")
        readonly property real sliderLabelY: 26
        readonly property real sliderTrackY: 62
        readonly property int rowInset: 20           // label x, separator inset
        readonly property int valueRight: 23         // value arrow right edge -> card edge
        readonly property int textSize: 17
        readonly property int arrowSize: 15
        readonly property int arrowGap: 7
        readonly property int swatch: 28
        readonly property int swatchStep: 38
        readonly property int swatchDot: 8
        readonly property int fieldWidth: 294
        readonly property int fieldHeight: 37
        readonly property int fieldRadius: Math.round(root.rad(9))
        readonly property int fieldPad: 8
        readonly property int switchWidth: 57
        readonly property int switchHeight: 30
        readonly property int knob: 20
        readonly property int trackHeight: 6
        readonly property int sliderKnob: 20
        readonly property int padBottom: 32
        readonly property int scrollX: 1058          // scrollbar handle (window coordinates)
        readonly property int scrollWidth: 8
        readonly property int scrollInset: 6
        readonly property int pageFade: 200          // content cross-fade on page change
        // dropdown (choices)
        readonly property int menuRow: 42
        readonly property int menuPad: 6
        readonly property int menuRadius: Math.round(root.rad(14))
        readonly property int menuMinWidth: 220

        readonly property color window: root.island
        readonly property color sidebar: root.mix(root.island, root.surface, 0.2)          // #020202
        readonly property color card: root.mix(root.island, root.surface, 0.55)            // #060606
        readonly property color search: root.mix(root.island, root.surfaceHigh, 0.51)      // #121212
        readonly property color nav: root.mix(root.island, root.surfaceHigh, 0.43)         // #0f0f0f
        readonly property color selected: root.mix(root.island, root.surfaceHigh, 0.77)    // #1b1b1b
        readonly property color disc: root.mix(root.island, root.surfaceHigh, 0.69)        // #181818
        readonly property color discOn: root.mix(selected, root.accent, 0.48)              // #7d7d7d on noir
        readonly property color field: root.mix(root.island, root.surfaceHigh, 0.63)       // #161616
        readonly property color switchOff: root.mix(root.island, root.surfaceHigh, 0.86)   // #1e1e1e
        readonly property color knobOff: root.mix(root.island, root.textDim, 0.9)          // #7c7c7c
        readonly property color separator: root.mix(root.island, root.surfaceHigh, 0.72)
        readonly property color scrollbar: selected
        readonly property color hover: root.mix(card, root.surfaceHigh, 0.32)
        readonly property color menu: root.mix(root.island, root.surfaceHigh, 0.62)
        readonly property color menuHover: root.mix(root.island, root.surfaceHigh, 1.0)
        readonly property color icon: root.mix(root.island, root.textDim, 0.9)
        readonly property color label: root.mix(root.text, root.island, 0.07)
        readonly property color value: root.mix(root.island, root.textDim, 0.87)
        readonly property color caption: root.mix(root.island, root.textDim, 0.77)
        readonly property color placeholder: root.mix(root.island, root.textDim, 0.95)
        readonly property color ring: root.textSecondary                                    // keyboard focus

        // settings-base: reset buttons, popovers and the option kinds added after the video
        readonly property int resetSize: 28          // per-option reset disc (only while changed)
        readonly property int resetGap: 8            // reset disc -> control
        readonly property int resetIconSize: 17
        readonly property int pageResetHeight: 30    // "Reset page" in the header card's corner
        readonly property int pageResetInset: 14
        readonly property real blockLabelY: 26       // tall rows (list, folders, custom): label line
        readonly property int blockTop: 50           // first content line under the label
        readonly property int blockPad: 12           // under the last content line
        readonly property int listRow: 46            // one entry of a list / folder row
        readonly property int miniButton: 30         // up / down / remove squares
        readonly property int miniRadius: Math.round(root.rad(9))
        readonly property int menuMaxRows: 9         // longer dropdowns scroll (and get a filter)
        readonly property int menuFilterHeight: 44
        readonly property int fontMenuWidth: 360
        readonly property int popover: 280           // colour picker width
        readonly property int popoverPad: 14
        readonly property int popoverRadius: Math.round(root.rad(18))
        readonly property int svHeight: 168          // saturation / value square
        readonly property int hueHeight: 14
        readonly property int colourDisc: 24
        readonly property int colourFieldWidth: 132
        readonly property int timeWidth: 86
        readonly property int day: 32                // weekday discs
        readonly property int dayGap: 6
        readonly property int toastHeight: 44
        readonly property int toastBottom: 22
        readonly property int tipPad: 10
        readonly property int tipSize: 14
        readonly property color danger: root.mix(root.danger, root.island, 0.15)
        readonly property color tip: root.mix(root.island, root.surfaceHigh, 1.0)
    }

    // ---- notification center (panels/NotificationCenter.qml; no video frame) ----------------
    // Drawn in the control center's language: same width (CC / launcher <-> center only morph
    // the height), black panel, cards with the CC radius and 1px outline, Inter, monochrome.
    // Header line: title + count left, Focus switch + "Clear all" right. Below, one group
    // per app: header row (icon, name, count, fold chevron, clear x) and its cards; a folded
    // group shows the newest card with the older ones as edges behind it (stack).
    readonly property QtObject nc: QtObject {
        readonly property int width: 686           // = Theme.cc.width
        readonly property int maxHeight: 760       // taller lists scroll
        readonly property int emptyHeight: 252     // header + "All caught up"
        readonly property int radius: Math.round(root.rad(38))           // = Theme.cc.radius
        readonly property int pad: 19              // panel edge -> cards (= cc)
        readonly property int headerHeight: 80     // title line; the list starts below it
        readonly property real headerY: 41         // title, switch and pill centre
        readonly property int titleX: 25           // = card edge + 6 (group icons share it)
        readonly property int titleSize: Math.round(root.tx(22))        // = sheet title
        readonly property int countGap: 10
        readonly property int labelSize: Math.round(root.tx(15))       // "Focus"
        readonly property int labelGap: 12         // "Focus" -> switch
        readonly property int controlsGap: 16      // switch -> "Clear all"
        readonly property int pillHeight: 34
        readonly property int groupHeader: 38      // header row; its centre line at groupY
        readonly property real groupY: 17
        readonly property int groupIcon: 22
        readonly property int groupIconX: 6        // from the card edge
        readonly property int groupTextX: 38       // name, from the card edge
        readonly property int groupSize: Math.round(root.tx(15))
        readonly property int groupGap: 16         // last card of a group -> next header
        readonly property int cardGap: 8
        readonly property int cardRadius: Math.round(root.rad(28))       // = Theme.cc.cardRadius
        readonly property int padX: 20
        readonly property int padY: 16
        readonly property int cardTitleSize: Math.round(root.tx(17))
        readonly property int bodySize: Math.round(root.tx(15))
        readonly property real bodyLineHeight: 1.12
        readonly property int bodyLines: 2
        readonly property int bodyLinesOpen: 16
        readonly property int bodyGap: 4           // title line -> body
        readonly property int timeSize: Math.round(root.tx(13))
        readonly property int dot: 6               // unread when the center was opened
        readonly property int chip: 26             // fold / unfold / dismiss discs
        readonly property int chipIcon: 13
        readonly property int thumb: 52            // wide image: at the right of the body
        readonly property int thumbGap: 14
        readonly property int lead: 40             // square image (avatar, cover): left of the text
        readonly property int leadGap: 14
        readonly property real leadAspect: 1.34    // up to this aspect (either way) an image counts as square
        readonly property int imageMaxHeight: 260  // unfolded: full width image below the body
        readonly property int imageRadius: Math.round(root.rad(16))
        readonly property int imageGap: 12
        readonly property int actionHeight: 32
        readonly property int actionSize: Math.round(root.tx(14))
        readonly property int actionGap: 8
        readonly property int actionsTop: 12
        readonly property int stackLayers: 2       // edges drawn behind a folded group
        readonly property int stackPeek: 8         // visible part of each edge
        readonly property int stackInset: 14       // each edge narrower by this per side
        readonly property real swipeAt: 0.3        // drag beyond this part of the width dismisses
        readonly property real edgeFade: 44        // list edge fades while more is off view
        readonly property int listInset: 6         // scrolled rows end this far above the panel edge (clear of the corners)
        readonly property real scrollbar: 3        // slim bar in the right gutter while the list scrolls
        readonly property int emptyIcon: 30
        readonly property int emptySize: Math.round(root.tx(18))
        // motion (Motion.ms applies)
        readonly property int move: 380            // rows slide, cards resize (= island panel morph)
        readonly property int enter: 260           // a new row fades in
        readonly property int enterDelay: 110      // ... after the rows below made room
        readonly property int leave: 200
        readonly property int fly: 170             // dismissed card flies out sideways
        readonly property int stagger: 26          // ms between rows while the panel opens
        readonly property real revealShift: 12
        readonly property color card: root.surface
        readonly property color cardHover: root.cc.hover
        readonly property color stroke: root.cc.stroke
        readonly property color strokeCritical: root.mix(root.cc.stroke, root.textDim, 0.55)
        readonly property color layer1: root.mix(root.surface, root.island, 0.12)
        readonly property color layer2: root.mix(root.surface, root.island, 0.35)
        readonly property color layerStroke1: root.cc.stroke
        readonly property color layerStroke2: root.mix(root.cc.stroke, root.island, 0.25)
        readonly property color chipColor: root.cc.chipColor
        readonly property color action: root.cc.chipColor
        readonly property color headerHover: root.mix(root.island, root.surface, 0.8)
        readonly property color ring: root.textSecondary
        readonly property color scrollbarColor: root.mix(root.island, root.textDim, 0.6)
    }

    // ---- configurable control center grid (panels/controlcenter/CcLayout, Settings.cc*) ---------
    // Rows keep the measured cc metrics: tiles in a row share the width left by the round
    // buttons (2 tiles + lock = 270 each, 2 tiles = 317 each, as in ref/08). A row takes up to
    // maxTiles tiles; round buttons join it while every tile stays at least minTile wide.
    readonly property QtObject ccLayout: QtObject {
        readonly property int maxTiles: 2
        readonly property int minTile: 220        // title + state still fit (textX 84 + ~120)
        readonly property int relayout: 380       // tiles glide to new slots when the layout changes
        // settings preview (apps/settings/pages/CcPreview.qml)
        readonly property real previewScale: 0.6
    }

    // ---- look (Settings look*): island fill, outline, shadow (island/IslandShape) -----------
    // Defaults are the video: solid island, no outline, no shadow. Opacity only thins the
    // island body (and the panels morphing out of it); text and cards stay solid. The shadow
    // needs room around the body: the island layer surface grows by shadowMargin while it is on.
    readonly property QtObject look: QtObject {
        readonly property real islandOpacity: Math.max(0.2, Math.min(1, Settings.lookIslandOpacity))
        readonly property real panelOpacity: Math.max(0.2, Math.min(1, Settings.lookPanelOpacity))
        readonly property bool translucent: islandOpacity < 1 || panelOpacity < 1
        readonly property int fillMs: 240              // island <-> panel opacity cross-fade
        readonly property bool border: Settings.lookBorder
        readonly property real borderWidth: Math.max(0.5, Math.min(6, Settings.lookBorderWidth))
        readonly property color borderColor: Settings.lookBorderColor !== "" ? Settings.lookBorderColor : root.mix(root.island, root.text, 0.2)
        readonly property bool shadow: Settings.lookShadow
        readonly property real strength: Math.max(0, Math.min(1, Settings.lookShadowStrength))
        readonly property real shadowBlur: 14 + 34 * strength
        readonly property real shadowOpacity: 0.3 + 0.5 * strength
        readonly property real shadowOffset: 3 + 7 * strength  // px down
        readonly property int shadowMargin: shadow ? Math.ceil(shadowBlur + shadowOffset + 4) : 0
    }

    // ---- island layout (island/bar/BarRegistry.qml, island/bar/layout.js, island/widgets) -----
    // Settings.islandLayout puts widgets into slots; these are the measures the video does not
    // give: widgets the video only shows in the hover island get collapsed sizes here, new
    // widgets get both. The default layout uses the collapsed/hover blocks above unchanged.
    readonly property QtObject widgets: QtObject {
        // hover island with only one row in use: the top row of ref/02, the bottom one cut away
        readonly property int oneRowHeight: 64
        readonly property int oneRowRadius: 32
        readonly property real oneRowY: 32
        // a column whose other row is empty is centred between both rows (ref/02 clock + date)
        readonly property real spanY: root.hover.clockY
        // island width = default width + (content - default content), clamped
        readonly property int minWidth: 120
        readonly property int maxWidth: 1800
        // at least this much air between the centre column and the sides, measured on what
        // shows (not for the default layout: the video's 958 px stays, long titles included)
        readonly property var minGap: [16, 24]
        // gap between neighbours by widget class: [collapsed, hover]; class pairs are unordered
        readonly property var gaps: ({
                "time": [8, root.hover.dateGap],
                "status": [root.collapsed.statusGap, root.hover.statusGap],
                "system": [2, 4],                                   // gear + power (IconButtons, 5 px air each)
                "label": [12, 16],
                "tray": [8, 10],
                "tray|status": [12, root.hover.trayGap],
                "system|label": [14, root.hover.systemGap],
                "other": [12, 20]                                   // any other pair of classes
            })
        // collapsed sizes of widgets the video shows only in the hover island
        readonly property real titleSize: 15
        readonly property real appIconSize: 18
        readonly property real appIconGap: 8
        readonly property real titleShare: 0.55     // collapsed longest title = this x islandWindowMaxWidth
        readonly property real notifSize: 15
        readonly property real bellSize: 17
        readonly property real notifGap: 9          // label -> bell (hover: 12)
        readonly property real chipCover: 20
        readonly property real chipButton: 22
        readonly property real chipMaxWidth: 220
        readonly property real systemIconSize: 16
        readonly property real dateSize: 15
        // new widgets: glyph + short text, [collapsed, hover]
        readonly property var textSize: [15, 17]
        readonly property var iconSize: [17, 20]
        readonly property var iconGap: [5, 7]
        // workspace styles (capsules: Theme.collapsed/hover): [collapsed, hover]
        readonly property var dotSize: [7, 9]
        readonly property var dotActive: [16, 22]   // the active dot stretches to a short pill
        readonly property var dotStep: [13, 17]
        readonly property var numberSize: [14, 17]
        readonly property var numberStep: [17, 22]
        // where hover-only parts start while the island is still collapsed (ref/03), as a share
        // of their rest line: top row 14 / 32 (Theme.hover.topStartY / row1Y)
        readonly property real startShare: root.hover.topStartY / root.hover.row1Y
        readonly property int reflow: 220           // neighbours slide when a slot changes
    }

    // ---- island editor (apps/settings/island, "Bar & Island" page) -------------------------------
    // A strip per state with the real island hanging from its top edge at preview scale, the
    // widget palette below, the options of the picked widget next to it. Monochrome, no chrome.
    readonly property QtObject islandEditor: QtObject {
        readonly property int segHeight: 32         // Collapsed | Hover | Both
        readonly property int segRadius: 10
        readonly property int segPad: 14
        readonly property int stripRadius: 14
        readonly property int stripPadTop: 0        // the island hangs from the strip's top edge
        readonly property int stripPadBottom: 22
        readonly property int stripGap: 10
        readonly property int captionSize: 12
        readonly property real maxScale: 0.72
        readonly property int chipHeight: 34
        readonly property int chipRadius: 10
        readonly property int chipPad: 11
        readonly property int chipIcon: 16
        readonly property int chipGap: 8
        readonly property int optionsWidth: 268
        readonly property int panelRadius: 14
        readonly property int panelPad: 16
        readonly property int caret: 3              // insertion marker width
        readonly property int dragThreshold: 6
        readonly property int selectPad: 5          // selection ring around a widget
        readonly property real dropOut: 34          // px beyond a strip that still counts as inside
        readonly property color strip: root.mix(root.island, root.surfaceHigh, 0.9)
        readonly property color stripEdge: root.mix(root.island, root.surfaceHigh, 0.55)
        readonly property color slot: root.mix(root.surfaceHigh, root.text, 0.10)
        readonly property color slotHot: root.mix(root.surfaceHigh, root.text, 0.22)
        readonly property color caretColor: root.accent
        readonly property color ring: root.textSecondary
        readonly property color chip: root.settings.field
        readonly property color chipHover: root.mix(root.settings.field, root.text, 0.1)
        readonly property color chipUsed: root.mix(root.settings.field, root.text, 0.04)
        readonly property color remove: root.settings.danger
    }

    // ---- power menu (panels/PowerMenu, variant B: a menu list with info lines) --------------
    // The launcher's language (black body, icon tile, title, dim subtitle) narrowed to a menu:
    // filter line on top, one row per action. A confirmed action arms its row: it fills with
    // the power red and drains back over Settings.powerConfirmTime (the fallback countdown).
    readonly property QtObject power: QtObject {
        readonly property int width: 540
        readonly property int headerHeight: 66     // filter row; 1 px separator on its last line
        readonly property real centerY: 34
        readonly property real lensX: 24
        readonly property real lensSize: 18
        readonly property real inputX: 58
        readonly property real inputSize: root.tx(17)
        readonly property real hostSize: root.tx(14)      // user@host at the right of the filter row
        readonly property real inset: 14           // separator + rows, left and right
        readonly property int listTop: 78
        readonly property int padBottom: 14
        readonly property int rowHeight: 62
        readonly property real rowRadius: root.rad(14)
        readonly property real barX: 2             // selection bar inside the highlight (launcher)
        readonly property real barWidth: 3
        readonly property real barHeight: 30
        readonly property real tileX: 12
        readonly property real tileSize: 42
        readonly property real tileRadius: root.rad(11)
        readonly property real glyphSize: 20
        readonly property real textX: 68
        readonly property real titleSize: root.tx(18)
        readonly property real subtitleSize: root.tx(14.5)
        readonly property real titleBaseline: 27   // from the row top
        readonly property real subtitleBaseline: 46
        readonly property int highlightMove: 160
        readonly property int stagger: 26          // ms between rows while the panel opens
        readonly property real revealShift: 8
        readonly property int armFade: 140         // red in / out
        readonly property int armGuard: 350        // ms after arming in which a second click is ignored (double click)
        readonly property color highlight: root.mix(root.island, root.text, 0.105)
        readonly property color separator: root.mix(root.island, root.text, 0.1)
        readonly property color tile: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.065)
        readonly property color armed: root.danger                          // remaining part of the countdown
        readonly property color armedSpent: root.mix(root.island, root.danger, 0.36) // elapsed part
        readonly property color armedInk: "#ffffff"
        readonly property color armedTile: Qt.rgba(1, 1, 1, 0.18)
    }

    // ---- settings app: sidebar groups + "Keep these settings?" dialog (sys-base) -----------
    // Sidebar: a caption line ("luxshell", "System") above each group of pages, in the style
    // of the page captions. Keep dialog: a card over the dimmed window, countdown line,
    // Revert / Keep (apps/settings/KeepDialog.qml).
    readonly property QtObject settingsSys: QtObject {
        readonly property int groupHead: 32          // caption line above a group (sidebar)
        readonly property real groupLabelY: 19       // caption centre from the top of that line
        readonly property int groupLabelX: 24        // from the sidebar's left edge (= icon discs)
        readonly property int groupGap: 10           // extra space above every group but the first
        readonly property int keepWidth: 440
        readonly property int keepPad: 26
        readonly property int keepRadius: Math.round(root.rad(22))
        readonly property int keepDisc: 52
        readonly property int keepIconSize: 28
        readonly property int keepTitleSize: 20
        readonly property int keepTrack: 4           // countdown line
        readonly property int keepButtonHeight: 36
        readonly property int keepButtonGap: 10
        readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)
        readonly property color keepCard: root.settings.menu
        readonly property color keepTrackColor: root.settings.field
        readonly property color keepFill: root.accent
    }

    // ---- bar info + tool widgets (island/widgets: Gpu, Temp, NetSpeed, Updates, Tool, Privacy;
    // panels/PrivacyPanel). Glyph + text sizes come from `widgets` above; [collapsed, hover].
    readonly property QtObject barInfo: QtObject {
        readonly property real arrowScale: 0.82     // netspeed arrows next to the text
        readonly property var dotSize: [8, 10]      // privacy dot
        readonly property var privacyGap: [6, 8]    // dot -> first glyph
        readonly property var privacyIconGap: [4, 6]
        readonly property real privacyIconScale: 0.9
        // privacy panel: the power menu's rows, narrower
        readonly property int panelWidth: 440
        readonly property int maxRows: 5
        readonly property int headerHeight: 62
        readonly property real centerY: 32
        readonly property real dotX: 28
        readonly property real headerDot: 9
        readonly property real titleX: 48
        readonly property real padRight: 26
        readonly property real headerSize: root.tx(17)
        readonly property real inset: 14
        readonly property int listTop: 72
        readonly property int padBottom: 12
        readonly property int rowHeight: 60
        readonly property real tileX: 12
        readonly property real tileSize: 40
        readonly property real tileRadius: root.rad(11)
        readonly property real appIconSize: 24
        readonly property real glyphSize: 18
        readonly property real glyphRight: 14
        readonly property real textX: 66
        readonly property real titleSize: root.tx(17)
        readonly property real subtitleSize: root.tx(14)
        readonly property real titleBaseline: 27
        readonly property real subtitleBaseline: 46
        readonly property color separator: root.mix(root.island, root.text, 0.1)
        readonly property color tile: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.065)
    }

    // ---- bar menus (panels/SheetMenu, island/widgets/BarToggle) -------------------------------
    // A control-center sheet as its own island panel (registry "sheet-*"): the island grows
    // straight into the sheet, no control center around it, no back disc. The sheet content
    // keeps the measures of Theme.cc.sheet; only the panel around it is set here. The small
    // menus (registry "menu-*": power mode, caffeine) are the same sheet, narrower.
    readonly property QtObject menus: QtObject {
        readonly property int width: 560           // sheet menus (Bluetooth, sound, network, display)
        readonly property int smallWidth: 400      // power mode, caffeine
        readonly property int maxHeight: 686       // = cc.maxHeight; taller content scrolls
        readonly property int minHeight: 160
        readonly property int topPad: 2            // island top edge -> sheet header block
        readonly property int radius: Math.round(root.rad(38))       // = cc.radius
        readonly property int smallRadius: Math.round(root.rad(32))
        readonly property int closeDelay: 120      // ms a picked row of a small menu shows its check before the menu closes
        // bar widget highlight under the pointer (same as the media chip / notification status)
        readonly property real hitPad: 8
        readonly property real hitGrow: 14         // highlight height = glyph + this
        readonly property color hit: root.media.chipHover
        readonly property color off: root.textDim  // glyph of a switch that is off (night light, caffeine)
        readonly property color recording: root.danger // microphone while an app records
    }

    // ---- Settings > System > Displays (apps/settings/displays, pages/SysDisplays.qml) ------------
    // The stage on top (the one display drawn large; two or more: the arrangement canvas), then
    // chips and segment bars instead of dropdowns. Monochrome: plates and outlines in the
    // settings greys, the selection in the text colour, snap guides in the accent.
    readonly property QtObject displays: QtObject {
        readonly property int stageHeight: 262       // one display: drawing + stand
        readonly property int screenMaxWidth: 400
        readonly property int screenMaxHeight: 184
        readonly property int screenTop: 26
        readonly property int bezel: 7
        readonly property int screenRadius: Math.round(root.rad(14))
        readonly property int neckWidth: 46
        readonly property int neckHeight: 15
        readonly property int baseWidth: 138
        readonly property int baseHeight: 6
        readonly property int canvasHeight: 286      // two or more: the arrangement
        readonly property int canvasInset: 14        // canvas -> card edge
        readonly property int canvasPad: 30          // monitors -> canvas edge (fit)
        readonly property real canvasRoom: 0.78      // the arrangement fills at most this much: room to drag
        readonly property int canvasRadius: Math.round(root.rad(14))
        readonly property int monitorRadius: Math.round(root.rad(9))
        readonly property real snap: 14              // px on the canvas: edges closer than this snap
        readonly property int footerHeight: 58       // under the canvas: selected display, main, off
        readonly property int nameSize: 20
        readonly property int subSize: 14
        readonly property int chipHeight: 56         // resolution chips
        readonly property int chipGap: 8
        readonly property int chipColumns: 4
        readonly property int chipRadius: Math.round(root.rad(12))
        readonly property int segHeight: 36          // segment bars (refresh rate, VRR, colour, mirror)
        readonly property int segRadius: Math.round(root.rad(11))
        readonly property int segPad: 16
        readonly property int tickTrack: 6           // scale: stepped slider
        readonly property int tickHeight: 12
        readonly property int tickLabelGap: 46       // min px between two tick labels
        readonly property int rotationTile: 78       // four small monitors
        readonly property int rotationGap: 10
        readonly property color canvas: root.settings.window
        readonly property color screen: root.mix(root.settings.card, root.surfaceHigh, 0.42)
        readonly property color screenHigh: root.mix(root.settings.card, root.surfaceHigh, 0.7)
        readonly property color bezelColor: root.mix(root.island, root.surfaceHigh, 0.5)
        readonly property color outline: root.mix(root.island, root.surfaceHigh, 1.0)
        readonly property color monitor: root.mix(root.island, root.surfaceHigh, 0.75)
        readonly property color monitorHover: root.mix(root.island, root.surfaceHigh, 0.95)
        readonly property color monitorSelected: root.mix(root.surfaceHigh, root.text, 0.1)
        readonly property color plate: root.mix(root.settings.field, root.text, 0.14)
        readonly property color guide: root.mix(root.island, root.accent, 0.6)
    }

    // ---- polkit prompt (panels/PolkitPrompt, services/Polkit) --------------------------------
    // The island grows into a card in the lock screen's language: who asks (app icon + label),
    // avatar disc(s), user name, the request text, the password pill with the lock screen's dots,
    // a note line, then Details / Cancel. Discs, pill and text alphas come from Theme.lock, so
    // both screens read the same. Heights stack top to bottom; the card follows them live.
    readonly property QtObject polkit: QtObject {
        readonly property int width: 520
        readonly property int radius: Math.round(root.rad(38))   // = cc / sheet menus
        readonly property int maxHeight: 640                     // taller content (long text) elides
        readonly property real padTop: 24
        readonly property real padBottom: 20
        readonly property real padX: 30
        // who asks
        readonly property real headHeight: 24
        readonly property real headIcon: 20
        readonly property real headGap: 9
        readonly property real headSize: root.tx(15)
        // identities: the selected disc large, the others small + dimmed beside it
        readonly property real identityTop: 22                    // header -> discs
        readonly property real avatarSize: 76
        readonly property real avatarSmall: 44
        readonly property real avatarGap: 16
        readonly property real avatarDim: 0.42
        readonly property real initialScale: 0.4                  // letter height / disc
        readonly property real nameTop: 12                        // discs -> name line
        readonly property real nameSize: root.tx(22)
        readonly property real nameHeight: 30
        readonly property real switchSize: 18                     // chevrons beside the name (several identities)
        readonly property real switchGap: 10
        // request text
        readonly property real messageTop: 12
        readonly property real messageSize: root.tx(16)
        readonly property real messageLine: 1.22
        readonly property int messageLines: 4
        readonly property real messageAlpha: 0.62
        // password pill (the lock screen's, a bit wider) + note
        readonly property real pillTop: 22
        readonly property real pillWidth: 320
        readonly property real pillHeight: 42
        readonly property real goSize: 30                         // submit disc at the right end
        readonly property real goInset: 6
        readonly property real noteTop: 8
        readonly property real noteHeight: 20
        readonly property real noteSize: root.tx(14)
        readonly property real noteAlpha: 0.54
        readonly property real noteErrorAlpha: 0.86
        // footer: Details (left), Cancel (right)
        readonly property real footTop: 14
        readonly property real buttonHeight: 34
        readonly property real buttonPadX: 16
        readonly property real buttonSize: root.tx(15)
        readonly property real buttonFill: 0.08
        readonly property real buttonHover: 0.15
        // details
        readonly property real detailsTop: 12
        readonly property real detailsPad: 14
        readonly property real detailsRow: 24
        readonly property real detailsLabel: 86                   // label column
        readonly property real detailsSize: root.tx(13.5)
        readonly property real detailsFill: 0.05
        readonly property real detailsRadius: root.rad(16)
        // motion (Motion.ms applies)
        readonly property int switchMs: 260                       // discs re-arrange on an identity switch
        readonly property int detailsMs: 220
        readonly property int successHold: 420                    // check in the pill before the card closes
    }

    // ---- System > Sound, Network & Bluetooth (apps/settings/sysnet) -------------------------
    // Lists inside the settings cards: one line per device / profile / network, an icon disc,
    // name + grey sub line, actions right; a line can unfold its details below.
    readonly property QtObject sysnet: QtObject {
        readonly property int line: 64              // one list line (two text lines)
        readonly property int disc: 38              // icon disc left
        readonly property int discIcon: 21
        readonly property int textGap: 14           // disc -> name
        readonly property real subSize: 13.5
        readonly property int subGap: 2             // name -> sub line
        readonly property int buttonGap: 8          // between the buttons right
        readonly property int detailRow: 40         // one line of unfolded details (key / value)
        readonly property int detailPadTop: 2
        readonly property int detailPadBottom: 14
        readonly property int detailKey: 150        // key column width
        readonly property real detailSize: 14.5
        readonly property int dnsField: 330         // custom DNS servers field
        readonly property int volumeButton: 34      // mute disc left of a volume slider
        readonly property int sliderGap: 14
        readonly property int appLine: 76           // per-app volume: name line + slider
        readonly property int appIcon: 26
        readonly property int meterBars: 30         // live input level
        readonly property int meterBarWidth: 6
        readonly property int meterGap: 4
        readonly property int meterHeight: 18
        readonly property int infoRow: 40           // address lines of the connection card
        readonly property int pwHeight: 52          // Wi-Fi password line
        readonly property color discOn: root.mix(root.settings.selected, root.text, 0.12)
        readonly property color meterOff: root.mix(root.island, root.surfaceHigh, 0.9)
        readonly property color meterHot: root.mix(root.accent, root.danger, 0.7)
    }
}
