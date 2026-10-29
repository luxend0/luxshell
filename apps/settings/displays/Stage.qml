import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Top of Settings > Displays (custom row without label, page = SysDisplays as `ctl`).
//   one display: drawn large in its real proportions (rotation and scale included) on a small
//     stand, name, connector, size, mode and what the scale makes of it.
//   two or more: the arrangement. Every display a rectangle in its logical size (mode /
//     scale, turned for 90° / 270°), positioned as Hyprland has them, fitted into the canvas.
//     Click picks the display the rows below edit; drag moves it: edges snap to the edges of
//     the others (guides show where), on release it lands next to one of them without
//     overlap and the arrangement starts at 0, 0 (page.drop asks "Keep?"). Under the canvas:
//     the picked display, "Main display" (cursor.default_monitor), displays that are off or
//     mirror another (click picks them), and a reset of the arrangement.
// Keys: Left/Right pick the previous / next display.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject d: Theme.displays
    property var ctl: null
    property var opt: null
    property var row: null
    property var host: null
    readonly property bool multi: ctl ? ctl.multi : false
    readonly property var cur: ctl ? ctl.cur : null

    implicitHeight: multi ? d.canvasInset + d.canvasHeight + d.footerHeight : d.stageHeight

    function adjust(dd: int): bool {
        if (!multi)
            return false;
        const l = ctl.list;
        const j = l.findIndex(v => v.name === ctl.sel) + dd;
        if (j < 0)
            return false;
        if (j < l.length)
            ctl.select(l[j].name);
        return true;
    }
    function focusRow(): void {
        if (row) {
            row.host.focusRoot();
            row.host.focusRow(row.flatIndex);
        }
    }
    // logical size shown for a display: the scale slider's preview while it is dragged
    function sizeOf(v: var): var {
        const p = ctl ? ctl.preview : null;
        if (p && v && p.name === v.name && v.w > 0)
            return ctl.logical(v.w, v.h, p.scale, v.transform);
        return {
            "w": v ? v.lw : 0,
            "h": v ? v.lh : 0
        };
    }
    function facts(v: var): string {
        if (!v)
            return "";
        const parts = [v.label !== v.name ? v.name : v.virtual ? "Virtual output" : v.name];
        if (v.inches > 0)
            parts.push(`${v.inches}″`);
        parts.push(ctl.aspect(v.w, v.h));
        return parts.join("  ·  ");
    }

    // ==== one display ========================================================================
    Item {
        id: single
        visible: !root.multi
        anchors.fill: parent

        readonly property var v: root.cur
        readonly property var size: root.sizeOf(v)
        readonly property real ar: size.h > 0 ? size.w / size.h : 16 / 9
        readonly property real sw: Math.min(root.d.screenMaxWidth, root.d.screenMaxHeight * ar)
        readonly property real sh: sw / ar
        readonly property real screenBottom: root.d.screenTop + root.d.screenMaxHeight

        Rectangle {
            id: bezel
            x: (single.width - width) / 2
            y: single.screenBottom - height
            width: single.sw
            height: single.sh
            radius: root.d.screenRadius
            color: root.d.bezelColor
            Behavior on width {
                Anim {
                    ms: 260
                }
            }
            Behavior on height {
                Anim {
                    ms: 260
                }
            }

            Rectangle {
                id: glass
                anchors.fill: parent
                anchors.margins: root.d.bezel
                radius: root.d.screenRadius - 4
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.d.screenHigh
                    }
                    GradientStop {
                        position: 1
                        color: root.d.screen
                    }
                }
                clip: true

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 4

                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        size: root.d.nameSize
                        font.weight: Font.DemiBold
                        text: single.v ? single.v.label : "No display"
                    }
                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        size: root.d.subSize
                        font.weight: Font.Normal
                        text: root.facts(single.v)
                        color: root.g.value
                    }
                    Item {
                        width: 1
                        height: 12
                    }
                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        size: 15.5
                        text: single.v ? `${single.v.w} × ${single.v.h}  ·  ${root.ctl.fmtHz(single.v.hz)} Hz` : ""
                    }
                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        size: root.d.subSize
                        font.weight: Font.Normal
                        color: root.g.value
                        text: {
                            const v = single.v;
                            if (!v)
                                return "";
                            const p = root.ctl.preview;
                            const s = p && p.name === v.name ? p.scale : v.scale;
                            const l = single.size;
                            return s === 1 ? "Scale 100 %" : `${root.ctl.pct(s)}  ·  looks like ${l.w} × ${l.h}`;
                        }
                    }
                }
            }
        }
        // stand
        Rectangle {
            x: (single.width - width) / 2
            y: single.screenBottom
            width: root.d.neckWidth
            height: root.d.neckHeight
            color: root.d.bezelColor
        }
        Rectangle {
            x: (single.width - width) / 2
            y: single.screenBottom + root.d.neckHeight
            width: root.d.baseWidth
            height: root.d.baseHeight
            radius: height / 2
            color: root.d.bezelColor
        }
    }

    // ==== two or more: arrangement canvas =====================================================
    Rectangle {
        id: canvas
        visible: root.multi
        x: root.d.canvasInset
        y: root.d.canvasInset
        width: parent.width - 2 * root.d.canvasInset
        height: root.d.canvasHeight
        radius: root.d.canvasRadius
        color: root.d.canvas
        clip: true

        readonly property var rects: root.ctl ? root.ctl.layout : []
        readonly property var box: {
            const r = rects;
            if (r.length === 0)
                return {
                    "x": 0,
                    "y": 0,
                    "w": 1920,
                    "h": 1080
                };
            const x0 = Math.min(...r.map(v => v.x)), y0 = Math.min(...r.map(v => v.y));
            const x1 = Math.max(...r.map(v => v.x + v.lw)), y1 = Math.max(...r.map(v => v.y + v.lh));
            return {
                "x": x0,
                "y": y0,
                "w": Math.max(1, x1 - x0),
                "h": Math.max(1, y1 - y0)
            };
        }
        // the fit is kept while a display is dragged, so the canvas holds still under the mouse
        property bool dragging: false
        property var held: null
        // the arrangement fills at most `room` of the canvas: space around it to drag a display to
        readonly property var fit: {
            const pad = root.d.canvasPad, room = root.d.canvasRoom;
            const k = Math.min((width - 2 * pad) * room / box.w, (height - 2 * pad - 14) * room / box.h, 0.16);
            return {
                "k": k,
                "ox": (width - box.w * k) / 2 - box.x * k,
                "oy": (height - 14 - box.h * k) / 2 - box.y * k
            };
        }
        readonly property var view: dragging && held ? held : fit
        readonly property real k: view.k
        readonly property real ox: view.ox
        readonly property real oy: view.oy
        property var guideX: null
        property var guideY: null
        property var landing: null // { x, y, w, h } logical: where the dragged display lands on release

        // snap a dragged display (logical x, y, w, h) to the edges of the others
        function snap(name: string, x: real, y: real, w: real, h: real): var {
            const thr = root.d.snap / k;
            let bx = x, by = y, gx = null, gy = null, ex = thr, ey = thr;
            for (const o of rects) {
                if (o.name === name)
                    continue;
                for (const [edge, target] of [[x, o.x], [x, o.x + o.lw], [x + w, o.x], [x + w, o.x + o.lw]]) {
                    const diff = target - edge;
                    if (Math.abs(diff) < ex) {
                        ex = Math.abs(diff);
                        bx = x + diff;
                        gx = target;
                    }
                }
                for (const [edge, target] of [[y, o.y], [y, o.y + o.lh], [y + h, o.y], [y + h, o.y + o.lh]]) {
                    const diff = target - edge;
                    if (Math.abs(diff) < ey) {
                        ey = Math.abs(diff);
                        by = y + diff;
                        gy = target;
                    }
                }
            }
            return {
                "x": bx,
                "y": by,
                "gx": gx,
                "gy": gy
            };
        }

        // where the dragged display lands (next to another one, no overlap)
        Rectangle {
            visible: canvas.dragging && canvas.landing !== null
            x: canvas.ox + (canvas.landing?.x ?? 0) * canvas.k
            y: canvas.oy + (canvas.landing?.y ?? 0) * canvas.k
            width: (canvas.landing?.w ?? 0) * canvas.k
            height: (canvas.landing?.h ?? 0) * canvas.k
            radius: root.d.monitorRadius
            color: Qt.rgba(root.d.guide.r, root.d.guide.g, root.d.guide.b, 0.12)
            border.width: 1.5
            border.color: root.d.guide
        }

        // snap guides
        Rectangle {
            visible: canvas.dragging && canvas.guideX !== null
            x: canvas.ox + (canvas.guideX ?? 0) * canvas.k
            width: 1
            height: canvas.height
            color: root.d.guide
        }
        Rectangle {
            visible: canvas.dragging && canvas.guideY !== null
            y: canvas.oy + (canvas.guideY ?? 0) * canvas.k
            width: canvas.width
            height: 1
            color: root.d.guide
        }

        Repeater {
            // an index model: the tiles stay (and glide) when only positions or sizes change
            model: canvas.rects.length

            Item {
                id: tile
                required property int index
                readonly property var v: canvas.rects[index] ?? null
                readonly property var size: root.sizeOf(v)
                readonly property bool picked: v !== null && root.ctl.sel === v.name
                readonly property bool main: v !== null && root.ctl.main === v.name
                property bool dragging: false
                property real dragX: 0
                property real dragY: 0
                property real startX: 0
                property real startY: 0
                property point press: Qt.point(0, 0)

                x: canvas.ox + (dragging ? dragX : (v?.x ?? 0)) * canvas.k
                y: canvas.oy + (dragging ? dragY : (v?.y ?? 0)) * canvas.k
                width: size.w * canvas.k
                height: size.h * canvas.k
                z: dragging ? 2 : picked ? 1 : 0
                opacity: dragging ? 0.9 : 1 // the landing place shows through
                Behavior on x {
                    enabled: !tile.dragging
                    Anim {
                        ms: 240
                    }
                }
                Behavior on y {
                    enabled: !tile.dragging
                    Anim {
                        ms: 240
                    }
                }
                Behavior on width {
                    Anim {
                        ms: 240
                    }
                }
                Behavior on height {
                    Anim {
                        ms: 240
                    }
                }


                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: root.d.monitorRadius
                    color: tile.picked ? root.d.monitorSelected : area.containsMouse ? root.d.monitorHover : root.d.monitor
                    border.width: tile.picked ? 2 : 1
                    border.color: tile.picked ? Theme.text : root.d.outline
                    Behavior on color {
                        ColorAnim {
                            ms: Theme.fadeOut
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 2

                        SText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            size: 14.5
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 9
                            font.weight: Font.DemiBold
                            text: tile.v ? tile.v.name : ""
                            color: tile.picked ? root.g.label : Theme.mix(root.g.label, root.g.value, 0.3)
                        }
                        SText {
                            visible: tile.height > 52
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            size: 12.5
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 8
                            font.weight: Font.Normal
                            text: tile.v ? `${tile.v.w} × ${tile.v.h}` : ""
                            color: root.g.value
                        }
                    }

                    // main display: a star in the corner
                    MdIcon {
                        visible: tile.main
                        x: 7
                        y: 6
                        size: 15
                        glyph: String.fromCodePoint(0xF04CE) // md-star
                        color: tile.picked ? root.g.label : root.g.value
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        root.focusRow();
                        root.ctl.select(tile.v.name);
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        tile.press = Qt.point(p.x, p.y);
                        tile.startX = tile.v.x;
                        tile.startY = tile.v.y;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !tile.v)
                            return;
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        const dx = p.x - tile.press.x, dy = p.y - tile.press.y;
                        if (!tile.dragging) {
                            if (Math.abs(dx) + Math.abs(dy) < 4 || canvas.rects.length < 2)
                                return;
                            canvas.held = canvas.fit;
                            canvas.dragging = true;
                            tile.dragging = true;
                        }
                        // at least half of it inside the canvas, edges snapped to the others
                        const w = tile.v.lw, h = tile.v.lh, k = canvas.k;
                        const nx = Math.max(-canvas.ox / k - w / 2, Math.min((canvas.width - canvas.ox) / k - w / 2, tile.startX + dx / k));
                        const ny = Math.max(-canvas.oy / k - h / 2, Math.min((canvas.height - canvas.oy) / k - h / 2, tile.startY + dy / k));
                        const s = canvas.snap(tile.v.name, nx, ny, w, h);
                        tile.dragX = s.x;
                        tile.dragY = s.y;
                        canvas.guideX = s.gx;
                        canvas.guideY = s.gy;
                        const l = root.ctl.settle(tile.v.name, Math.round(s.x), Math.round(s.y));
                        canvas.landing = l.x === Math.round(s.x) && l.y === Math.round(s.y) ? null : {
                            "x": l.x,
                            "y": l.y,
                            "w": w,
                            "h": h
                        };
                    }
                    onReleased: {
                        if (!tile.dragging)
                            return;
                        const x = tile.dragX, y = tile.dragY;
                        root.ctl.drop(tile.v.name, x, y);
                        tile.dragging = false;
                        canvas.dragging = false;
                        canvas.guideX = null;
                        canvas.guideY = null;
                        canvas.landing = null;
                    }
                    onCanceled: {
                        tile.dragging = false;
                        canvas.dragging = false;
                        canvas.landing = null;
                    }
                }
            }
        }

        SText {
            visible: canvas.rects.length >= 2
            x: canvas.width - width - 14
            y: canvas.height - height - 10
            size: 12.5
            font.weight: Font.Normal
            text: canvas.dragging ? "Release to place" : "Drag to arrange, click to pick"
            color: Theme.mix(root.g.value, root.d.canvas, 0.25)
        }
    }

    // ---- under the canvas: the picked display -------------------------------------------------
    Item {
        id: footer
        visible: root.multi
        x: root.d.canvasInset + 6
        y: root.d.canvasInset + root.d.canvasHeight
        width: parent.width - 2 * x
        height: root.d.footerHeight

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, tools.x - 16)
            spacing: 2

            SText {
                width: parent.width
                elide: Text.ElideRight
                text: root.cur ? root.cur.label : ""
            }
            SText {
                width: parent.width
                elide: Text.ElideRight
                size: 13.5
                font.weight: Font.Normal
                color: root.g.value
                text: {
                    const v = root.cur;
                    if (!v)
                        return "";
                    const who = v.label !== v.name ? `${v.name}  ·  ` : "";
                    if (v.disabled)
                        return `${who}off`;
                    if (v.mirror !== "")
                        return `${who}shows the picture of ${v.mirror}`;
                    return `${root.facts(v)}  ·  at ${v.x}, ${v.y}`;
                }
            }
        }

        Row {
            id: tools
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // displays outside the arrangement: off, or showing another one
            Repeater {
                model: root.ctl ? root.ctl.list.filter(v => v.disabled || v.mirror !== "" || v.lw <= 0) : []

                MiniButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.disabled ? `${modelData.name}: off` : `${modelData.name}: mirror`
                    color: root.ctl.sel === modelData.name ? root.d.plate : root.g.field
                    onClicked: {
                        root.focusRow();
                        root.ctl.select(modelData.name);
                    }
                }
            }

            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                shown: root.ctl !== null && root.ctl.arranged()
                host: root.host
                tip: "Arrangement as before"
                onClicked: {
                    root.focusRow();
                    root.ctl.resetArrangement();
                }
            }

            // main display: the cursor starts there
            Rectangle {
                id: mainButton
                readonly property bool on: root.cur !== null && root.ctl.main === root.cur.name
                readonly property bool usable: root.cur !== null && !root.cur.disabled && root.cur.mirror === ""
                anchors.verticalCenter: parent.verticalCenter
                width: mainRow.width + 28
                height: 34
                radius: height / 2
                color: on ? root.d.plate : mainArea.containsMouse && usable ? Theme.mix(root.g.field, Theme.text, 0.1) : root.g.field
                opacity: usable ? 1 : 0.45

                Row {
                    id: mainRow
                    anchors.centerIn: parent
                    spacing: 7
                    MdIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        glyph: String.fromCodePoint(mainButton.on ? 0xF04CE : 0xF04D2) // md-star / md-star-outline
                        color: mainButton.on ? root.g.label : root.g.value
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 14.5
                        text: "Main display"
                        color: mainButton.on ? root.g.label : root.g.value
                    }
                }
                MouseArea {
                    id: mainArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: mainButton.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.focusRow();
                        root.ctl.setMain(root.cur.name);
                    }
                    onContainsMouseChanged: if (root.host) {
                        if (containsMouse)
                            root.host.tip(mainButton, mainButton.on ? "The cursor starts here (click: no main display)" : "Make this the main display: the cursor starts here");
                        else
                            root.host.untip(mainButton);
                    }
                }
            }
        }
    }
}
