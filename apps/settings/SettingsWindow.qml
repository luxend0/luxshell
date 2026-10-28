import QtQuick
import Quickshell
import qs.config
import qs.widgets

// Settings app window (ref/12), 1:1 with the video: search field and page list on
// the left, back/forward, header card and cards of rows on the right, scrolling.
// Own toplevel (FloatingWindow, fixed size so Hyprland floats it; SettingsApp adds
// a rule for no border/shadow/blur). Transparent outside the 32 px corners.
//
// Keys
//   typing            search across all pages (results stay editable in place)
//   Ctrl+F, /         search field         Esc   clear search, else close
//   Up/Down           page (sidebar) or row (page)
//   Tab, Shift+Tab    sidebar <-> page; Right/Enter in the sidebar enter the page
//   Left/Right        slider, choice, swatch, switch; Left on other rows: sidebar
//   Enter/Space       toggle / open / pick / edit       Alt+Left/Right  back/forward
//   PgUp/PgDn, Home/End scroll                          Ctrl+W, Ctrl+Q  close
// Mouse: everything clickable, sliders drag, wheel scrolls, back/forward buttons.
FloatingWindow {
    id: win

    readonly property QtObject g: Theme.settings

    title: SettingsApp.title
    screen: Quickshell.screens.find(s => s.name === SettingsApp.screenName) ?? null
    implicitWidth: g.width
    implicitHeight: g.height
    minimumSize: Qt.size(g.width, g.height)
    maximumSize: Qt.size(g.width, g.height)
    color: "transparent"

    onClosed: SettingsApp.hide()

    // ---- state -----------------------------------------------------------------
    property bool kb: false              // keyboard navigation in use: focus rings shown
    property string zone: "sidebar"      // "sidebar" | "content"
    property int focusIndex: 0
    readonly property bool searching: SettingsApp.query.trim() !== ""
    readonly property var page: Catalog.pageById(SettingsApp.page)
    readonly property var sections: searching ? Catalog.search(SettingsApp.query) : page.sections
    readonly property var flatCount: sections.reduce((n, s) => n + s.options.length, 0)
    readonly property int pageIndex: Catalog.visiblePages.findIndex(p => p.id === page.id)

    // controller handed to every row
    readonly property QtObject host: QtObject {
        readonly property bool kb: win.kb
        readonly property string zone: win.zone
        readonly property int focusIndex: win.focusIndex
        property var items: ({})
        function register(i: int, item: Item): void {
            items[i] = item;
        }
        function unregister(i: int, item: Item): void {
            if (items[i] === item)
                delete items[i];
        }
        function openMenu(row: Item, opt: var): void {
            menu.show(row, opt);
        }
        function focusRow(i: int): void {
            win.zone = "content";
            win.focusIndex = i;
        }
        function focusRoot(): void {
            keys.forceActiveFocus();
        }
    }

    onSectionsChanged: {
        focusIndex = 0;
        menu.close();
    }

    Connections {
        target: SettingsApp
        function onPageShown() {
            flick.contentY = 0;
            fade.restart();
        }
        function onSearchRequested() {
            search.forceActiveFocus();
            search.cursorPosition = search.text.length;
        }
    }

    function moveFocus(d: int): void {
        if (flatCount === 0)
            return;
        focusIndex = Math.max(0, Math.min(flatCount - 1, focusIndex + d));
        reveal(host.items[focusIndex]);
    }

    // scroll the page so item (a row) is fully visible
    function reveal(item: Item): void {
        if (!item)
            return;
        const p = item.mapToItem(flick.contentItem, 0, 0);
        const top = p.y - 12, bottom = p.y + item.height + 12;
        if (top < flick.contentY)
            scrollTo(top);
        else if (bottom > flick.contentY + flick.height)
            scrollTo(bottom - flick.height);
    }

    function scrollTo(y: real): void {
        scrollAnim.stop();
        scrollAnim.to = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y));
        scrollAnim.start();
    }
    function scrollBy(dy: real): void {
        scrollTo((scrollAnim.running ? scrollAnim.to : flick.contentY) + dy);
    }

    function goPage(d: int): void {
        const list = Catalog.visiblePages;
        const i = searching ? (d > 0 ? 0 : list.length - 1) : Math.max(0, Math.min(list.length - 1, pageIndex + d));
        SettingsApp.navigate(list[i].id);
    }

    function onKey(event): void {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        const alt = event.modifiers & Qt.AltModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        event.accepted = true;
        kb = true;
        if (menu.shown) {
            menu.key(event);
            return;
        }
        if (alt && k === Qt.Key_Left)
            return SettingsApp.back();
        if (alt && k === Qt.Key_Right)
            return SettingsApp.forward();
        if (ctrl && (k === Qt.Key_W || k === Qt.Key_Q))
            return SettingsApp.hide();
        if ((ctrl && k === Qt.Key_F) || (k === Qt.Key_Slash && !ctrl && !alt)) {
            search.forceActiveFocus();
            search.selectAll();
            return;
        }
        const row = host.items[focusIndex];
        switch (k) {
        case Qt.Key_Escape:
            if (searching)
                SettingsApp.query = "";
            else
                SettingsApp.hide();
            return;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (k === Qt.Key_Backtab || shift)
                zone = zone === "content" ? "sidebar" : (flatCount > 0 ? "content" : "sidebar");
            else
                zone = zone === "sidebar" && flatCount > 0 ? "content" : "sidebar";
            if (zone === "content")
                reveal(host.items[focusIndex]);
            return;
        case Qt.Key_Up:
        case Qt.Key_Down:
            if (zone === "sidebar")
                goPage(k === Qt.Key_Down ? 1 : -1);
            else
                moveFocus(k === Qt.Key_Down ? 1 : -1);
            return;
        case Qt.Key_Right:
        case Qt.Key_Left:
            if (zone === "sidebar") {
                if (k === Qt.Key_Right && flatCount > 0) {
                    zone = "content";
                    reveal(host.items[focusIndex]);
                }
            } else if (!(row && row.adjust(k === Qt.Key_Right ? 1 : -1)) && k === Qt.Key_Left) {
                zone = "sidebar";
            }
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (zone === "sidebar") {
                if (flatCount > 0)
                    zone = "content";
            } else if (row) {
                row.activate();
            }
            return;
        case Qt.Key_PageDown:
            return scrollBy(flick.height * 0.8);
        case Qt.Key_PageUp:
            return scrollBy(-flick.height * 0.8);
        case Qt.Key_Home:
            return scrollTo(0);
        case Qt.Key_End:
            return scrollBy(flick.contentHeight);
        }
        // anything printable starts a search
        if (!ctrl && !alt && event.text.length === 1 && event.text >= " ") {
            search.forceActiveFocus();
            search.insert(search.cursorPosition, event.text);
            SettingsApp.query = search.text;
            return;
        }
        event.accepted = false;
    }

    // ---- body ------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: win.g.radius
        color: win.g.window
    }

    Rectangle {
        width: win.g.sidebarWidth
        height: parent.height
        topLeftRadius: win.g.radius
        bottomLeftRadius: win.g.radius
        color: win.g.sidebar
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => win.onKey(event)
        Component.onCompleted: {
            if (SettingsApp.query !== "") {
                search.forceActiveFocus();
                search.cursorPosition = search.text.length;
            } else {
                forceActiveFocus();
            }
        }

        // click on empty space: leave text fields; mouse back/forward buttons
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton)
                    SettingsApp.back();
                else if (mouse.button === Qt.ForwardButton)
                    SettingsApp.forward();
                keys.forceActiveFocus();
            }
        }
    }

    // any pointer movement hides the keyboard focus rings (on the content item: sees every child)
    HoverHandler {
        onPointChanged: win.kb = false
    }

    // ---- search field ------------------------------------------------------------
    Rectangle {
        x: win.g.searchX
        y: win.g.searchY
        width: win.g.searchWidth
        height: win.g.searchHeight
        radius: win.g.searchRadius
        color: win.g.search
        border.width: search.activeFocus ? 1 : 0
        border.color: Theme.mix(win.g.search, Theme.text, 0.18)

        Icon {
            x: win.g.lensX - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: win.g.lensSize
            stroke: 2.4
            color: win.g.placeholder
        }

        TextInput {
            id: search
            x: win.g.searchTextX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            clip: true
            text: SettingsApp.query
            color: win.g.label
            selectionColor: Theme.surfaceHigh
            selectedTextColor: Theme.text
            selectByMouse: true
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(win.g.textSize * Theme.fontScale)
            cursorDelegate: Rectangle {
                width: 2
                color: Theme.text
                visible: search.cursorVisible
            }
            onTextEdited: SettingsApp.query = text
            onActiveFocusChanged: if (activeFocus)
                win.zone = "sidebar"

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    if (text !== "")
                        SettingsApp.query = "";
                    keys.forceActiveFocus();
                    break;
                case Qt.Key_Down:
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Tab:
                    keys.forceActiveFocus();
                    if (win.flatCount > 0) {
                        win.kb = true;
                        win.zone = "content";
                        win.focusIndex = 0;
                        win.reveal(win.host.items[0]);
                    }
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        SText {
            x: win.g.searchTextX
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Search Settings"
            color: win.g.placeholder
        }
    }

    // ---- sidebar -----------------------------------------------------------------
    Rectangle {
        id: highlight
        x: win.g.sideX
        y: Math.round(win.g.sideTop + Math.max(0, win.pageIndex) * win.g.sideStep)
        width: win.g.sideWidth
        height: win.g.sideRowHeight
        radius: win.g.sideRadius
        color: win.g.selected
        opacity: win.searching ? 0 : 1
        Behavior on y {
            Anim {
                ms: win.g.highlightMove
            }
        }
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }

    Repeater {
        model: Catalog.visiblePages

        SideItem {
            required property var modelData
            required property int index
            x: win.g.sideX
            y: Math.round(win.g.sideTop + index * win.g.sideStep)
            page: modelData
            current: !win.searching && index === win.pageIndex
            ring: win.kb && win.zone === "sidebar" && !search.activeFocus && index === win.pageIndex
            onClicked: {
                keys.forceActiveFocus();
                SettingsApp.navigate(modelData.id);
            }
        }
    }

    // ---- back / forward ------------------------------------------------------------
    NavButton {
        x: win.g.navX
        y: win.g.navY
        glyph: Catalog.glyph(0xF004D)
        active: SettingsApp.canBack
        onClicked: SettingsApp.back()
    }
    NavButton {
        x: win.g.navX + win.g.navWidth + win.g.navGap
        y: win.g.navY
        glyph: Catalog.glyph(0xF0054)
        active: SettingsApp.canForward
        onClicked: SettingsApp.forward()
    }

    // ---- page ----------------------------------------------------------------------
    Flickable {
        id: flick
        x: win.g.sidebarWidth
        y: win.g.pageTop
        width: win.width - x
        height: win.height - y
        clip: true
        contentWidth: width
        contentHeight: column.height + win.g.padBottom
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: !menu.shown

        Anim {
            id: scrollAnim
            target: flick
            property: "contentY"
            ms: 220
        }

        Column {
            id: column
            x: win.g.cardX - flick.x
            width: win.g.cardWidth

            NumberAnimation on opacity {
                id: fade
                from: 0
                to: 1
                duration: Motion.ms(win.g.pageFade)
                easing.type: Easing.OutCubic
            }

            PageHeader {
                visible: !win.searching
                page: win.page
            }

            Repeater {
                model: win.sections

                SectionBlock {
                    required property var modelData
                    required property int index
                    section: modelData
                    host: win.host
                    tight: win.searching && index === 0
                    firstIndex: {
                        let n = 0;
                        for (let i = 0; i < index; i++)
                            n += win.sections[i].options.length;
                        return n;
                    }
                }
            }

            Item {
                visible: win.searching && win.flatCount === 0
                width: parent.width
                height: 120

                SText {
                    anchors.centerIn: parent
                    text: `No settings match “${SettingsApp.query.trim()}”`
                    color: win.g.value
                }
            }
        }
    }

    // ---- scrollbar (ref/12: 8 px handle at the right edge, no track) ----------------
    Rectangle {
        id: handle
        readonly property real track: win.height - win.g.pageTop - 2 * win.g.scrollInset
        visible: flick.visibleArea.heightRatio < 0.999
        x: win.g.scrollX
        y: win.g.pageTop + win.g.scrollInset + flick.visibleArea.yPosition * track
        width: win.g.scrollWidth
        height: Math.max(40, flick.visibleArea.heightRatio * track)
        radius: width / 2
        color: scrollArea.pressed || scrollArea.containsMouse ? Theme.mix(win.g.scrollbar, Theme.text, 0.15) : win.g.scrollbar

        MouseArea {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            property real startY: 0
            property real startContent: 0
            onPressed: mouse => {
                startY = mapToItem(null, mouse.x, mouse.y).y;
                startContent = flick.contentY;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const dy = mapToItem(null, mouse.x, mouse.y).y - startY;
                const range = flick.contentHeight - flick.height;
                const free = handle.track - handle.height;
                flick.contentY = Math.max(0, Math.min(range, startContent + dy / Math.max(1, free) * range));
            }
        }
    }

    Menu {
        id: menu
        anchors.fill: parent
        onClosed: keys.forceActiveFocus()
    }
}
