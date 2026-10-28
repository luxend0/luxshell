pragma Singleton
import QtQuick
import Quickshell

// Island motion, fitted to the video frames ref/13 (hover open) and ref/14 (hover close).
//
//   Open:  height leads (32 % after ~110 ms), width starts ~70 ms later, the content
//          (horizontal progress) trails the shape by another ~40 ms (ref/03 midway).
//   Close: width leads (66 % after ~130 ms), height follows more slowly (34 %).
//   Both curves start soft and ease out long, no overshoot ("standard").
//   Panels (open, switch, close, runtime resize) use "emphasized": fast start, long tail.
//
// specs: per transition "from>to" and axis [duration ms, delay ms, bezier]
//   w, h, r  island body (width, height, bottom radius)
//   cx, cy   content progress 0 = collapsed layout, 1 = hover layout (default: w, h)
//   wy       vertical progress of the workspace row (default: cy). It trails the height
//            in BOTH directions (ref/03: still high mid-open, ref/14: still low while
//            closing), which no p^k lag can do, so it gets its own axis.
// Every axis animates from its current value, so any transition can interrupt any other.
//
// Secondary animations (widgets/Anim) keep Theme.curve; all durations go through ms()
// so LUXSHELL_SLOWMO (Env.slowmo) slows the whole shell down for frame captures.
//
// Style (Settings.motionStyle, Motion page of the settings app), switched live; it picks
// the specs and content fades below, so it reaches the island morph, every panel open /
// switch / close / resize (all of them run through "panel") and the panel cross-fades:
//   video    the fitted curves above (default)
//   spring   a damped spring (zeta 0.65, ~7 % overshoot, one barely visible swing back) on
//            every growing / resizing transition; closing to the collapsed bar settles
//            without overshoot (no undershoot below the bar height). The island's layer
//            surface gets `overshoot` of room (island/IslandWindow) so the swing is not clipped.
//   fast     same curves, ~0.6 of the durations and delays
//   reduced  no geometry motion: the body jumps to its new size, only the content
//            cross-fades (bar, top row, panel slots). Motion.reduced lets panels drop
//            their own slides too.
// standard / emphasized stay the video curves whatever the style: panels use them as
// named curves for their own animations.
Singleton {
    id: root

    readonly property real slowmo: Env.slowmo
    // Settings "Animation speed" (apps/settings, Motion page): 2 = everything twice as fast
    readonly property real speed: Math.max(0.25, Math.min(4, Settings.animationSpeed || 1))

    readonly property var styles: ["video", "spring", "fast", "reduced"]
    readonly property string style: styles.includes(Settings.motionStyle) ? Settings.motionStyle : "video"
    readonly property bool reduced: style === "reduced"
    // peak overshoot of the spring as a fraction of the distance (room the surface needs)
    readonly property real overshoot: style === "spring" ? 0.07 : 0

    readonly property var standard: [0.4, 0.0, 0.2, 1.0, 1, 1]
    readonly property var emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
    // damped spring (zeta 0.65), fitted with three cubic segments split at its extremes:
    // rise to +6.8 % at 43 % of the time, back to -0.5 % at 86 %, rest at 1
    readonly property var spring: [0.12, 0.3, 0.288, 1.068, 0.432, 1.068, 0.577, 1.068, 0.721, 0.995, 0.865, 0.995, 0.91, 0.995, 0.955, 1.0, 1.0, 1.0]
    // critically damped landing (spring style, closing to the bar): quick, no overshoot
    readonly property var settle: [0.3, 0.0, 0.15, 1.0, 1, 1]
    // the curve the island body uses for panels in the current style (panels that want
    // their own edges to follow the body can take it with specs.panel durations)
    readonly property var panelCurve: specs.panel.h[2]

    readonly property var styleSpecs: ({
            "video": {
                "collapsed>hover": {
                    "w": [340, 70, standard],
                    "h": [370, 0, standard],
                    "r": [370, 0, standard],
                    "cx": [340, 110, standard],
                    "wy": [420, 20, standard]
                },
                "hover>collapsed": {
                    "w": [300, 0, standard],
                    "h": [420, 0, standard],
                    "r": [420, 0, standard],
                    "wy": [540, 0, standard]
                },
                "panel": {
                    "w": [380, 0, emphasized],
                    "h": [400, 0, emphasized],
                    "r": [380, 0, emphasized]
                }
            },
            "spring": {
                "collapsed>hover": {
                    "w": [560, 40, spring],
                    "h": [600, 0, spring],
                    "r": [420, 0, settle],
                    "cx": [340, 90, standard],
                    "wy": [420, 20, standard]
                },
                "hover>collapsed": {
                    "w": [320, 0, settle],
                    "h": [380, 0, settle],
                    "r": [380, 0, settle],
                    "wy": [480, 0, standard]
                },
                "panel": {
                    "w": [620, 0, spring],
                    "h": [660, 0, spring],
                    "r": [420, 0, settle]
                },
                // closing a panel: land on the bar without undershoot
                "panel>collapsed": {
                    "w": [340, 0, settle],
                    "h": [380, 0, settle],
                    "r": [380, 0, settle]
                },
                "panel>hover": {
                    "w": [340, 0, settle],
                    "h": [380, 0, settle],
                    "r": [380, 0, settle]
                }
            },
            "fast": {
                "collapsed>hover": {
                    "w": [200, 40, standard],
                    "h": [220, 0, standard],
                    "r": [220, 0, standard],
                    "cx": [200, 60, standard],
                    "wy": [250, 10, standard]
                },
                "hover>collapsed": {
                    "w": [180, 0, standard],
                    "h": [250, 0, standard],
                    "r": [250, 0, standard],
                    "wy": [320, 0, standard]
                },
                "panel": {
                    "w": [230, 0, emphasized],
                    "h": [240, 0, emphasized],
                    "r": [230, 0, emphasized]
                }
            },
            "reduced": {
                "collapsed>hover": {
                    "w": [0, 0, standard],
                    "h": [0, 0, standard],
                    "r": [0, 0, standard],
                    "cx": [0, 0, standard],
                    "wy": [0, 0, standard]
                },
                "hover>collapsed": {
                    "w": [0, 0, standard],
                    "h": [0, 0, standard],
                    "r": [0, 0, standard],
                    "wy": [0, 0, standard]
                },
                "panel": {
                    "w": [0, 0, standard],
                    "h": [0, 0, standard],
                    "r": [0, 0, standard]
                }
            }
        })

    readonly property var specs: styleSpecs[style]

    // anything that involves a panel or overlay uses "panel" (unless the style has its own
    // "panel>collapsed" ...)
    function spec(from: string, to: string): var {
        return specs[from + ">" + to] ?? specs.panel;
    }

    function ms(v: real): int {
        return Math.round(v * slowmo / speed);
    }

    // ---- content fades ---------------------------------------------------------
    // per style: [fadeOut, fadeIn, fadeInDelay, topIn, topInDelay, topOut]
    readonly property var styleFades: ({
            "video": [110, 220, 90, 260, 90, 70],
            "spring": [110, 220, 90, 260, 90, 70],
            "fast": [70, 140, 50, 160, 50, 50],
            "reduced": [140, 220, 0, 220, 0, 120]
        })
    readonly property var fades: styleFades[style]
    // bar <-> panel cross-fade (bar content and panel slots)
    readonly property int fadeOut: fades[0]
    readonly property int fadeIn: fades[1]
    readonly property int fadeInDelay: fades[2]
    // hover-only top row + extras: late in on open, gone at once on close (ref/14)
    readonly property int topIn: fades[3]
    readonly property int topInDelay: fades[4]
    readonly property int topOut: fades[5]

    // ---- per-element lag (ref/14) ------------------------------------------------
    // Each element follows q = p^k of the content progress: k > 1 runs ahead while
    // closing and trails while opening, so elements at the front of the motion lead.
    readonly property var lag: ({
            "workspacesX": [1.0, 1.05, 1.1, 1.25, 1.8], // outer -> inner capsule
            "workspacesSize": 0.4, // of wy: capsules stay big while closing, grow early on open
            "clockY": 0.75,
            "volumeX": 1.2,
            "volumeY": 1.3,
            "signalX": 2.4,
            "signalY": 1.6,
            "topY": 1.5
        })

    // windows [from, to] of the horizontal progress in which hover-only parts fade in
    readonly property var reveal: ({
            "date": [0.4, 0.9],
            "topIcon": [0.0, 0.4], // app icon, bell
            "topText": [0.5, 1.0], // window title, "All caught up"
            "extras": [0.7, 1.0] // gear, power, tray
        })

    function smooth(t: real, range: var): real {
        const x = Math.max(0, Math.min(1, (t - range[0]) / (range[1] - range[0])));
        return x * x * (3 - 2 * x);
    }
    function lagged(p: real, k: real): real {
        return Math.pow(Math.max(0, Math.min(1, p)), k);
    }
    // k for capsule i of n: the fitted table for 5, interpolated for other counts
    function workspaceLag(i: int, n: int): real {
        const ks = lag.workspacesX;
        if (n <= 1)
            return ks[0];
        const f = i / (n - 1) * (ks.length - 1);
        const a = Math.floor(f);
        const b = Math.min(ks.length - 1, a + 1);
        return ks[a] + (ks[b] - ks[a]) * (f - a);
    }
}
