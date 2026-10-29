import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.island.widgets

// Content of the island when no panel is shown, rendered from the layout
// (Settings.islandLayout via island/bar/BarRegistry.qml). One BarWidget per widget id;
// a widget in both states moves and scales between its collapsed and hover rest places,
// hover-only widgets fade in late, collapsed-only ones fade out early (BarWidget.qml).
// The default layout is the video's island, pixel for pixel.
//
// Driven by the island's content progress (Island.cxp/cyp/wyp, config/Motion.qml):
//   pw  horizontal progress (positions, clock size)   ph  vertical progress (rows, sizes)
//   pr  vertical progress of the workspace row (trails ph in both directions)
// While opening, the content trails the shape; while closing it moves with it.
// Shared widgets are placed relative to the island centre, independent of the animated
// body width (the body clips); hover-only widgets ride the edges or their neighbours.
//
// The settings editor renders the same component (preview: true, fixed progress, its own
// layout while dragging, ghostId drawn translucent).
Item {
    id: content

    property real pw: 0
    property real ph: 0
    property real pr: 0
    property real topAlpha: 0 // own animation in Island: late in, out at once
    property var screen: null
    property var layout: BarRegistry.layout
    property bool preview: false
    property string ghostId: ""
    readonly property bool holdOpen: (items["tray"]?.w?.openMenus ?? 0) > 0

    // rest places glide on layout changes, not while the first layout settles
    property bool animate: false
    Timer {
        running: true
        interval: 700
        onTriggered: content.animate = true
    }

    // ---- island size per state (BarRegistry: default size + content delta) ----------------
    readonly property real wC: stateWidth(layout, "collapsed")
    readonly property real wH: stateWidth(layout, "hover")
    readonly property real hC: BarRegistry.height(layout, "collapsed")
    readonly property real hH: BarRegistry.height(layout, "hover")
    readonly property real rC: BarRegistry.radius(layout, "collapsed")
    readonly property real rH: BarRegistry.radius(layout, "hover")
    readonly property bool hoverEmpty: BarRegistry.hoverRows(layout) === 0

    // ---- plans with the live widths of the widgets -----------------------------------------
    property var widths: ({})
    function report(id: string, wc: real, wh: real): void {
        const cur = widths[id];
        if (cur && cur[0] === wc && cur[1] === wh)
            return;
        const n = Object.assign({}, widths);
        n[id] = [wc, wh];
        widths = n;
    }
    function widthOf(id: string, state: string): real {
        if (id === "spacer")
            return Settings.islandSpacerWidth;
        const w = widths[id];
        return w ? w[state === "collapsed" ? 0 : 1] : BarRegistry.reserve(id, state, BarRegistry.opts(false));
    }
    // default size + content delta (BarRegistry), widened when what shows needs more air
    // (never for the default layout: the video's widths stay exact)
    function stateWidth(lay: var, state: string): real {
        const base = BarRegistry.width(lay, state);
        if (BarRegistry.isDefaultLayout(lay) || (state === "hover" && BarRegistry.hoverRows(lay) === 0))
            return base;
        return Math.min(Theme.widgets.maxWidth, Math.max(base, BarRegistry.liveMinWidth(lay, state, (id, s) => content.widthOf(id, s))));
    }
    function planFor(lay: var, state: string): var {
        return BarRegistry.lib().plan(lay, state, BarRegistry.env((id, s) => content.widthOf(id, s)), stateWidth(lay, state));
    }
    readonly property var planC: planFor(layout, "collapsed")
    readonly property var planH: planFor(layout, "hover")

    // ---- live widgets (followers ride their neighbours) ---------------------------------------
    property var items: ({})
    function register(id: string, item: Item): void {
        const n = Object.assign({}, items);
        n[id] = item;
        items = n;
    }
    function unregister(id: string, item: Item): void {
        if (items[id] !== item)
            return;
        const n = Object.assign({}, items);
        delete n[id];
        items = n;
    }

    // whom a widget shown in one state only rides: the nearest widget shown in both states
    // toward its slot's edge (in the centre: either side, the left first; the date rides the
    // clock), else nobody (it rides the island edge / the centre). Never another one-state
    // widget, so no chain of riders can loop while a plan changes.
    //   { key, side: "after" (rides on its right) | "before", offset: planned distance }
    function followTarget(state: string, key: string): var {
        const p = state === "collapsed" ? planC : planH;
        const other = state === "collapsed" ? planH : planC;
        const it = p.items[key];
        if (!it)
            return null;
        const walk = (dir, side) => {
            let k = it[dir];
            let adjacent = true;
            while (k) {
                const n = p.items[k];
                if (!n)
                    return null;
                if (other.items[k])
                    return {
                        "key": k,
                        "side": side,
                        // exact gap for a direct neighbour (the video's tray / date offsets)
                        "offset": adjacent ? (side === "after" ? it.lead : it.trail) : side === "after" ? it.x - (n.x + n.w) : n.x - (it.x + it.w)
                    };
                adjacent = false;
                k = n[dir];
            }
            return null;
        };
        if (it.col === "left")
            return walk("prev", "after");
        if (it.col === "right")
            return walk("next", "before");
        return walk("prev", "after") ?? walk("next", "before");
    }

    // visible widget under a point (bar coordinates)
    function widgetAt(px: real, py: real): var {
        for (const id in items) {
            const it = items[id];
            if (!it.shown || it.fills)
                continue;
            if (px >= it.hitX - 6 && px <= it.hitX + it.hitW + 6 && py >= it.hitY - 6 && py <= it.hitY + it.hitH + 6)
                return it;
        }
        return null;
    }

    // ---- scroll: on the volume glyph always volume, elsewhere Settings.islandScrollAction ------
    function scrolled(dy: real, px: real, py: real): void {
        if (dy === 0)
            return;
        const it = widgetAt(px, py);
        const action = it && it.w && it.w.wantsVolumeScroll ? "volume" : Settings.islandScrollAction;
        if (action === "volume") {
            Audio.step(dy > 0 ? 0.05 : -0.05);
        } else if (action === "workspaces") {
            const cur = Hypr.activeFor(content.screen);
            const next = Math.max(1, Math.min(Hypr.count, cur + (dy > 0 ? -1 : 1)));
            if (next !== cur)
                Hypr.focus(next);
        }
    }
    WheelHandler {
        enabled: !content.preview
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => content.scrolled(e.angleDelta.y, point.position.x, point.position.y)
    }

    // ---- widgets ------------------------------------------------------------------------------
    Repeater {
        model: BarRegistry.widgets.filter(w => w.id !== "spacer")

        BarWidget {
            bar: content
        }
    }

    readonly property var components: ({
            "workspaces": cWorkspaces,
            "clock": cClock,
            "date": cDate,
            "window": cWindow,
            "media": cMedia,
            "notifications": cNotifications,
            "network": cNetwork,
            "volume": cVolume,
            "tray": cTray,
            "settings": cSettings,
            "power": cPower,
            "battery": cBattery,
            "weather": cWeather,
            "cpu": cCpu,
            "ram": cRam,
            "keyboard": cKeyboard,
            "gpu": cGpu,
            "temps": cTemps,
            "netspeed": cNetSpeed,
            "updates": cUpdates,
            "screenshot": cScreenshot,
            "colorpicker": cColorPicker,
            "launcher": cLauncher,
            "overview": cOverview,
            "privacy": cPrivacy
        })

    Component {
        id: cWorkspaces
        Workspaces {
            style: Settings.islandWorkspaceStyle
        }
    }
    Component {
        id: cClock
        ClockWidget {}
    }
    Component {
        id: cDate
        DateWidget {}
    }
    Component {
        id: cWindow
        WindowLabel {}
    }
    Component {
        id: cMedia
        MediaLabel {
            onOpenRequested: Ui.open("media", content.screen ? content.screen.name : undefined)
        }
    }
    Component {
        id: cNotifications
        NotifStatus {
            onOpenRequested: Ui.open("notifications", content.screen ? content.screen.name : undefined)
        }
    }
    Component {
        id: cNetwork
        NetworkWidget {}
    }
    Component {
        id: cVolume
        VolumeWidget {}
    }
    Component {
        id: cTray
        TrayRow {}
    }
    Component {
        id: cSettings
        SystemButton {
            kind: "settings"
        }
    }
    Component {
        id: cPower
        SystemButton {
            kind: "power"
        }
    }
    Component {
        id: cBattery
        BatteryWidget {}
    }
    Component {
        id: cWeather
        WeatherWidget {}
    }
    Component {
        id: cCpu
        SysmonWidget {
            kind: "cpu"
        }
    }
    Component {
        id: cRam
        SysmonWidget {
            kind: "ram"
        }
    }
    Component {
        id: cKeyboard
        KeyboardWidget {}
    }

    // ---- bar info + tools (palette only) ----
    Component {
        id: cGpu
        GpuWidget {}
    }
    Component {
        id: cTemps
        TempWidget {}
    }
    Component {
        id: cNetSpeed
        NetSpeedWidget {}
    }
    Component {
        id: cUpdates
        UpdatesWidget {}
    }
    Component {
        id: cScreenshot
        ToolButton {
            kind: "screenshot"
        }
    }
    Component {
        id: cColorPicker
        ToolButton {
            kind: "colorpicker"
        }
    }
    Component {
        id: cLauncher
        ToolButton {
            kind: "launcher"
        }
    }
    Component {
        id: cOverview
        ToolButton {
            kind: "overview"
        }
    }
    Component {
        id: cPrivacy
        PrivacyWidget {}
    }
}
