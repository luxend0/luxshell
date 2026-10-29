import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.polkit

// Polkit prompt, variant A: the island grows into a card in the lock screen's language
// (services/Polkit drives it, registry id "polkit", opened by the service on the focused monitor).
//
//   who asks      app icon + label from the action id (or the action's own icon)
//   identities    avatar disc (~/.face, else the initial); several: the selected one large in
//                 the middle, the others small and dimmed beside it, chevrons beside the name
//   request       polkit's message, up to Theme.polkit.messageLines lines
//   password      the lock screen's pill and dots, submit disc at its end; wrong password: shake +
//                 "Wrong password, try again"; success: a check, then the card closes
//   footer        Details (action id, identity, icon; the card grows) and Cancel
//
// Keys: type the password, Enter submits, Esc cancels the request, Tab / Shift+Tab or Left /
// Right switch the identity, Backspace (Ctrl: all), Ctrl+U clears. The island window holds the
// keyboard exclusively while this panel is open (registry flag "exclusive", IslandWindow).
// Clicking outside does nothing: the request stays until it is answered or cancelled.
PanelBase {
    id: root

    readonly property QtObject p: Theme.polkit
    readonly property QtObject g: Theme.lock
    property bool detailsOpen: false

    // what the card shows (a copy in the service, kept while the card fades out)
    readonly property var info: Polkit.view
    readonly property var ids: info.identities
    readonly property int sel: info.selected
    readonly property var who: ids[sel] ?? null
    readonly property bool several: ids.length > 1

    // stacked top to bottom (Theme.polkit)
    readonly property real headY: p.padTop
    readonly property real discsY: headY + p.headHeight + p.identityTop
    readonly property real nameY: discsY + p.avatarSize + p.nameTop
    readonly property real messageY: nameY + p.nameHeight + p.messageTop
    readonly property real pillY: messageY + message.height + p.pillTop
    readonly property real noteY: pillY + p.pillHeight + p.noteTop
    readonly property real footY: noteY + p.noteHeight + p.footTop
    readonly property real closedHeight: footY + p.buttonHeight + p.padBottom
    readonly property real openHeight: closedHeight + p.detailsTop + details.height

    preferredWidth: p.width
    preferredHeight: Math.min(p.maxHeight, Math.round(detailsOpen ? openHeight : closedHeight))
    maxHeight: p.maxHeight
    cornerRadius: p.radius

    function focusDefault() {
        keys.forceActiveFocus();
    }

    // ---- keyboard ------------------------------------------------------------------------
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            const ctrl = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
            if (k === Qt.Key_Return || k === Qt.Key_Enter)
                Polkit.submit();
            else if (k === Qt.Key_Escape)
                Polkit.cancel();
            else if (k === Qt.Key_Backspace)
                Polkit.erase(ctrl);
            else if (ctrl && k === Qt.Key_U)
                Polkit.erase(true);
            else if (k === Qt.Key_Tab || (k === Qt.Key_Right && !ctrl))
                Polkit.step(1);
            else if (k === Qt.Key_Backtab || (k === Qt.Key_Left && !ctrl))
                Polkit.step(-1);
            else if (k === Qt.Key_CapsLock)
                Polkit.capsKey();
            else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127)
                Polkit.type(event.text, (event.modifiers & Qt.ShiftModifier) !== 0);
            event.accepted = true; // Esc must not reach PanelHost (it would only close, not cancel)
        }

        MouseArea {
            anchors.fill: parent
            onPressed: keys.forceActiveFocus()
        }
    }

    // ---- who asks ------------------------------------------------------------------------
    Row {
        id: head
        x: Math.round((root.width - width) / 2)
        y: root.headY
        height: root.p.headHeight
        spacing: root.p.headGap

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            source: root.info.requester.icon
            size: root.p.headIcon
            fallback: "lock"
            fallbackColor: root.g.fg(0.7)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - 2 * root.p.padX - root.p.headIcon - root.p.headGap)
            elide: Text.ElideRight
            text: root.info.requester.label
            color: root.g.fg(0.7)
            font.family: Theme.fontFamily
            font.pixelSize: root.p.headSize
            font.weight: Font.Medium
        }
    }

    // ---- identities: selected disc centred, the others beside it ---------------------------
    Repeater {
        model: root.ids.length // count only: a switch moves the same discs instead of new ones

        PkAvatar {
            id: disc
            required property int index
            readonly property var modelData: root.ids[index] ?? {
                "name": "",
                "avatar": ""
            }
            readonly property int off: index - root.sel
            readonly property bool chosen: off === 0
            readonly property real big: root.p.avatarSize
            readonly property real small: root.p.avatarSmall
            readonly property real gap: root.p.avatarGap
            readonly property real cx: off === 0 ? 0 : Math.sign(off) * (big / 2 + gap + small / 2 + (Math.abs(off) - 1) * (small + gap))

            name: modelData.name
            picture: modelData.avatar
            size: chosen ? big : small
            x: root.width / 2 + cx - size / 2
            y: root.discsY + (big - size) / 2
            opacity: chosen ? 1 : Math.abs(off) > 2 ? 0 : root.p.avatarDim
            visible: opacity > 0.01

            Behavior on size {
                Anim {
                    ms: root.p.switchMs
                }
            }
            Behavior on x {
                Anim {
                    ms: root.p.switchMs
                }
            }
            Behavior on opacity {
                Anim {
                    ms: root.p.switchMs
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !disc.chosen
                cursorShape: Qt.PointingHandCursor
                onClicked: Polkit.select(disc.index)
            }
        }
    }

    // ---- name (+ switch chevrons) --------------------------------------------------------
    Text {
        id: name
        x: Math.round((root.width - width) / 2)
        y: root.nameY
        width: Math.min(implicitWidth, root.width - 2 * (root.p.padX + root.p.switchSize + root.p.switchGap))
        height: root.p.nameHeight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: !root.who ? "" : root.who.group ? `${root.who.name} (group)` : root.who.display !== "" ? root.who.display : root.who.name
        color: root.g.fg(root.g.nameAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.p.nameSize
        font.weight: root.g.nameWeight
        font.letterSpacing: root.g.nameSpacing
    }
    Repeater {
        model: root.several ? [-1, 1] : []

        Item {
            required property int modelData
            width: root.p.switchSize + 12
            height: root.p.nameHeight
            x: modelData < 0 ? name.x - root.p.switchGap - width + 6 : name.x + name.width + root.p.switchGap - 6
            y: root.nameY

            Icon {
                anchors.centerIn: parent
                name: parent.modelData < 0 ? "chevron-left" : "chevron-right"
                size: root.p.switchSize
                stroke: 2.2
                color: root.g.fg(arrowArea.containsMouse ? 0.9 : 0.45)
            }
            MouseArea {
                id: arrowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Polkit.step(parent.modelData)
            }
        }
    }

    // ---- request -------------------------------------------------------------------------
    Text {
        id: message
        x: root.p.padX
        y: root.messageY
        width: root.width - 2 * root.p.padX
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: root.p.messageLines
        elide: Text.ElideRight
        lineHeight: root.p.messageLine
        text: root.info.message
        color: root.g.fg(root.p.messageAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.p.messageSize
        font.weight: Font.Medium
    }

    // ---- password ------------------------------------------------------------------------
    PkPill {
        id: pill
        x: Math.round((root.width - width) / 2)
        y: root.pillY
        onSubmitClicked: {
            keys.forceActiveFocus();
            Polkit.submit();
        }
    }

    Text {
        readonly property string line: Polkit.note !== "" ? Polkit.note : Polkit.caps && Polkit.phase === "input" ? "Caps Lock is on" : ""
        x: root.p.padX
        y: root.noteY
        width: root.width - 2 * root.p.padX
        height: root.p.noteHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: line
        color: root.g.fg(Polkit.noteError ? root.p.noteErrorAlpha : root.p.noteAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.p.noteSize
        font.weight: Font.Medium
        opacity: line !== "" ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: root.g.pillIn
            }
        }
    }

    // ---- footer --------------------------------------------------------------------------
    PkButton {
        x: root.p.padX + root.p.detailsPad + 4 - root.p.buttonPadX // text on the details' label column
        y: root.footY
        text: "Details"
        flat: true
        chevron: "chevron-down"
        turn: root.detailsOpen ? 1 : 0
        Behavior on turn {
            Anim {
                ms: root.p.detailsMs
            }
        }
        onClicked: {
            root.detailsOpen = !root.detailsOpen;
            keys.forceActiveFocus();
        }
    }
    PkButton {
        x: root.width - root.p.padX - width
        y: root.footY
        text: "Cancel"
        onClicked: Polkit.cancel()
    }

    // ---- details -------------------------------------------------------------------------
    Rectangle {
        id: details
        readonly property var rows: {
            const out = [["Action", root.info.actionId]];
            if (root.who)
                out.push(["Identity", `${root.who.group ? "unix-group" : "unix-user"}:${root.who.name} · ${root.who.group ? "gid" : "uid"} ${root.who.uid}`]);
            if (root.info.iconName !== "")
                out.push(["Icon", root.info.iconName]);
            return out;
        }
        x: root.p.padX
        y: root.footY + root.p.buttonHeight + root.p.detailsTop
        width: root.width - 2 * root.p.padX
        height: 2 * root.p.detailsPad + rows.length * root.p.detailsRow
        radius: root.p.detailsRadius
        color: Qt.rgba(1, 1, 1, root.p.detailsFill)
        opacity: root.detailsOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            Anim {
                ms: root.p.detailsMs
            }
        }

        Column {
            x: root.p.detailsPad + 4
            y: root.p.detailsPad
            width: parent.width - 2 * x

            Repeater {
                model: details.rows

                Item {
                    required property var modelData
                    width: parent.width
                    height: root.p.detailsRow

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[0]
                        color: root.g.fg(0.5)
                        font.family: Theme.fontFamily
                        font.pixelSize: root.p.detailsSize
                        font.weight: Font.Medium
                    }
                    Text {
                        x: root.p.detailsLabel
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: parent.modelData[1]
                        color: root.g.fg(0.86)
                        font.family: Theme.monoFamily
                        font.pixelSize: root.p.detailsSize
                    }
                }
            }
        }
    }
}
