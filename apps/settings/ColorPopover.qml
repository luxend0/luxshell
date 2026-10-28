import QtQuick
import qs.config
import qs.widgets

// Colour picker of a "color" row, inside the window above everything (like Menu):
// saturation/value square, hue strip, hex field, swatches, and "Default" when the
// option allows an empty value. Every move applies live. Click outside / Esc / Enter close.
// Keys (from the window): Left/Right saturation, Up/Down brightness, PgUp/PgDn hue,
// typing a hex digit or # jumps into the hex field.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property bool shown: false
    property var opt: null
    property var host: null
    property real hue: 0
    property real sat: 0
    property real val: 0
    property real anchorRight: 0
    property real anchorTop: 0
    property real anchorBottom: 0
    signal closed

    readonly property color current: Qt.hsva(hue, sat, val, 1)
    readonly property string currentHex: hexOf(current)
    readonly property string optValue: shown && opt ? opt.value() : ""

    visible: shown || box.opacity > 0.01

    // colour or colour string -> "#rrggbb"
    function hexOf(x): string {
        const c = Qt.tint(x, "#00000000");
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    function load(x): void {
        const c = Qt.tint(x, "#00000000");
        if (c.hsvHue >= 0)
            hue = c.hsvHue;
        sat = c.hsvSaturation;
        val = c.hsvValue;
    }
    function show(row: Item, o: var): void {
        opt = o;
        const v = o.value();
        load(v === "" ? (o.fallback ? o.fallback() : Theme.accent) : v);
        const p = row.mapToItem(root, row.width - g.rowInset + 6, 0);
        anchorRight = p.x;
        anchorTop = p.y + row.height - 6;
        anchorBottom = p.y + 6;
        shown = true;
    }
    function close(): void {
        if (!shown)
            return;
        hexField.finish(true, true);
        shown = false;
        closed();
    }
    function apply(): void {
        if (opt && currentHex !== opt.value())
            opt.set(currentHex);
    }
    function setHsv(h: real, s: real, v: real): void {
        hue = Math.max(0, Math.min(1, h));
        sat = Math.max(0, Math.min(1, s));
        val = Math.max(0, Math.min(1, v));
        apply();
    }

    function key(event): void {
        const big = event.modifiers & Qt.ShiftModifier ? 0.1 : 0.02;
        switch (event.key) {
        case Qt.Key_Left:
            return setHsv(hue, sat - big, val);
        case Qt.Key_Right:
            return setHsv(hue, sat + big, val);
        case Qt.Key_Up:
            return setHsv(hue, sat, val + big);
        case Qt.Key_Down:
            return setHsv(hue, sat, val - big);
        case Qt.Key_PageUp:
            return setHsv((hue + big + 1) % 1, sat, val);
        case Qt.Key_PageDown:
            return setHsv((hue - big + 1) % 1, sat, val);
        case Qt.Key_Escape:
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            return close();
        }
        if (/^[#0-9a-fA-F]$/.test(event.text)) {
            hexField.edit();
            hexField.input.text = event.text === "#" ? "#" : "#" + event.text;
            hexField.input.cursorPosition = hexField.input.text.length;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: box
        readonly property real wanted: col.height + 2 * root.g.popoverPad
        readonly property bool below: root.anchorTop + wanted <= root.height - 12
        width: root.g.popover
        height: wanted
        x: Math.max(12, root.anchorRight - width)
        y: below ? root.anchorTop : Math.max(12, root.anchorBottom - height)
        radius: root.g.popoverRadius
        color: root.g.menu
        border.width: 1
        border.color: root.g.separator
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: below ? Item.TopRight : Item.BottomRight
        Behavior on opacity {
            Anim {
                ms: 140
            }
        }
        Behavior on scale {
            Anim {
                ms: 180
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true // swallow clicks between the parts
        }

        Column {
            id: col
            x: root.g.popoverPad
            y: root.g.popoverPad
            width: box.width - 2 * root.g.popoverPad
            spacing: 12

            // saturation (x) / value (y)
            Item {
                width: parent.width
                height: root.g.svHeight

                Rectangle {
                    id: sv
                    anchors.fill: parent
                    radius: 10
                    color: Qt.hsva(root.hue, 1, 1, 1)
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "#ffffffff"
                            }
                            GradientStop {
                                position: 1
                                color: "#00ffffff"
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "#00000000"
                            }
                            GradientStop {
                                position: 1
                                color: "#ff000000"
                            }
                        }
                    }
                }
                Rectangle {
                    x: root.sat * parent.width - width / 2
                    y: (1 - root.val) * parent.height - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: root.current
                    border.width: 2
                    border.color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.CrossCursor
                    function at(m): void {
                        root.setHsv(root.hue, m.x / width, 1 - m.y / height);
                    }
                    onPressed: m => at(m)
                    onPositionChanged: m => at(m)
                }
            }

            // hue
            Item {
                width: parent.width
                height: root.g.hueHeight

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0 / 6
                            color: "#ff0000"
                        }
                        GradientStop {
                            position: 1 / 6
                            color: "#ffff00"
                        }
                        GradientStop {
                            position: 2 / 6
                            color: "#00ff00"
                        }
                        GradientStop {
                            position: 3 / 6
                            color: "#00ffff"
                        }
                        GradientStop {
                            position: 4 / 6
                            color: "#0000ff"
                        }
                        GradientStop {
                            position: 5 / 6
                            color: "#ff00ff"
                        }
                        GradientStop {
                            position: 1
                            color: "#ff0000"
                        }
                    }
                }
                Rectangle {
                    x: root.hue * (parent.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: Qt.hsva(root.hue, 1, 1, 1)
                    border.width: 2
                    border.color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    function at(m): void {
                        root.setHsv(Math.max(0, Math.min(1, (m.x - 6) / (width - 12))), root.sat, root.val);
                    }
                    onPressed: m => at(m)
                    onPositionChanged: m => at(m)
                }
            }

            // hex + default
            Row {
                width: parent.width
                spacing: 8

                FieldCtl {
                    id: hexField
                    width: parent.width - (resetDefault.visible ? resetDefault.width + 8 : 0)
                    host: root.host
                    text: root.optValue === "" ? "" : root.optValue.toUpperCase()
                    placeholder: root.opt?.emptyLabel ?? "#rrggbb"
                    valid: t => /^#?[0-9a-fA-F]{6}$/.test(t.trim()) || (t.trim() === "" && (root.opt?.allowEmpty ?? false))
                    onApplied: t => {
                        const v = t.trim();
                        if (v === "") {
                            root.opt.set("");
                            return;
                        }
                        const hx = (v.startsWith("#") ? v : "#" + v).toLowerCase();
                        root.load(hx);
                        root.opt.set(hx);
                    }
                }
                Rectangle {
                    id: resetDefault
                    visible: root.opt?.allowEmpty ?? false
                    width: defText.implicitWidth + 24
                    height: root.g.fieldHeight
                    radius: root.g.fieldRadius
                    color: defArea.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.1) : root.g.field
                    SText {
                        id: defText
                        anchors.centerIn: parent
                        size: 15
                        text: root.opt?.emptyLabel ?? "Default"
                        color: root.optValue === "" ? root.g.label : root.g.value
                    }
                    MouseArea {
                        id: defArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.opt.set("");
                            root.load(root.opt.fallback ? root.opt.fallback() : Theme.accent);
                        }
                    }
                }
            }

            // swatches: theme accent + palette + option extras
            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: {
                        const list = [Theme.pal.accent, ...Theme.swatches, "#ffffff", "#9a9a9a", "#3b82f6", "#e5484d", "#30a46c", "#f5a524"];
                        const extra = root.opt?.swatches ? root.opt.swatches() : [];
                        const seen = {};
                        return [...extra, ...list].map(c => root.hexOf(c)).filter(c => seen[c] ? false : (seen[c] = true));
                    }

                    Rectangle {
                        id: sw
                        required property var modelData
                        width: 24
                        height: 24
                        radius: 12
                        color: modelData
                        border.width: 1
                        border.color: Theme.mix(color, Theme.text, 0.2)
                        scale: swArea.containsMouse ? 1.12 : 1
                        Behavior on scale {
                            Anim {
                                ms: Theme.fadeOut
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 7
                            height: 7
                            radius: 3.5
                            color: Theme.island
                            visible: root.optValue.toLowerCase() === sw.modelData
                        }
                        MouseArea {
                            id: swArea
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.load(sw.modelData);
                                root.opt.set(sw.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
