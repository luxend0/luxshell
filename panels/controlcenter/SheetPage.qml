import QtQuick
import qs.config
import qs.widgets

// Content of a control center sheet (ref/09): header with back disc, title and a
// switch (or an icon button), then SheetSections in a column. Reports its
// natural height; the panel clamps it (Theme.cc.sheet.maxHeight) and sets this
// item's height, the column scrolls when it does not fit.
//
// The panel root keeps the keyboard focus (panels/ControlCenter.qml); an item
// that takes real focus (password field) emits releaseFocus when done.
//
// backButton: false for a sheet shown as its own island panel (panels/SheetMenu, bar
// menus): no back disc, the title moves to the captions' line. scrollTo(item) brings a
// section to the top of the column (sound menu opened on its input part).
FocusScope {
    id: page

    readonly property QtObject sh: Theme.cc.sheet

    property string title
    property bool hasSwitch: false
    property bool switchOn: false
    property string actionIcon: ""      // icon button at the right instead of a switch
    property bool backButton: true      // false: bar menu (panels/SheetMenu), nothing to go back to
    readonly property Item defaultItem: backDisc

    signal back
    signal toggled          // switch flipped or icon button pressed
    signal releaseFocus     // give the keyboard back to the panel

    default property alias content: body.data

    implicitWidth: Theme.cc.width - 2 * sh.inset
    implicitHeight: sh.headerHeight + body.implicitHeight + sh.padBottom

    // keep the keyboard selection inside the visible part of the column
    function reveal(item: Item): void {
        let p = item;
        while (p && p !== body)
            p = p.parent;
        if (!p)
            return;
        const y = item.mapToItem(body, 0, 0).y;
        if (y < flick.contentY)
            flick.contentY = y;
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = Math.min(y + item.height - flick.height, flick.contentHeight - flick.height);
    }
    Connections {
        target: Cc
        function onCurrentChanged() {
            if (Cc.kb && Cc.current)
                page.reveal(Cc.current);
        }
    }

    // section (or any item of the column) at the top of the visible part, as far as it scrolls
    function scrollTo(item: Item): void {
        if (!item)
            return;
        // 2 px into the item: the bottom edge of the row above stays out of the clip line
        const y = Math.round(item.mapToItem(body, 0, 0).y) + 2;
        flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
    }

    // ---- header ---------------------------------------------------------------
    IconDisc {
        id: backDisc
        visible: page.backButton
        x: page.sh.backX
        y: Math.round(page.sh.headerY - height / 2)
        onClicked: page.back()
    }

    SheetText {
        x: page.backButton ? page.sh.titleX : page.sh.captionX
        width: (sw.visible ? sw.x : action.visible ? action.x : page.width) - x - 16
        capY: page.sh.headerY
        px: page.sh.titleSize
        text: page.title
        color: page.sh.textColor
        font.weight: Font.Medium
    }

    Switch {
        id: sw
        x: page.width - page.sh.switchRight - width
        y: Math.round(page.sh.headerY - height / 2)
        visible: page.hasSwitch
        on: page.switchOn
        onToggled: page.toggled()
    }

    IconDisc {
        id: action
        x: page.width - page.sh.switchRight - width
        y: Math.round(page.sh.headerY - height / 2)
        visible: !page.hasSwitch && page.actionIcon !== ""
        icon: page.actionIcon
        iconSize: 16
        onClicked: page.toggled()
    }

    // ---- sections -------------------------------------------------------------
    Flickable {
        id: flick
        y: page.sh.headerHeight
        width: page.width
        height: Math.max(0, page.height - y - page.sh.padBottom)
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: contentHeight > height + 0.5
        interactive: clip
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
        }
    }
}
