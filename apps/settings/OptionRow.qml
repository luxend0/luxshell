import QtQuick
import qs.config
import qs.widgets

// One row of a settings card (ref/12): label left, control right, 1 px separator
// above every row but the first. kinds: see Catalog.qml.
//
// Keys come from the window (SettingsWindow): activate() for Enter/Space,
// adjust(+1/-1) for Left/Right; both return false when the row has no use for them.
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
    readonly property bool clickable: active && ["link", "choice", "switch", "button"].includes(kind)
    readonly property bool hovered: area.containsMouse

    width: g.cardWidth
    height: kind === "slider" ? g.sliderRowHeight : g.rowHeight

    Component.onCompleted: host.register(flatIndex, row)
    Component.onDestruction: host.unregister(flatIndex, row)

    function activate(): bool {
        if (!active)
            return false;
        switch (kind) {
        case "link":
        case "button":
            opt.run();
            return true;
        case "switch":
            opt.set(!opt.value());
            return true;
        case "choice":
            host.openMenu(row, opt);
            return true;
        case "text":
            control.item.edit();
            return true;
        }
        return false;
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
        }
        return false;
    }

    // room for a value text right of the label (long values elide in the middle)
    readonly property real valueRoom: width - 2 * g.rowInset - label.implicitWidth - 40

    // value as the row shows it (search results, choice label)
    function choiceLabel(): string {
        const v = opt.value();
        const o = opt.options().find(x => x.value === v);
        return o ? o.label : String(v);
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
        visible: row.focused
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
        x: row.g.rowInset
        y: (row.kind === "slider" ? row.g.sliderLabelY : row.height / 2) - height / 2
        width: (row.kind === "slider" ? valueText.x : control.x) - x - 16
        elide: Text.ElideRight
        text: row.opt.label
        color: row.active ? row.g.label : row.g.value
    }

    // slider value on the label line ("15 px")
    SText {
        id: valueText
        visible: row.kind === "slider"
        x: row.width - 22 - width
        y: label.y
        text: row.kind === "slider" ? row.opt.format(control.item?.shown ?? row.opt.value()) : ""
        color: row.g.value
    }

    // ---- control ------------------------------------------------------------------
    Loader {
        id: control
        x: row.kind === "slider" ? row.g.rowInset : row.width - row.g.rowInset - width
        y: row.kind === "slider" ? row.g.sliderTrackY - height / 2 : (row.height - height) / 2
        width: row.kind === "slider" ? row.width - 2 * row.g.rowInset : implicitWidth
        sourceComponent: ({
                "link": valueComp,
                "choice": valueComp,
                "info": valueComp,
                "button": buttonComp,
                "switch": switchComp,
                "slider": sliderComp,
                "swatches": swatchComp,
                "text": textComp
            })[row.kind] ?? null
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
                text: row.kind === "choice" ? row.choiceLabel() : row.opt.value()
                color: row.g.value
                font.family: row.kind === "choice" && row.opt.id === "fontFamily" ? row.opt.value() : Theme.fontFamily
            }
            MdIcon {
                visible: row.kind !== "info"
                anchors.verticalCenter: parent.verticalCenter
                glyph: row.kind === "choice" ? Catalog.glyph(0xF0140) : Catalog.glyph(0xF0054)
                size: row.kind === "choice" ? row.g.arrowSize + 3 : row.g.arrowSize
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
                text: row.opt.value()
                color: row.g.value
                visible: text !== ""
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: btnText.implicitWidth + 32
                height: 34
                radius: height / 2
                color: row.active && row.hovered ? Theme.mix(row.g.field, Theme.text, 0.1) : row.g.field
                opacity: row.active ? 1 : 0.5
                SText {
                    id: btnText
                    anchors.centerIn: parent
                    size: 15
                    text: row.opt.action
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
        Rectangle {
            id: field
            readonly property bool valid: row.opt.valid(input.text)
            implicitWidth: row.g.fieldWidth
            implicitHeight: row.g.fieldHeight
            radius: row.g.fieldRadius
            color: row.g.field
            border.width: input.activeFocus ? 1 : 0
            border.color: valid ? Theme.mix(row.g.field, Theme.text, 0.25) : Theme.danger

            function edit(): void {
                input.forceActiveFocus();
                input.selectAll();
            }
            function finish(apply: bool): void {
                if (apply && valid && input.text !== row.opt.value())
                    row.opt.apply(input.text);
                input.text = Qt.binding(() => row.opt.value());
                if (input.activeFocus) // finished by key; a click elsewhere keeps its own focus
                    row.host.focusRoot();
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                x: row.g.fieldPad
                width: parent.width - 2 * row.g.fieldPad
                clip: true
                text: row.opt.value()
                color: row.g.label
                selectionColor: Theme.surfaceHigh
                selectedTextColor: Theme.text
                selectByMouse: true
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(row.g.textSize * Theme.fontScale)
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.text
                    visible: input.cursorVisible
                }
                onActiveFocusChanged: if (activeFocus)
                    row.host.focusRow(row.flatIndex)
                else if (text !== row.opt.value())
                    field.finish(true)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                        field.finish(true);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        field.finish(false);
                        event.accepted = true;
                    }
                }
            }

            SText {
                anchors.verticalCenter: parent.verticalCenter
                x: row.g.fieldPad
                visible: input.text === "" && !input.activeFocus
                text: row.opt.placeholder ?? ""
                color: row.g.placeholder
            }
        }
    }
}
