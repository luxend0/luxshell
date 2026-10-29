import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.apps.settings
import qs.apps.settings.displays

// System > Displays, the visual variant: the display drawn large on top (two or more: an
// arrangement canvas to drag them around, click to pick one, main display marked), under it
// the picked display's mode as chips and segment bars instead of dropdowns:
//   resolutions as chips, the refresh rates of that resolution as a segment bar, the scale as a
//   stepped slider over only the values Hyprland keeps (logical size a whole number of pixels,
//   live "looks like 2048 × 1152"), rotation as four small monitors, VRR, colour (8 bit /
//   10 bit / HDR, offered only when the EDID says so: services/DisplayCaps), mirror, on/off
//   (the last display that is on stays on). Then brightness (DDC/CI, services/Brightness) and
//   night light (services/NightLight).
// Every display change goes live through services/HyprSystem inside begin() .. commit(), with
// the "Keep this display setting?" countdown (15 s, Esc / timeout = rollback). A change of
// size moves the displays right of / below it along, so the arrangement keeps no gaps.
// Test data: LUXSHELL_FAKE_MONITORS=<file> (a `hyprctl monitors all -j` dump) is shown instead
// of the live list; changes still go to the compositor qs runs in (the sandbox).
SettingsPage {
    id: page

    pageId: "displays"
    group: "system"
    title: "Displays"
    subtitle: "Arrangement, resolution, refresh rate and scale. Each change asks before it stays."
    icon: 0xF0379 // md-monitor

    // ---- data ------------------------------------------------------------------------------
    readonly property string fakeFile: Env.get("LUXSHELL_FAKE_MONITORS")
    property var fake: null
    FileView {
        path: page.fakeFile
        printErrors: false
        onLoaded: {
            try {
                page.fake = JSON.parse(text());
            } catch (e) {
                console.warn(`luxshell: LUXSHELL_FAKE_MONITORS: no JSON (${e})`);
            }
        }
    }
    readonly property var mons: fake ?? HyprSystem.monitors
    readonly property var list: mons.map(m => page.view(m))
    readonly property var layout: list.filter(v => !v.disabled && v.mirror === "" && v.lw > 0)
    readonly property bool multi: mons.length >= 2
    readonly property string main: HyprSystem.current("cursor.default_monitor")

    property string chosen: ""
    readonly property string sel: {
        if (chosen !== "" && list.some(v => v.name === chosen))
            return chosen;
        const f = list.find(v => v.focused && !v.disabled) ?? list.find(v => !v.disabled) ?? list[0];
        return f ? f.name : "";
    }
    readonly property var cur: list.find(v => v.name === sel) ?? null
    property var preview: null // { name, scale } while the scale slider is dragged / hovered

    function select(name: string): void {
        chosen = name;
    }

    // the page shows: read what changes outside (hotplug, brightness, wlsunset), slowly
    Timer {
        running: SettingsApp.open && SettingsApp.page === page.pageId
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: {
            HyprSystem.refreshMonitors();
            DisplayCaps.refresh();
            Brightness.refresh(false);
            NightLight.refresh();
        }
    }
    Timer {
        id: reread
        interval: 900
        onTriggered: HyprSystem.refreshMonitors()
    }

    // ---- one display as the page sees it -------------------------------------------------------
    readonly property var common: [[3840, 2160], [2560, 1440], [1920, 1200], [1920, 1080], [1680, 1050], [1600, 900], [1440, 900], [1366, 768], [1280, 1024], [1280, 720]]

    function parseMode(s: var): var {
        const r = /^(\d+)x(\d+)(?:@([\d.]+))?/.exec(String(s ?? ""));
        return r ? {
            "w": +r[1],
            "h": +r[2],
            "hz": r[3] ? +r[3] : 0
        } : null;
    }
    function hasOwn(o: var, k: string): bool {
        return o !== null && o !== undefined && Object.prototype.hasOwnProperty.call(o, k);
    }
    function own(name: string, field: string): bool {
        return hasOwn(HyprSystem.data.monitor?.[name], field);
    }
    // hyprctl entry + what luxshell set (HyprSystem.monitorSpec: base + override)
    function view(m: var): var {
        const s = HyprSystem.monitorSpec(m.name);
        const md = parseMode(s.mode) ?? {
            "w": m.width,
            "h": m.height,
            "hz": m.refreshRate
        };
        if (!md.hz)
            md.hz = m.refreshRate;
        const p = /^(-?\d+)x(-?\d+)$/.exec(String(s.position ?? ""));
        const scale = Number(s.scale) > 0 ? Number(s.scale) : (m.scale > 0 ? m.scale : 1);
        const tf = s.transform !== undefined ? Number(s.transform) : (m.transform ?? 0);
        const swap = tf % 2 === 1;
        // hyprctl names the mirrored display by id
        const mo = String(m.mirrorOf ?? "none");
        const mirror = s.mirror !== undefined && s.mirror !== null ? String(s.mirror) : (mo !== "none" && mo !== "" ? (mons.find(x => String(x.id) === mo)?.name ?? mo) : "");
        const cm = s.cm !== undefined ? String(s.cm) : String(m.colorManagementPreset ?? "srgb");
        const depth = s.bitdepth !== undefined ? Number(s.bitdepth) : (/2101010|16161616/.test(String(m.currentFormat ?? "")) ? 10 : 8);
        const modes = Array.from(m.availableModes ?? []);
        const native = parseMode(modes[0]);
        const mm = Math.hypot(m.physicalWidth ?? 0, m.physicalHeight ?? 0);
        return {
            "name": m.name,
            "label": [m.make, m.model].filter(x => x && x !== "").join(" ") || m.name,
            "virtual": /^(HEADLESS|WAYLAND|X11)-/.test(m.name) || modes.length === 0,
            "w": md.w,
            "h": md.h,
            "hz": md.hz,
            "scale": scale,
            "transform": tf,
            "x": p ? +p[1] : m.x,
            "y": p ? +p[2] : m.y,
            "lw": md.w > 0 ? Math.round((swap ? md.h : md.w) / scale) : 0,
            "lh": md.h > 0 ? Math.round((swap ? md.w : md.h) / scale) : 0,
            "vrr": s.vrr !== undefined ? Number(s.vrr) : Number(HyprSystem.current("misc.vrr")),
            "colour": cm === "hdr" || cm === "hdredid" ? "hdr" : depth >= 10 ? "10" : "8",
            "mirror": mirror,
            "disabled": s.disabled !== undefined ? !!s.disabled : !!m.disabled,
            "focused": !!m.focused,
            "modes": modes,
            "native": native && !/^(HEADLESS|WAYLAND|X11)-/.test(m.name) ? `${native.w}x${native.h}` : "",
            "inches": mm > 0 ? Math.round(mm / 25.4 * 10) / 10 : 0
        };
    }
    // what a reset of the display gives back (the rule before luxshell, else what it shows now)
    function baseView(name: string): var {
        const b = HyprSystem.base.monitor?.[name];
        const v = list.find(x => x.name === name);
        const md = parseMode(b?.mode);
        return {
            "w": md ? md.w : v?.w ?? 0,
            "h": md ? md.h : v?.h ?? 0,
            "hz": md && md.hz ? md.hz : v?.hz ?? 0,
            "scale": b && Number(b.scale) > 0 ? Number(b.scale) : v?.scale ?? 1,
            "transform": b && b.transform !== undefined ? Number(b.transform) : v?.transform ?? 0
        };
    }

    // ---- words ---------------------------------------------------------------------------------
    function fmtHz(r: real): string {
        const t = Math.round(r * 100) / 100;
        return Number.isInteger(t) ? String(t) : t.toFixed(2);
    }
    function pct(s: real): string {
        return `${Math.round(s * 100)} %`;
    }
    function aspect(w: int, h: int): string {
        if (w <= 0 || h <= 0)
            return "";
        const r = w / h;
        const known = [[16, 9], [16, 10], [4, 3], [5, 4], [3, 2], [32, 9], [1, 1]];
        for (const [a, b] of known)
            if (Math.abs(r - a / b) < 0.012)
                return `${a}:${b}`;
        if (r > 2.3 && r < 2.42)
            return "21:9";
        const gcd = (x, y) => y === 0 ? x : gcd(y, x % y);
        const g = gcd(w, h);
        return `${w / g}:${h / g}`;
    }
    function rotationName(t: int): string {
        return ["Landscape", "Portrait", "Landscape, flipped", "Portrait, flipped"][t % 4] + (t >= 4 ? " (mirrored)" : "");
    }

    // ---- what can be picked ------------------------------------------------------------------------
    // resolutions, biggest first: [{ w, h, rates (ascending) }]. Virtual outputs (headless,
    // nested) take any mode: the common sizes at 60 Hz.
    function modesOf(v: var): var {
        if (!v)
            return [];
        const map = {};
        const add = (w, h, hz) => {
            const k = `${w}x${h}`;
            if (!map[k])
                map[k] = {
                    "w": w,
                    "h": h,
                    "rates": []
                };
            const r = Math.round(hz * 100) / 100;
            if (r > 0 && !map[k].rates.some(x => Math.abs(x - r) < 0.005))
                map[k].rates.push(r);
        };
        for (const s of v.modes) {
            const r = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
            if (r)
                add(+r[1], +r[2], +r[3]);
        }
        if (v.virtual)
            for (const [w, h] of common)
                add(w, h, 60);
        if (v.w > 0)
            add(v.w, v.h, v.hz);
        const out = Object.values(map);
        out.forEach(o => o.rates.sort((a, b) => a - b));
        out.sort((a, b) => b.w * b.h - a.w * a.h || b.w - a.w);
        return out;
    }
    function ratesOf(v: var, w: int, h: int): var {
        return modesOf(v).find(o => o.w === w && o.h === h)?.rates ?? [];
    }
    // Scales Hyprland keeps as they are: it rounds every scale to n/120 and takes it only when
    // width / scale and height / scale are whole pixels (otherwise it picks a neighbour and
    // complains). Same double maths as Hyprland's check, 100 % .. 300 %.
    function scalesFor(w: int, h: int): var {
        const out = [];
        for (let n = 120; n <= 360; n++) {
            const s = n / 120;
            const a = w / s, b = h / s;
            if (a === Math.round(a) && b === Math.round(b))
                out.push(HyprSystem.round(s));
        }
        return out.length > 0 ? out : [1];
    }
    function nearest(list: var, x: real): real {
        return list.reduce((a, b) => Math.abs(b - x) < Math.abs(a - x) ? b : a, list[0]);
    }
    function logical(w: int, h: int, scale: real, tf: int): var {
        const swap = tf % 2 === 1;
        return {
            "w": Math.round((swap ? h : w) / scale),
            "h": Math.round((swap ? w : h) / scale)
        };
    }

    // ---- changes (all through "Keep this display setting?") ---------------------------------------
    function apply(changes: var, text: string): void {
        if (Object.keys(changes).length === 0)
            return;
        HyprSystem.begin();
        for (const o in changes) {
            undoFirst(o);
            HyprSystem.setMonitor(o, changes[o]);
        }
        SettingsApp.askKeep({
            "title": "Keep this display setting?",
            "text": text,
            "icon": 0xF0379,
            "keep": () => {
                HyprSystem.commit();
                reread.restart();
            },
            "revert": () => {
                HyprSystem.rollback();
                reread.restart();
            }
        });
        reread.restart();
    }
    // Hyprland leaves a display off / mirrored when a rule just lacks `disabled` / `mirror`:
    // the rollback rule of a display says both outright (noted before HyprSystem notes its own)
    function explicitSpec(name: string, spec: var): var {
        const v = list.find(x => x.name === name);
        return Object.assign({}, spec, {
            "disabled": v ? v.disabled : false,
            "mirror": v ? v.mirror : ""
        });
    }
    function undoFirst(name: string): void {
        if (liveOf(name))
            HyprSystem.noteUndo("monitor:" + name, HyprSystem.monitorLua(name, explicitSpec(name, HyprSystem.monitorSpec(name))));
    }
    function liveOf(name: string): var {
        return mons.find(m => m.name === name) ?? null;
    }
    // where a display that comes back (on again, own picture again) goes: right of the others
    function freeSpot(): string {
        if (layout.length === 0)
            return "0x0";
        return `${Math.max(...layout.map(o => o.x + o.lw))}x${Math.min(...layout.map(o => o.y))}`;
    }
    // the displays at or past the right / bottom edge of `name` move along when it changes size
    function reflow(name: string, nlw: int, nlh: int): var {
        const out = {};
        const v = layout.find(x => x.name === name);
        if (!v)
            return out;
        const dw = nlw - v.lw, dh = nlh - v.lh;
        for (const o of layout) {
            if (o.name === name)
                continue;
            let x = o.x, y = o.y;
            if (dw !== 0 && o.x >= v.x + v.lw)
                x += dw;
            if (dh !== 0 && o.y >= v.y + v.lh)
                y += dh;
            if (x !== o.x || y !== o.y)
                out[o.name] = {
                    "position": `${x}x${y}`
                };
        }
        return out;
    }
    function setMode(w: int, h: int, hz: real): void {
        const v = cur;
        if (!v)
            return;
        const fields = {
            "mode": `${w}x${h}@${HyprSystem.hz(hz)}`
        };
        let scale = v.scale;
        const ok = scalesFor(w, h);
        if (!ok.some(s => Math.abs(s - scale) < 0.0005)) {
            scale = nearest(ok, scale);
            fields.scale = scale;
        }
        const l = logical(w, h, scale, v.transform);
        const changes = reflow(v.name, l.w, l.h);
        changes[v.name] = fields;
        apply(changes, `${v.label}: ${w} × ${h} at ${fmtHz(hz)} Hz` + (fields.scale ? `, scale ${pct(scale)}` : ""));
    }
    function setResolution(w: int, h: int): void {
        const v = cur;
        if (!v || (w === v.w && h === v.h))
            return;
        const rates = ratesOf(v, w, h);
        const same = rates.find(r => Math.abs(r - v.hz) < 0.5);
        setMode(w, h, same ?? (rates.length > 0 ? rates[rates.length - 1] : 60));
    }
    function setRate(hz: real): void {
        const v = cur;
        if (v && Math.abs(hz - v.hz) > 0.004)
            setMode(v.w, v.h, hz);
    }
    function setScale(s: real): void {
        const v = cur;
        if (!v || Math.abs(s - v.scale) < 0.0005)
            return;
        const l = logical(v.w, v.h, s, v.transform);
        const changes = reflow(v.name, l.w, l.h);
        changes[v.name] = {
            "scale": HyprSystem.round(s)
        };
        apply(changes, `${v.label}: scale ${pct(s)}, looks like ${l.w} × ${l.h}`);
    }
    function setTransform(t: int): void {
        const v = cur;
        if (!v || t === v.transform)
            return;
        const l = logical(v.w, v.h, v.scale, t);
        const changes = reflow(v.name, l.w, l.h);
        changes[v.name] = {
            "transform": t
        };
        apply(changes, `${v.label}: ${rotationName(t).toLowerCase()} (${(t % 4) * 90}°)`);
    }
    function setVrr(n: int): void {
        const v = cur;
        if (!v || n === v.vrr)
            return;
        apply({
            [v.name]: {
                "vrr": n
            }
        }, `${v.label}: variable refresh rate ${["off", "on", "in fullscreen only"][n] ?? n}`);
    }
    function setColour(c: string): void {
        const v = cur;
        if (!v || c === v.colour)
            return;
        const f = c === "hdr" ? {
            "bitdepth": 10,
            "cm": "hdr"
        } : c === "10" ? {
            "bitdepth": 10,
            "cm": null
        } : {
            "bitdepth": null,
            "cm": null
        };
        apply({
            [v.name]: f
        }, `${v.label}: ${c === "hdr" ? "HDR (10 bit)" : c === "10" ? "10 bit colour" : "8 bit colour"}`);
    }
    function setMirror(target: string): void {
        const v = cur;
        if (!v || target === v.mirror)
            return;
        const changes = target !== "" ? reflow(v.name, 0, 0) : {};
        changes[v.name] = target !== "" ? {
            "mirror": target
        } : {
            "mirror": "",
            "position": freeSpot()
        };
        const t = list.find(x => x.name === target);
        apply(changes, target !== "" ? `${v.label} shows ${t ? t.label : target}` : `${v.label}: own picture again`);
    }
    readonly property int onCount: list.filter(v => !v.disabled).length
    function canTurnOff(v: var): bool {
        return v !== null && (v.disabled || onCount > 1);
    }
    function setEnabled(on: bool): void {
        const v = cur;
        if (!v || on === !v.disabled || (!on && !canTurnOff(v)))
            return;
        if (on) {
            const f = {
                "disabled": false,
                "position": freeSpot()
            };
            if (v.w <= 0)
                f.mode = "preferred";
            apply({
                [v.name]: f
            }, `${v.label}: on`);
        } else {
            const changes = reflow(v.name, 0, 0);
            changes[v.name] = {
                "disabled": true
            };
            apply(changes, `${v.label}: off`);
        }
    }
    // drag on the canvas ended at x, y (logical px): next to another display, no overlap, the
    // whole arrangement starting at 0, 0
    function drop(name: string, x: real, y: real): void {
        const v = layout.find(o => o.name === name);
        if (!v)
            return;
        const p = settle(name, Math.round(x), Math.round(y));
        const pos = {};
        for (const o of layout)
            pos[o.name] = o.name === name ? p : {
                "x": o.x,
                "y": o.y
            };
        const all = Object.values(pos);
        const minX = Math.min(...all.map(q => q.x)), minY = Math.min(...all.map(q => q.y));
        const changes = {};
        for (const o of layout) {
            const nx = pos[o.name].x - minX, ny = pos[o.name].y - minY;
            if (nx !== o.x || ny !== o.y)
                changes[o.name] = {
                    "position": `${nx}x${ny}`
                };
        }
        const q = changes[name]?.position ?? `${v.x}x${v.y}`;
        apply(changes, `${v.label} moved to ${q.replace("x", ", ")}`);
    }
    function overlaps(name: string, x: real, y: real, w: real, h: real): bool {
        return layout.some(o => o.name !== name && x < o.x + o.lw && x + w > o.x && y < o.y + o.lh && y + h > o.y);
    }
    function touches(name: string, x: real, y: real, w: real, h: real): bool {
        return layout.some(o => o.name !== name && (((x + w === o.x || o.x + o.lw === x) && y < o.y + o.lh && y + h > o.y) || ((y + h === o.y || o.y + o.lh === y) && x < o.x + o.lw && x + w > o.x)));
    }
    function settle(name: string, x: int, y: int): var {
        const v = layout.find(o => o.name === name);
        const others = layout.filter(o => o.name !== name);
        if (!v || others.length === 0)
            return {
                "x": x,
                "y": y
            };
        const w = v.lw, h = v.lh;
        if (!overlaps(name, x, y, w, h) && touches(name, x, y, w, h))
            return {
                "x": x,
                "y": y
            };
        // per neighbour the side the display was dropped on (centre to centre, relative to their
        // sizes) comes first, the other three sides after it; then the nearest place wins
        const clamp = (a, lo, hi) => Math.max(lo, Math.min(hi, a));
        const cx = x + w / 2, cy = y + h / 2;
        let best = null, bd = Infinity;
        for (const o of others) {
            const ry = clamp(y, o.y - h + 1, o.y + o.lh - 1), rx = clamp(x, o.x - w + 1, o.x + o.lw - 1);
            const dxn = (cx - (o.x + o.lw / 2)) / ((w + o.lw) / 2), dyn = (cy - (o.y + o.lh / 2)) / ((h + o.lh) / 2);
            const side = Math.abs(dxn) >= Math.abs(dyn) ? (dxn < 0 ? 0 : 1) : (dyn < 0 ? 2 : 3);
            const places = [[o.x - w, ry], [o.x + o.lw, ry], [rx, o.y - h], [rx, o.y + o.lh]];
            for (let i = 0; i < 4; i++) {
                const c = places[i];
                if (overlaps(name, c[0], c[1], w, h))
                    continue;
                const dist = Math.hypot(c[0] - x, c[1] - y) + (i === side ? 0 : 1e6);
                if (dist < bd) {
                    bd = dist;
                    best = {
                        "x": c[0],
                        "y": c[1]
                    };
                }
            }
        }
        return best ?? {
            "x": v.x,
            "y": v.y
        };
    }
    function arranged(): bool {
        return layout.some(v => own(v.name, "position") && HyprSystem.base.monitor?.[v.name]?.position !== HyprSystem.data.monitor[v.name].position);
    }
    function resetArrangement(): void {
        const changes = {};
        for (const v of list)
            if (own(v.name, "position"))
                changes[v.name] = {
                    "position": null
                };
        apply(changes, "Arrangement as before");
    }
    function setMain(name: string): void {
        if (name === "" || name === main)
            HyprSystem.reset("cursor.default_monitor");
        else
            HyprSystem.set("cursor.default_monitor", name);
    }
    // a field of the picked display back to the rule it had before luxshell
    function resetFields(fields: var, what: string): void {
        const v = cur;
        if (!v)
            return;
        const f = {};
        for (const k of fields)
            if (own(v.name, k))
                f[k] = null;
        if (Object.keys(f).length === 0)
            return;
        apply({
            [v.name]: f
        }, `${v.label}: ${what} as before`);
    }
    // the mode as before; the scale too when Hyprland would not keep it at that size
    function resetResolution(): void {
        const v = cur;
        if (!v)
            return;
        const b = baseView(v.name);
        const fields = ["mode"];
        if (!scalesFor(b.w, b.h).some(s => Math.abs(s - v.scale) < 0.0005))
            fields.push("scale");
        resetFields(fields, "resolution");
    }
    // everything luxshell set for every display ("Reset page")
    function resetAll(): void {
        const names = Object.keys(HyprSystem.data.monitor ?? {});
        if (names.length > 0) {
            HyprSystem.begin();
            for (const n of names) {
                const v = list.find(x => x.name === n);
                const back = HyprSystem.base.monitor?.[n];
                undoFirst(n);
                HyprSystem.resetMonitor(n);
                if (v && back && (v.disabled || v.mirror !== ""))
                    HyprSystem.push(HyprSystem.monitorLua(n, Object.assign({}, back, {
                        "disabled": false,
                        "mirror": ""
                    })), `monitor ${n} on, own picture`);
            }
            SettingsApp.askKeep({
                "title": "Keep the displays as before?",
                "text": names.join(", ") + ": back to the Hyprland config",
                "icon": 0xF0379,
                "keep": () => {
                    HyprSystem.commit();
                    reread.restart();
                },
                "revert": () => {
                    HyprSystem.rollback();
                    reread.restart();
                }
            });
            reread.restart();
        }
        if (HyprSystem.isSet("cursor.default_monitor"))
            HyprSystem.reset("cursor.default_monitor");
    }

    // ---- rows ------------------------------------------------------------------------------------
    Component {
        id: stageComp
        Stage {
            ctl: page
        }
    }
    Component {
        id: resComp
        ResolutionChips {
            ctl: page
        }
    }
    Component {
        id: segBlock
        SegBlock {}
    }
    Component {
        id: segLine
        SegLine {}
    }
    Component {
        id: scaleComp
        ScaleSteps {
            ctl: page
        }
    }
    Component {
        id: rotationComp
        RotationPicker {
            ctl: page
        }
    }
    Component {
        id: brightnessComp
        BrightnessList {
            ctl: page
        }
    }
    Component {
        id: note
        Note {}
    }

    readonly property var stageSection: ({
            "title": "",
            "options": [
                {
                    "id": "displayStage",
                    "kind": "custom",
                    "label": "",
                    "keywords": "display monitor screen arrangement arrange position layout drag move main primary",
                    "component": stageComp,
                    "modified": () => Object.keys(HyprSystem.data.monitor ?? {}).length > 0 || HyprSystem.isSet("cursor.default_monitor"),
                    "reset": () => page.resetAll()
                }
            ]
        })

    readonly property var modeSection: ({
            "title": "Mode",
            "options": [
                {
                    "id": "displayResolution",
                    "kind": "custom",
                    "label": "Resolution",
                    "keywords": "display monitor resolution size pixels mode 1080p 1440p 4k",
                    "component": resComp,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "summary": () => page.cur ? `${page.cur.w} × ${page.cur.h}` : "",
                    "modified": () => {
                        const v = page.cur;
                        if (!v || !page.own(v.name, "mode"))
                            return false;
                        const b = page.baseView(v.name);
                        return b.w !== v.w || b.h !== v.h;
                    },
                    "reset": () => page.resetResolution()
                },
                {
                    "id": "displayRate",
                    "kind": "custom",
                    "label": "Refresh rate",
                    "keywords": "display monitor refresh rate hz hertz fps frequency 144 165 180",
                    "component": segBlock,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "items": () => page.cur ? page.ratesOf(page.cur, page.cur.w, page.cur.h).map(r => ({
                                "value": r,
                                "label": page.fmtHz(r)
                            })) : [],
                    "value": () => {
                        const v = page.cur;
                        if (!v)
                            return 0;
                        const rates = page.ratesOf(v, v.w, v.h);
                        return rates.find(r => Math.abs(r - v.hz) < 0.05) ?? page.nearest(rates, v.hz);
                    },
                    "set": hz => page.setRate(hz),
                    "summary": () => page.cur ? `${page.fmtHz(page.cur.hz)} Hz` : "",
                    "modified": () => {
                        const v = page.cur;
                        if (!v || !page.own(v.name, "mode"))
                            return false;
                        const b = page.baseView(v.name);
                        return b.w === v.w && b.h === v.h && Math.abs(b.hz - v.hz) > 0.05;
                    },
                    "reset": () => page.resetFields(["mode"], "refresh rate")
                },
                {
                    "id": "displayScale",
                    "kind": "custom",
                    "label": "Scale",
                    "keywords": "display monitor scale scaling zoom dpi hidpi size text bigger smaller fractional",
                    "component": scaleComp,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "modified": () => {
                        const v = page.cur;
                        return v !== null && page.own(v.name, "scale") && Math.abs(page.baseView(v.name).scale - v.scale) > 0.0005;
                    },
                    "reset": () => page.resetFields(["scale"], "scale")
                }
            ]
        })

    readonly property var pictureSection: ({
            "title": "Picture",
            "options": [
                {
                    "id": "displayRotation",
                    "kind": "custom",
                    "label": "Rotation",
                    "keywords": "display monitor rotation rotate orientation portrait landscape transform flip",
                    "component": rotationComp,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "summary": () => page.cur ? page.rotationName(page.cur.transform) : "",
                    "modified": () => page.cur !== null && page.own(page.cur.name, "transform") && page.baseView(page.cur.name).transform !== page.cur.transform,
                    "reset": () => page.resetFields(["transform"], "rotation")
                },
                {
                    "id": "displayVrr",
                    "kind": "custom",
                    "label": "",
                    "title": "Variable refresh rate",
                    "keywords": "display monitor vrr adaptive sync freesync gsync g-sync variable refresh tearing games",
                    "component": segLine,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "note": () => {
                        const c = page.cur ? DisplayCaps.of(page.cur.name) : null;
                        if (!c)
                            return "";
                        return c.vrr ? `${c.vrrMin}–${c.vrrMax} Hz, adaptive sync` : (c.vrrMax > 0 ? `${c.vrrMin}–${c.vrrMax} Hz, no adaptive sync reported` : "");
                    },
                    "items": () => [
                        {
                            "value": 0,
                            "label": "Off"
                        },
                        {
                            "value": 1,
                            "label": "On"
                        },
                        {
                            "value": 2,
                            "label": "Fullscreen"
                        }
                    ],
                    "value": () => page.cur ? Math.max(0, Math.min(2, page.cur.vrr)) : 0,
                    "set": n => page.setVrr(n),
                    "modified": () => page.cur !== null && page.own(page.cur.name, "vrr"),
                    "reset": () => page.resetFields(["vrr"], "variable refresh rate")
                },
                {
                    "id": "displayColour",
                    "kind": "custom",
                    "label": "",
                    "title": "Colour",
                    "keywords": "display monitor colour color 10 bit bitdepth depth hdr high dynamic range wide gamut",
                    "component": segLine,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "note": () => {
                        const c = page.cur ? DisplayCaps.of(page.cur.name) : null;
                        if (!c)
                            return page.cur?.virtual ? "Virtual output, no EDID" : "The display reports no 10 bit or HDR";
                        const parts = [c.bpc > 0 ? `${c.bpc} bit panel` : ""];
                        if (c.hdr)
                            parts.push(c.maxNits > 0 ? `HDR up to ${c.maxNits} nits` : "HDR");
                        else if (c.bpc < 10)
                            parts.push("no 10 bit or HDR reported");
                        return parts.filter(p => p !== "").join(", ");
                    },
                    "items": () => {
                        const v = page.cur;
                        const c = v ? DisplayCaps.of(v.name) : null;
                        const out = [
                            {
                                "value": "8",
                                "label": "8 bit"
                            }
                        ];
                        if ((c && c.bpc >= 10) || v?.colour === "10")
                            out.push({
                                "value": "10",
                                "label": "10 bit"
                            });
                        if ((c && c.hdr) || v?.colour === "hdr")
                            out.push({
                                "value": "hdr",
                                "label": "HDR"
                            });
                        return out;
                    },
                    "value": () => page.cur ? page.cur.colour : "8",
                    "set": c => page.setColour(c),
                    "modified": () => page.cur !== null && (page.own(page.cur.name, "bitdepth") || page.own(page.cur.name, "cm")),
                    "reset": () => page.resetFields(["bitdepth", "cm"], "colour")
                }
            ].concat(page.multi ? [
                {
                    "id": "displayMirror",
                    "kind": "custom",
                    "label": "",
                    "title": "Mirror",
                    "keywords": "display monitor mirror duplicate clone same picture projector",
                    "component": segLine,
                    "enabled": () => page.cur !== null && !page.cur.disabled,
                    "note": () => page.cur && page.cur.mirror !== "" ? "Shows the picture of another display" : "",
                    "items": () => [
                        {
                            "value": "",
                            "label": "Off"
                        }
                    ].concat(page.list.filter(v => page.cur && v.name !== page.cur.name && !v.disabled && v.mirror === "").map(v => ({
                                "value": v.name,
                                "label": v.name
                            }))),
                    "value": () => page.cur ? page.cur.mirror : "",
                    "set": t => page.setMirror(t),
                    "modified": () => page.cur !== null && page.own(page.cur.name, "mirror") && page.cur.mirror !== "",
                    "reset": () => page.setMirror("")
                }
            ] : []).concat([
                {
                    "id": "displayOn",
                    "kind": "switch",
                    "label": "Use this display",
                    "keywords": "display monitor on off enable disable turn off",
                    "enabled": () => page.canTurnOff(page.cur),
                    "value": () => page.cur !== null && !page.cur.disabled,
                    "set": on => page.setEnabled(on),
                    "modified": () => page.cur !== null && page.own(page.cur.name, "disabled") && page.cur.disabled,
                    "reset": () => page.setEnabled(true),
                    "defaultValue": () => true
                }
            ])
        })

    readonly property var lightSection: ({
            "title": "Brightness",
            "options": [
                {
                    "id": "displayBrightness",
                    "kind": "custom",
                    "label": "",
                    "keywords": "display monitor brightness ddc ddcutil backlight dim",
                    "component": brightnessComp
                }
            ]
        })

    readonly property var nightSection: ({
            "title": "Night light",
            "options": [
                {
                    "id": "displayNight",
                    "kind": "switch",
                    "label": "Night light",
                    "keywords": "night light warm blue light filter evening wlsunset",
                    "enabled": () => NightLight.available,
                    "value": () => NightLight.active,
                    "set": on => NightLight.set(on)
                },
                {
                    "id": "displayNightTemp",
                    "kind": "slider",
                    "key": "ccNightTemp",
                    "label": "Temperature",
                    "keywords": "night light warm kelvin wlsunset colour temperature",
                    "enabled": () => NightLight.available,
                    "min": 2500,
                    "max": 6000,
                    "step": 100,
                    "format": v => `${Math.round(v)} K`
                },
                {
                    "id": "displayNightNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "night light wlsunset",
                    "text": () => NightLight.available ? "Warms every display through wlsunset, the time of day does not matter. The control center tile and the bar switch use the same temperature." : "Needs wlsunset, which is not installed."
                }
            ]
        })

    sections: [stageSection, modeSection, pictureSection, lightSection, nightSection]
}
