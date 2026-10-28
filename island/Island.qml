import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.services
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
//
// Size per state comes from the layout (BarContent: Settings.islandLayout, the default is the
// video's 316 x 42 / 958 x 100), times Settings.islandScale (island only, panels keep theirs).
// Settings.islandMargin > 0 lets the island float below the edge as a pill. Hover delay,
// expand-on-click, click / middle-click / scroll actions: Settings.island* (Bar & Island page).
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

    // island-only scale and distance from the top edge
    readonly property real s: Math.max(0.5, Math.min(2, Settings.islandScale || 1))
    readonly property int margin: Math.max(0, Settings.islandMargin)
    // what the layer surface must hold (IslandWindow)
    readonly property real needWidth: Math.max(bar.wC, bar.wH) * s
    readonly property real needHeight: Math.max(bar.hC, bar.hH) * s + margin
    readonly property int zone: Math.round(bar.hC * s) + margin

    property bool pointerInside: false
    property bool clickOpen: false // expanded by a click (Settings.islandHoverExpand off)
    readonly property bool expanded: !bar.hoverEmpty && (Ui.forced === "hover" || (Ui.forced !== "collapsed" && ((Settings.islandHoverExpand && pointerInside) || clickOpen || bar.holdOpen || BarRegistry.peeking)))
    readonly property string mode: panel ? "panel" : expanded ? "hover" : "collapsed"
    onModeChanged: if (mode === "panel")
        clickOpen = false

    readonly property var target: {
        if (panel)
            return {
                "w": panel.preferredWidth,
                "h": panel.preferredHeight,
                "r": panel.cornerRadius
            };
        return expanded ? {
            "w": bar.wH * s,
            "h": bar.hH * s,
            "r": bar.rH * s
        } : {
            "w": bar.wC * s,
            "h": bar.hC * s,
            "r": bar.rC * s
        };
    }

    // click on the bar (children with own handlers win): Settings.islandClickAction, or expand
    // first when hover does not; middle click: Settings.islandMiddleClick
    function clicked(button: int): void {
        if (button === Qt.MiddleButton) {
            run(Settings.islandMiddleClick);
            return;
        }
        if (!Settings.islandHoverExpand && !expanded && !bar.hoverEmpty) {
            clickOpen = true;
            return;
        }
        run(Settings.islandClickAction);
    }
    function run(action: string): void {
        switch (action) {
        case "controlcenter":
        case "notifications":
        case "launcher":
        case "overview":
            Ui.toggle(action, screenName);
            return;
        case "playpause":
            if (Media.active)
                Media.toggle(Media.active);
            return;
        case "mute":
            {
                const a = Audio.sink?.audio;
                if (a && Exec.allow(`mute ${!a.muted}`))
                    a.muted = !a.muted;
                return;
            }
        }
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
        onTriggered: {
            island.pointerInside = false;
            island.clickOpen = false;
        }
    }
    // Settings.islandHoverDelay: the pointer rests this long before the island expands
    Timer {
        id: enterDelay
        interval: Math.max(0, Settings.islandHoverDelay)
        onTriggered: island.pointerInside = true
    }

    IslandShape {
        id: shape
        anchors.top: parent.top
        anchors.topMargin: island.margin
        anchors.horizontalCenter: parent.horizontalCenter
        width: island.bw
        height: island.bh
        radius: island.br
        floating: island.margin > 0

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leaveHold.stop();
                    if (Settings.islandHoverDelay > 0 && !island.pointerInside)
                        enterDelay.restart();
                    else
                        island.pointerInside = true;
                } else {
                    enterDelay.stop();
                    leaveHold.restart();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !island.modal
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => island.clicked(m.button)
        }

        Item {
            anchors.fill: parent
            clip: true

            BarContent {
                id: bar
                width: parent.width / island.s
                height: parent.height / island.s
                scale: island.s
                transformOrigin: Item.TopLeft
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
