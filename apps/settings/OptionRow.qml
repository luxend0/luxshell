import QtQuick
import qs.config
import qs.widgets
import qs.services

// One row of a settings card (ref/12): label left, control right, 1 px separator
// above every row but the first. Kinds: README.md (Catalog.normalize fills value/set/
// reset for options with a `key`). Tall kinds put the label on a line of its own:
// slider (track below), list, paths and custom (content below).
//
// A changed option shows a quiet reset arrow next to its control (tip: the default).
// Keys come from the window (SettingsWindow): activate() Enter/Space, adjust(+1/-1)
// Left/Right, navigate(d, mods) Up/Down inside tall rows, enter(d) when focus arrives,
// deleteKey() Delete/Backspace (remove an entry, else reset the option); each returns
// false when the row has no use for the key.
Item {
    id: row

    readonly property QtObject g: Theme.settings
    required property var opt
    required property var host        // SettingsWindow controller
    property int flatIndex: -1
    property bool first: false
    property bool last: false

    readonly property string kind: opt.kind
    readonly property bool active: opt.enabled ? opt.enabled() : true
    readonly property bool focused: host.kb && host.zone === "content" && host.focusIndex === flatIndex
    readonly property bool block: ["list", "paths", "custom"].includes(kind)
    readonly property bool bare: kind === "custom" && (opt.label ?? "") === "" // custom content fills the row
    readonly property bool tall: kind === "slider" || block
    readonly property bool clickable: active && ["link", "choice", "font", "switch", "button", "color"].includes(kind)
    readonly property bool hovered: area.containsMouse
    readonly property bool modified: opt.modified ? opt.modified() : false
    property bool armed: false        // button with `confirm`: first activation shows the question

    width: g.cardWidth
    height: kind === "slider" ? g.sliderRowHeight : block ? (bare ? contentHeight : g.blockTop + contentHeight + g.blockPad) : g.rowHeight
    readonly property real contentHeight: control.item ? control.item.implicitHeight : 0

    // a growing list keeps its keyboard entry in view
    onHeightChanged: if (focused)
        host.revealRow(row)

    Component.onCompleted: host.register(flatIndex, row)
    Component.onDestruction: host.unregister(flatIndex, row)

    function call(name: string, a: var, b: var): var {
        const it = control.item;
        return it && typeof it[name] === "function" ? it[name](a, b) : undefined;
    }

    function activate(): bool {
        if (!active)
            return false;
        switch (kind) {
        case "link":
            opt.run();
            return true;
        case "button":
            if (opt.confirm && !armed) {
                armed = true;
                disarm.restart();
                return true;
            }
            armed = false;
            opt.run();
            return true;
        case "switch":
            opt.set(!opt.value());
            return true;
        case "choice":
        case "font":
            host.openMenu(row, opt);
            return true;
        case "color":
            host.openColor(row, opt);
            return true;
        case "text":
        case "time":
        case "path":
            control.item.edit();
            return true;
        case "timerange":
            control.item.editFrom();
            return true;
        }
        return call("activate") === true;
    }

    function adjust(d: int): bool {
        if (!active)
            return false;
        switch (kind) {
        case "slider":
            {
                const v = Math.max(opt.min, Math.min(opt.max, Math.round((opt.value() + d * opt.step) * 1000) / 1000));
                if (v !== opt.value())
                    opt.set(v);
                return true;
            }
        case "choice":
            {
                const list = opt.options();
                const i = list.findIndex(o => o.value === opt.value());
                const n = list[Math.max(0, Math.min(list.length - 1, i + d))];
                if (n && n.value !== opt.value())
                    opt.set(n.value);
                return true;
            }
        case "swatches":
            {
                const n = opt.colours().length;
                const i = Math.max(0, Math.min(n - 1, control.item.current + d));
                control.item.pick(i);
                return true;
            }
        case "switch":
            if ((d > 0) !== opt.value())
                opt.set(d > 0);
            return true;
        case "time":
            control.item.shift(d);
            return true;
        }
        return call("adjust", d) === true;
    }

    function navigate(d: int, mods: int): bool {
        return active && call("navigate", d, mods) === true;
    }
    function enter(d: int): void {
        call("enter", d);
    }
    // part of the row the keyboard is on (the window scrolls it into view)
    function focusRect(): var {
        const r = call("focusRect");
        return r ? {
            "y": control.y + r.y,
            "h": r.h
        } : {
            "y": 0,
            "h": height
        };
    }
    function deleteKey(): bool {
        if (active && call("deleteKey") === true)
            return true;
        if (modified) {
            opt.reset();
            return true;
        }
        return false;
    }

    // room for a value text right of the label (long values elide in the middle)
    readonly property real valueRoom: width - 2 * g.rowInset - label.implicitWidth - 40 - reset.width

    // value as the row shows it (search results, choice label)
    function choiceLabel(): string {
        const v = opt.value();
        if (kind === "font")
            return v;
        const o = opt.options().find(x => x.value === v);
        return o ? o.label : String(v);
    }

    // the default in words, for the reset tip
    function describe(v: var): string {
        if (v === undefined || v === null)
            return "";
        switch (kind) {
        case "slider":
            return opt.format ? opt.format(v) : String(v);
        case "choice":
            {
                const o = opt.options().find(x => x.value === v);
                return o ? o.label : String(v);
            }
        case "switch":
            return v ? "On" : "Off";
        case "color":
        case "swatches":
            return v === "" ? (opt.emptyLabel ?? "Theme") : String(v).toUpperCase();
        case "list":
            {
                const items = opt.items();
                return Array.from(v).map(x => items.find(i => i.value === x)?.label ?? x).join(", ");
            }
        case "paths":
            return v.length === 0 ? "none" : Array.from(v).join(", ");
        case "timerange":
            return `${v.from} – ${v.to}`;
        case "weekdays":
            return Array.from(v).map(d => Clock.locale.dayName(d % 7, Locale.ShortFormat)).join(" ");
        }
        return typeof v === "object" ? "" : String(v);
    }
    readonly property string resetTip: {
        if (!modified)
            return "";
        const d = describe(opt.defaultValue());
        return d === "" ? "Reset to default" : `Reset to default: ${d}`;
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: row.armed = false
    }

    // ---- chrome -------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: row.g.hover
        opacity: row.clickable && row.hovered ? 1 : 0
        topLeftRadius: row.first ? row.g.cardRadius : 0
        topRightRadius: row.first ? row.g.cardRadius : 0
        bottomLeftRadius: row.last ? row.g.cardRadius : 0
        bottomRightRadius: row.last ? row.g.cardRadius : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }

    Rectangle {
        visible: !row.first
        x: row.g.rowInset
        width: parent.width - 2 * row.g.rowInset
        height: 1
        color: row.g.separator
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 13
        color: "transparent"
        border.width: 2
        border.color: row.g.ring
        // tall rows with their own entry cursor ring the entry instead
        visible: row.focused && !(row.block && control.item && control.item.cursor !== undefined && control.item.cursor >= 0)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.clickable
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            row.host.focusRoot();
            row.host.focusRow(row.flatIndex);
            row.activate();
        }
    }

    SText {
        id: label
        visible: !row.bare
        x: row.g.rowInset
        y: (row.kind === "slider" ? row.g.sliderLabelY : row.block ? row.g.blockLabelY : row.height / 2) - height / 2
        width: (reset.shown ? reset.x : row.tall ? head.x : control.x) - x - 16
        elide: Text.ElideRight
        text: row.opt.label ?? ""
        color: row.active ? row.g.label : row.g.value
    }

    // tall rows: reset + value ("15 px") or summary ("3 of 6") on the label line
    Row {
        id: head
        visible: row.tall && !row.bare
        x: row.width - (row.kind === "slider" ? 22 : row.g.rowInset) - width
        y: label.y + label.height / 2 - height / 2
        spacing: row.g.resetGap
        layoutDirection: Qt.LeftToRight

        SText {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: {
                if (row.kind === "slider")
                    return row.opt.format(control.item?.shown ?? row.opt.value());
                if (row.opt.summary)
                    return row.opt.summary();
                return control.item && typeof control.item.summary === "function" ? control.item.summary() : "";
            }
            color: row.g.value
        }
    }

    ResetButton {
        id: reset
        shown: row.modified && row.active && !row.bare
        host: row.host
        tip: row.resetTip
        x: row.tall ? head.x - (shown ? width + row.g.resetGap : 0) : control.x - (shown ? width + row.g.resetGap : 0)
        y: row.tall ? head.y + head.height / 2 - height / 2 : (row.height - height) / 2
        onClicked: {
            row.host.focusRoot();
            row.host.focusRow(row.flatIndex);
            row.opt.reset();
        }
    }

    // ---- control ------------------------------------------------------------------
    Loader {
        id: control
        x: row.bare ? 0 : row.tall ? row.g.rowInset : row.width - row.g.rowInset - width
        y: row.kind === "slider" ? row.g.sliderTrackY - height / 2 : row.block ? (row.bare ? 0 : row.g.blockTop) : (row.height - height) / 2
        width: row.bare ? row.width : row.tall ? row.width - 2 * row.g.rowInset : implicitWidth
        sourceComponent: row.kind === "custom" ? (row.opt.component ?? null) : (({
                    "link": valueComp,
                    "choice": valueComp,
                    "font": valueComp,
                    "info": valueComp,
                    "button": buttonComp,
                    "switch": switchComp,
                    "slider": sliderComp,
                    "swatches": swatchComp,
                    "text": textComp,
                    "color": colorComp,
                    "time": timeComp,
                    "timerange": rangeComp,
                    "weekdays": daysComp,
                    "path": pathComp,
                    "list": listComp,
                    "paths": pathsComp
                })[row.kind] ?? null)
        onLoaded: {
            if (row.kind !== "custom")
                return;
            for (const [k, v] of [["opt", row.opt], ["row", row], ["host", row.host]])
                if (k in item)
                    item[k] = v;
        }
    }

    Component {
        id: valueComp
        Row {
            spacing: row.g.arrowGap
            layoutDirection: Qt.LeftToRight
            // link/choice: arrow right edge sits 23 px from the card edge (ref/12)
            rightPadding: row.kind === "info" ? 2 : row.g.valueRight - row.g.rowInset - 2

            SText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, row.valueRoom - 30)
                elide: Text.ElideMiddle
                text: row.kind === "choice" || row.kind === "font" ? row.choiceLabel() : row.opt.value()
                color: row.g.value
                font.family: row.kind === "font" ? row.opt.value() : Theme.fontFamily
            }
            MdIcon {
                visible: row.kind !== "info"
                anchors.verticalCenter: parent.verticalCenter
                glyph: row.kind === "choice" || row.kind === "font" ? Catalog.glyph(0xF0140) : Catalog.glyph(0xF0054)
                size: row.kind === "choice" || row.kind === "font" ? row.g.arrowSize + 3 : row.g.arrowSize
                color: row.g.value
            }
        }
    }

    Component {
        id: buttonComp
        Row {
            spacing: 14
            SText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, row.valueRoom - btnText.implicitWidth - 46)
                elide: Text.ElideMiddle
                text: row.armed ? (typeof row.opt.confirm === "function" ? row.opt.confirm() : row.opt.confirm) : row.opt.value()
                color: row.armed ? row.g.label : row.g.value
                visible: text !== ""
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: btnText.implicitWidth + 32
                height: 34
                radius: height / 2
                color: row.armed ? row.g.danger : row.active && row.hovered ? Theme.mix(row.g.field, Theme.text, 0.1) : row.g.field
                opacity: row.active ? 1 : 0.5
                Behavior on color {
                    ColorAnim {
                        ms: Theme.fadeOut
                    }
                }
                SText {
                    id: btnText
                    anchors.centerIn: parent
                    size: 15
                    text: row.armed ? "Confirm" : (typeof row.opt.action === "function" ? row.opt.action() : row.opt.action)
                    color: row.armed ? "white" : row.g.label
                }
            }
        }
    }

    Component {
        id: switchComp
        SwitchCtl {
            on: row.opt.value()
            hovered: row.hovered
            opacity: row.active ? 1 : 0.5
        }
    }

    Component {
        id: sliderComp
        SliderCtl {
            value: row.opt.value()
            min: row.opt.min
            max: row.opt.max
            step: row.opt.step
            enabled: row.active
            onCommit: v => {
                row.host.focusRoot();
                row.host.focusRow(row.flatIndex);
                if (v !== row.opt.value())
                    row.opt.set(v);
            }
        }
    }

    Component {
        id: swatchComp
        Swatches {
            colours: row.opt.colours()
            current: {
                const v = row.opt.value().toLowerCase();
                if (v === "")
                    return 0;
                return colours.findIndex(c => Icons.hex(c) === v);
            }
            function pick(i: int): void {
                row.opt.set(i === 0 ? "" : Icons.hex(colours[i]));
            }
            onPicked: i => {
                row.host.focusRoot();
                row.host.focusRow(row.flatIndex);
                pick(i);
            }
        }
    }

    Component {
        id: textComp
        FieldCtl {
            host: row.host
            flatIndex: row.flatIndex
            text: row.opt.value()
            placeholder: row.opt.placeholder ?? ""
            family: row.opt.mono ? Theme.monoFamily : Theme.fontFamily
            valid: row.opt.valid
            enabled: row.active
            onApplied: t => row.opt.apply(t)
        }
    }

    Component {
        id: colorComp
        ColorCtl {
            value: row.opt.value()
            fallback: row.opt.fallback ? row.opt.fallback() : Theme.accent
            emptyLabel: row.opt.emptyLabel ?? "Default"
            hovered: row.hovered
            opacity: row.active ? 1 : 0.5
        }
    }

    Component {
        id: timeComp
        TimeCtl {
            host: row.host
            flatIndex: row.flatIndex
            value: row.opt.value()
            step: row.opt.step ?? 15
            enabled: row.active
            onChanged: v => {
                if (v !== row.opt.value())
                    row.opt.set(v);
            }
        }
    }

    Component {
        id: rangeComp
        Row {
            id: range
            readonly property var v: row.opt.value() ?? ({
                    "from": "00:00",
                    "to": "00:00"
                })
            spacing: 10
            function editFrom(): void {
                fromField.edit();
            }
            function put(k: string, t: string): void {
                if (t === v[k])
                    return;
                const n = Object.assign({}, v);
                n[k] = t;
                row.opt.set(n);
            }
            TimeCtl {
                id: fromField
                host: row.host
                flatIndex: row.flatIndex
                value: range.v.from
                step: row.opt.step ?? 15
                enabled: row.active
                onChanged: t => range.put("from", t)
                onTabbed: toField.edit()
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                text: "–"
                color: row.g.value
            }
            TimeCtl {
                id: toField
                host: row.host
                flatIndex: row.flatIndex
                value: range.v.to
                step: row.opt.step ?? 15
                enabled: row.active
                onChanged: t => range.put("to", t)
            }
        }
    }

    Component {
        id: daysComp
        DaysCtl {
            owner: row
            value: Array.from(row.opt.value() ?? [])
            opacity: row.active ? 1 : 0.5
            onChanged: d => row.opt.set(d)
        }
    }

    Component {
        id: pathComp
        Row {
            spacing: 8
            function edit(): void {
                pathField.edit();
            }
            FieldCtl {
                id: pathField
                host: row.host
                flatIndex: row.flatIndex
                text: row.opt.value()
                placeholder: row.opt.placeholder ?? ""
                valid: row.opt.valid
                enabled: row.active
                onApplied: t => row.opt.set(t.trim() === "" ? "" : Catalog.tilde(Catalog.expand(t.trim())))
            }
            MiniButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: row.g.fieldHeight
                visible: Catalog.hasChooser
                text: "Browse"
                active: row.active
                onClicked: Catalog.choosePath(row.opt.mode ?? "file", row.opt.label, row.opt.value(), p => row.opt.set(p))
            }
        }
    }

    Component {
        id: listComp
        ListCtl {
            opt: row.opt
            owner: row
            opacity: row.active ? 1 : 0.5
        }
    }

    Component {
        id: pathsComp
        PathsCtl {
            opt: row.opt
            owner: row
            host: row.host
            opacity: row.active ? 1 : 0.5
        }
    }
}
