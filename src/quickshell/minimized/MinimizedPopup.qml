import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Minimized-windows picker (Hyprland). Windows are "minimized" by moving them to
// the hidden special workspace `special:minimized` (see scripts/minimize.sh). This shows
// them as a strip of cards, each with the app's own icon over a thumbnail of the window.
// Enter / click restores, Backspace closes the highlighted window.
Item {
    id: root
    focus: true

    readonly property string specialName: "special:minimized"

    property var windows: []
    property int currentIndex: 0
    property bool loaded: false

    function s(val) {
        return Scaler.s(val);
    }

    function refresh() {
        thumbRev++;
        listProc.running = false;
        listProc.running = true;
    }

    function clampIndex() {
        if (windows.length === 0) currentIndex = 0;
        else currentIndex = Math.max(0, Math.min(currentIndex, windows.length - 1));
    }

    function move(delta) {
        if (windows.length === 0) return;
        currentIndex = (currentIndex + delta + windows.length) % windows.length;
        view.positionViewAtIndex(currentIndex, ListView.Contain);
    }

    // Thumbnails are written by scripts/minimize.sh at minimize time.
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/serpantinum/minimized"

    // Bumped on every refresh so a thumbnail that was rewritten (or missing on an earlier
    // load) is re-read instead of served from Qt's pixmap cache.
    property int thumbRev: 0

    function thumbFor(addr) {
        return "file://" + thumbDir + "/" + addr + ".jpg?v=" + thumbRev;
    }

    function iconFor(cls) {
        let c = cls || "";
        let entry = (typeof DesktopEntries !== "undefined") ? DesktopEntries.heuristicLookup(c) : null;
        let name = (entry && entry.icon) ? entry.icon : c.toLowerCase();
        // iconPath(name, true) yields "" when the theme has no such icon, so we can chain fallbacks.
        let path = Quickshell.iconPath(name, true);
        if (!path) path = Quickshell.iconPath("application-default-icon", true);
        if (!path) path = Quickshell.iconPath("application-x-executable", true);
        return path || "";
    }

    function restoreSelected() {
        if (windows.length === 0) return;
        let addr = windows[currentIndex].address;
        // Move onto the workspace that is active now, then focus the window.
        Quickshell.execDetached(["bash", "-c",
            "ws=$(hyprctl activeworkspace -j | jq -r .id); " +
            "hyprctl dispatch \"hl.dsp.window.move({workspace=$ws, window=\\\"address:$1\\\"})\" >/dev/null; " +
            "hyprctl dispatch \"hl.dsp.focus({window=\\\"address:$1\\\"})\" >/dev/null",
            "_", addr]);
        Quickshell.execDetached(["serpantinum", "msg", "close"]);
    }

    function closeSelected() {
        if (windows.length === 0) return;
        let addr = windows[currentIndex].address;
        Quickshell.execDetached(["bash", "-c",
            "hyprctl dispatch \"hl.dsp.window.close({window=\\\"address:$1\\\"})\" >/dev/null",
            "_", addr]);
        // The compositor drops the window asynchronously; re-list shortly after.
        refreshSoon.restart();
    }

    Timer {
        id: refreshSoon
        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        isReady = visible;
        if (visible) {
            currentIndex = 0;
            forceActiveFocus();
            focusTimer.restart();
            refresh();
        }
    }

    Component.onCompleted: {
        isReady = visible;
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            refresh();
        }
    }

    Process {
        id: listProc
        command: ["bash", "-c",
            "hyprctl clients -j | jq -c --arg ws '" + root.specialName + "' " +
            "'[.[] | select(.workspace.name == $ws) | {address, class, title}]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = [];
                try { parsed = JSON.parse(this.text.trim() || "[]"); } catch (e) { parsed = []; }
                root.windows = parsed;
                root.loaded = true;
                root.clampIndex();
            }
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.restoreSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            root.closeSelected();
            event.accepted = true;
        }
    }

    // ---- look: same language as the wallpaper picker (skewed cards, enlarged selection) ----
    readonly property real itemWidth: s(260)
    readonly property real itemHeight: s(300)
    readonly property real borderWidth: s(3)
    readonly property real skewFactor: -0.35
    readonly property real selectedCenterOffset: (skewFactor * itemHeight) / 2

    property bool isReady: false

    ListView {
        id: view
        anchors.fill: parent
        opacity: root.isReady ? 1.0 : 0.0
        anchors.margins: root.isReady ? 0 : root.s(40)
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on anchors.margins { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }

        spacing: 0
        orientation: ListView.Horizontal
        clip: false
        interactive: false
        model: root.windows
        currentIndex: root.currentIndex

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((root.itemWidth * 1.5 + root.s(4)) / 2) + root.selectedCenterOffset
        preferredHighlightEnd: (width / 2) + ((root.itemWidth * 1.5 + root.s(4)) / 2) + root.selectedCenterOffset
        highlightMoveDuration: 400

        header: Item { width: Math.max(0, (view.width / 2) - ((root.itemWidth * 1.5) / 2) + root.selectedCenterOffset) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((root.itemWidth * 1.5) / 2) - root.selectedCenterOffset) }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                let d = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                if (d !== 0) root.move(d > 0 ? -1 : 1);
                wheel.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot
            required property var modelData
            required property int index

            readonly property bool enlarged: ListView.isCurrentItem
            readonly property int dist: Math.abs(index - view.currentIndex)
            readonly property real sideScale: Math.max(0.58, Math.pow(0.88, Math.max(0, dist - 1)))

            readonly property real dynamicRadius: {
                let baseR = ThemeBackend.borderRadius;
                if (baseR <= 0) return 0;
                let k = Math.min(1.0, Math.pow(baseR / 48, 2));
                let decay = Math.max(0.45, Math.pow(0.85, dist));
                return baseR * (1.0 - k * (1.0 - decay));
            }

            width: enlarged ? (root.itemWidth * 1.5 + root.s(4)) : (root.itemWidth * 0.48 * sideScale)
            height: enlarged ? (root.itemHeight + root.s(30)) : (root.itemHeight * Math.max(0.62, Math.pow(0.90, Math.max(0, dist - 1))))
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: root.s(25)
            z: enlarged ? 100 : Math.max(1, 50 - dist)

            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            // The skewed parallelogram card.
            Item {
                id: skewedWrapper
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -(root.skewFactor * height) / 2
                width: parent.width - root.s(4)
                height: parent.height
                transform: Matrix4x4 { property real s: root.skewFactor; matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = delegateRoot.index;
                        if (delegateRoot.enlarged) root.restoreSelected();
                    }
                }

                Item {
                    id: cardFrame
                    anchors.fill: parent
                    anchors.margins: root.borderWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        color: delegateRoot.enlarged ? ThemeBackend.surface1 : ThemeBackend.surface0
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        visible: false
                        layer.enabled: true
                    }

                    // Window thumbnail, clipped to the card shape. Only cards near the selection
                    // load one; images decode async at a fixed small size, so this stays cheap.
                    Item {
                        anchors.fill: parent
                        layer.enabled: thumb.status === Image.Ready
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: cardMask
                        }

                        Image {
                            id: thumb
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: root.s(-50)
                            // same oversize-and-counter-skew trick as the wallpaper picker, so the
                            // picture stays upright while the card is skewed
                            width: (root.itemWidth * 1.5) + ((root.itemHeight + root.s(30)) * Math.abs(root.skewFactor)) + root.s(50)
                            height: root.itemHeight + root.s(30)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: Math.round(width * 0.6)
                            sourceSize.height: Math.round(height * 0.6)
                            source: delegateRoot.dist <= 4 ? root.thumbFor(delegateRoot.modelData.address) : ""
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            transform: Matrix4x4 { property real s: -root.skewFactor; matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        }

                        // Darken so the icon and title stay readable on any screenshot.
                        Rectangle {
                            anchors.fill: parent
                            visible: thumb.status === Image.Ready
                            color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, delegateRoot.enlarged ? 0.40 : 0.65)
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        color: "transparent"
                        border.width: delegateRoot.enlarged ? root.s(2) : 0
                        border.color: ThemeBackend.mauve
                    }
                }
            }

            // Content stays upright (not skewed): the app's own icon in the middle of the card.
            Column {
                anchors.centerIn: parent
                spacing: root.s(10)
                width: parent.width * 0.62

                Image {
                    id: iconImg
                    visible: source.toString() !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: delegateRoot.enlarged ? root.s(120) : root.s(56) * delegateRoot.sideScale
                    height: width
                    sourceSize.width: root.s(128)
                    sourceSize.height: root.s(128)
                    fillMode: Image.PreserveAspectFit
                    source: root.iconFor(delegateRoot.modelData.class)
                    opacity: delegateRoot.enlarged ? 1.0 : 0.75
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                Text {
                    // last-resort fallback when no icon resolves at all
                    visible: iconImg.source.toString() === ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (delegateRoot.modelData.class || "?").charAt(0).toUpperCase()
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: delegateRoot.enlarged ? root.s(80) : root.s(36)
                    height: iconImg.height
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: parent.width
                    visible: delegateRoot.enlarged
                    text: delegateRoot.modelData.title || delegateRoot.modelData.class
                    color: ThemeBackend.text
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(14)
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: delegateRoot.enlarged
                    text: delegateRoot.modelData.class
                    color: ThemeBackend.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                }
            }
        }
    }

    // Pill bar above the strip (same treatment as the wallpaper picker's filter bar).
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: root.isReady ? root.s(40) : root.s(-75)
        anchors.horizontalCenter: parent.horizontalCenter
        Behavior on anchors.topMargin { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
        opacity: root.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        z: 200
        height: root.s(48)
        width: barRow.width + root.s(28)
        radius: ThemeBackend.borderRadius
        color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.90)
        border.color: ThemeBackend.surface0
        border.width: 1

        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: root.s(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰖲"
                color: ThemeBackend.mauve
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(18)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.windows.length > 0
                    ? I18n.t("minimized.title") + "  ·  " + (root.currentIndex + 1) + " / " + root.windows.length
                    : (root.loaded ? I18n.t("minimized.empty") : I18n.t("minimized.title"))
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
                font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.windows.length > 0
                text: I18n.t("minimized.hint")
                color: ThemeBackend.overlay0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
            }
        }
    }
}
