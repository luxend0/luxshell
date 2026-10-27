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
Singleton {
    id: root

    readonly property real slowmo: Env.slowmo

    readonly property var standard: [0.4, 0.0, 0.2, 1.0, 1, 1]
    readonly property var emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

    readonly property var specs: ({
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
        })

    // anything that involves a panel or overlay uses "panel"
    function spec(from: string, to: string): var {
        return specs[from + ">" + to] ?? specs.panel;
    }

    function ms(v: real): int {
        return Math.round(v * slowmo);
    }

    // ---- content fades ---------------------------------------------------------
    // bar <-> panel cross-fade (bar content and panel slots)
    readonly property int fadeOut: 110
    readonly property int fadeIn: 220
    readonly property int fadeInDelay: 90
    // hover-only top row + extras: late in on open, gone at once on close (ref/14)
    readonly property int topIn: 260
    readonly property int topInDelay: 90
    readonly property int topOut: 70

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
