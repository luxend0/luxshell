import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.island.bar

// Morph container for one screen. It decides WHAT is shown (Ui priorities) and
// moves the body there; content comes from BarContent (collapsed/hover) or from
// PanelHost (whatever panel the registry provides, size reported by the panel).
//
// Motion (config/Motion.qml): mode collapsed | hover | panel gives a target
// geometry; morph() starts one animation per axis (width, height, radius and the
// bar content's horizontal/vertical/workspace-row progress) with its own duration, delay and
// curve for the transition "from>to", always from the current value, so every
// transition can interrupt every other one.
Item {
    id: island

    required property var screen
    readonly property string screenName: screen?.name ?? ""
    readonly property alias body: shape

    // ---- what is shown ------------------------------------------------------
    readonly property string panelId: Ui.panelFor(screenName)
    readonly property string overlayId: panelId === "" ? Ui.overlayFor(screenName) : ""
    readonly property string shownId: panelId !== "" ? panelId : overlayId
    readonly property bool modal: panelId !== ""
    // focus grab + exclusive keyboard only where the panel was opened; a preview
    // shown on every screen must not fight over the grab
    readonly property bool grabs: modal && Ui.panelScreen === screenName
    readonly property Item panel: shownId !== "" ? host.current : null

    property bool pointerInside: false
    readonly property bool expanded: Ui.forced === "hover" || (Ui.forced !== "collapsed" && (pointerInside || bar.holdOpen))
    readonly property string mode: panel ? "panel" : expanded ? "hover" : "collapsed"

    readonly property var target: {
        if (panel)
            return {
                "w": panel.preferredWidth,
                "h": panel.preferredHeight,
                "r": panel.cornerRadius
            };
        const g = expanded ? Theme.hover : Theme.collapsed;
        return {
            "w": g.width,
            "h": g.height,
            "r": g.radius
        };
    }

    // ---- morph state (animated by morph(), never bound) ----------------------
    property real bw: Theme.collapsed.width
    property real bh: Theme.collapsed.height
    property real br: Theme.collapsed.radius
    property real cxp: 0 // bar content progress, horizontal (0 collapsed .. 1 hover)
    property real cyp: 0 // bar content progress, vertical
    property real wyp: 0 // workspace row, vertical (own axis, trails cyp both ways)
    property real topAlpha: 0 // hover-only top row + extras
    property real barAlpha: 1 // whole bar content (out while a panel is shown)
    property string lastMode: "collapsed"
    property var animTo: null

    onTargetChanged: morph()
    Component.onCompleted: {
        // start state without animation (preview, reload)
        const t = target;
        bw = t.w;
        bh = t.h;
        br = t.r;
        cxp = cyp = wyp = mode === "hover" ? 1 : 0;
        topAlpha = mode === "hover" ? 1 : 0;
        barAlpha = mode === "panel" ? 0 : 1;
        lastMode = mode;
        animTo = t;
    }

    // Delays only apply from rest: an axis still on its way (value short of its last
    // target) turns around at once instead of freezing mid-motion for the delay
    // (e.g. pointer back on the island while it is still closing).
    function setup(anim: NumberAnimation, pause: PauseAnimation, s: var, to: real, cur: real, busy: bool): void {
        pause.duration = busy && cur !== anim.to ? 0 : Motion.ms(s[1]);
        anim.duration = Motion.ms(s[0]);
        anim.easing.bezierCurve = s[2];
        anim.to = to;
    }

    function morph(): void {
        const t = target;
        if (t.w <= 0 || t.h <= 0)
            return;
        if (animTo && t.w === animTo.w && t.h === animTo.h && t.r === animTo.r && lastMode === mode)
            return;
        const s = Motion.spec(lastMode, mode);
        const from = lastMode;
        lastMode = mode;
        animTo = t;

        const busy = geo.running;
        geo.stop();
        setup(animW, pauseW, s.w, t.w, bw, busy);
        setup(animH, pauseH, s.h, t.h, bh, busy);
        setup(animR, pauseR, s.r, t.r, br, busy);
        // while a panel is shown the (invisible) bar layout stays where it is
        const c = mode === "hover" ? 1 : mode === "collapsed" ? 0 : -1;
        setup(animCX, pauseCX, s.cx ?? s.w, c < 0 ? cxp : c, cxp, busy);
        setup(animCY, pauseCY, s.cy ?? s.h, c < 0 ? cyp : c, cyp, busy);
        setup(animWY, pauseWY, s.wy ?? s.cy ?? s.h, c < 0 ? wyp : c, wyp, busy);
        geo.start();

        if (from === mode)
            return;
        // top row: late in on open, out at once on close (ref/14)
        top.stop();
        const show = mode === "hover";
        topPause.duration = show ? Motion.ms(Motion.topInDelay) : 0;
        topAnim.duration = Motion.ms(show ? Motion.topIn : Motion.topOut);
        topAnim.to = show ? 1 : 0;
        top.start();
        // bar <-> panel cross-fade (the panel side lives in PanelHost)
        if (mode === "panel" || from === "panel") {
            fade.stop();
            const toPanel = mode === "panel";
            fadePause.duration = toPanel ? 0 : Motion.ms(Motion.fadeInDelay);
            fadeAnim.duration = Motion.ms(toPanel ? Motion.fadeOut : Motion.fadeIn);
            fadeAnim.to = toPanel ? 0 : 1;
            fade.start();
        }
    }

    ParallelAnimation {
        id: geo
        SequentialAnimation {
            PauseAnimation {
                id: pauseW
            }
            NumberAnimation {
                id: animW
                target: island
                property: "bw"
                easing.type: Easing.BezierSpline
            }
        }
        SequentialAnimation {
            PauseAnimation {
                id: pauseH
            }
            NumberAnimation {
                id: animH
                target: island
                property: "bh"
                easing.type: Easing.BezierSpline
            }
        }
        SequentialAnimation {
            PauseAnimation {
                id: pauseR
            }
            NumberAnimation {
                id: animR
                target: island
                property: "br"
                easing.type: Easing.BezierSpline
            }
        }
        SequentialAnimation {
            PauseAnimation {
                id: pauseCX
            }
            NumberAnimation {
                id: animCX
                target: island
                property: "cxp"
                easing.type: Easing.BezierSpline
            }
        }
        SequentialAnimation {
            PauseAnimation {
                id: pauseCY
            }
            NumberAnimation {
                id: animCY
                target: island
                property: "cyp"
                easing.type: Easing.BezierSpline
            }
        }
        SequentialAnimation {
            PauseAnimation {
                id: pauseWY
            }
            NumberAnimation {
                id: animWY
                target: island
                property: "wyp"
                easing.type: Easing.BezierSpline
            }
        }
    }

    SequentialAnimation {
        id: top
        PauseAnimation {
            id: topPause
        }
        NumberAnimation {
            id: topAnim
            target: island
            property: "topAlpha"
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: fade
        PauseAnimation {
            id: fadePause
        }
        NumberAnimation {
            id: fadeAnim
            target: island
            property: "barAlpha"
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: leaveHold
        interval: Theme.hoverHold
        onTriggered: island.pointerInside = false
    }

    IslandShape {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: island.bw
        height: island.bh
        radius: island.br

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leaveHold.stop();
                    island.pointerInside = true;
                } else {
                    leaveHold.restart();
                }
            }
        }

        // click on the bar = control center (children with own handlers win)
        MouseArea {
            anchors.fill: parent
            enabled: !island.modal
            onClicked: Ui.toggle("controlcenter", island.screenName)
        }

        Item {
            anchors.fill: parent
            clip: true

            BarContent {
                id: bar
                width: parent.width
                height: parent.height
                pw: island.cxp
                ph: island.cyp
                pr: island.wyp
                topAlpha: island.topAlpha
                screen: island.screen
                opacity: island.barAlpha
                visible: opacity > 0.001
                enabled: island.mode !== "panel"
            }

            PanelHost {
                id: host
                anchors.fill: parent
                panelId: island.shownId
            }
        }
    }
}
