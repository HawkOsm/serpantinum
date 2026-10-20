pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Hover preview for dock apps: a strip with one card per window of the hovered app, each showing the
// window's latest snapshot. Separate from DockAppMenuController (the right-click menu).
Item {
    id: controller

    property bool isVisible: false
    property var screen: null
    property real targetX: 0
    property real targetY: 0
    property string dockPosition: "bottom"
    property string desktopId: ""
    property string appName: ""
    property string appIcon: ""
    property string groupKey: ""
    property var windows: []
    property real buttonSize: 0
    // bumped on every show so snapshots rewritten since the last hover are re-read
    property int revision: 0

    property var _pending: null

    // Called while the pointer is on a dock button: shows the preview after a short delay.
    function request(scr, posX, posY, dockPos, dId, name, icon, key, winList, btnSize) {
        if (!winList || winList.length === 0) { controller.scheduleHide(); return; }
        if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible) return;   // never over the right-click menu
        hideTimer.stop();
        controller._pending = { scr: scr, x: posX, y: posY, pos: dockPos, id: dId, name: name, icon: icon, key: key, wins: winList, btn: btnSize };
        if (controller.isVisible) {
            controller.show();   // a preview is already open: switch to this app at once, no delay
        } else {
            showTimer.restart();
        }
    }

    function show() {
        let p = controller._pending;
        if (!p) return;
        controller.screen = p.scr;
        controller.targetX = p.x;
        controller.targetY = p.y;
        controller.dockPosition = p.pos || "bottom";
        controller.desktopId = p.id || "";
        controller.appName = p.name || "";
        controller.appIcon = p.icon || "";
        controller.groupKey = p.key || "";
        controller.windows = p.wins || [];
        controller.buttonSize = p.btn || 0;
        controller.revision++;
        controller.isVisible = true;
    }

    function scheduleHide() {
        showTimer.stop();
        controller._pending = null;
        if (controller.isVisible) hideTimer.restart();
    }

    function cancelHide() { hideTimer.stop(); }

    function hide() {
        showTimer.stop();
        hideTimer.stop();
        controller._pending = null;
        controller.isVisible = false;
        controller.windows = [];
    }

    Timer { id: showTimer; interval: 350; repeat: false; onTriggered: controller.show() }
    Timer { id: hideTimer; interval: 220; repeat: false; onTriggered: controller.hide() }

    // Keep the cards in step with the live window list (a window closed or restored from the preview, etc.).
    Connections {
        target: (typeof WindowTracker !== "undefined") ? WindowTracker : null
        function onUpdated() {
            if (!controller.isVisible || controller.groupKey === "") return;
            let g = WindowTracker.groups ? WindowTracker.groups[controller.groupKey] : null;
            let list = (g && g.windows) ? g.windows : [];
            if (list.length === 0) controller.hide();
            else controller.windows = list;
        }
    }

    // Scripting/testing hook:  quickshell ipc call dockpreview showapp <appId>
    IpcHandler {
        target: "dockpreview"

        function showapp(appId: string): void {
            let groups = (typeof WindowTracker !== "undefined" && WindowTracker.groups) ? WindowTracker.groups : {};
            for (let k in groups) {
                let g = groups[k];
                if (!g || !g.windows || g.windows.length === 0) continue;
                if (String(g.appId).toLowerCase() === appId.toLowerCase() || k === appId) {
                    let scr = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
                    let w = scr ? scr.width : 1920, h = scr ? scr.height : 1080;
                    controller._pending = { scr: scr, x: w / 2, y: h - 40, pos: "bottom", id: g.desktopId, name: g.appId, icon: "", key: k, wins: g.windows, btn: 48 };
                    controller.show();
                    return;
                }
            }
        }

        function hide(): void { controller.hide(); }

        // quickshell ipc call dockpreview list <appId>   -> JSON of that app's window instances
        function list(appId: string): string {
            let ws = (typeof WindowTracker !== "undefined" && WindowTracker.windows) ? WindowTracker.windows : [];
            let out = [];
            for (let i = 0; i < ws.length; i++) {
                let w = ws[i];
                if (String(w.appId).toLowerCase() !== appId.toLowerCase()) continue;
                out.push({ address: "0x" + w.nativeId, title: w.title, minimized: Boolean(w.minimized), workspace: w.workspaceLabel, focused: Boolean(w.focused) });
            }
            return JSON.stringify(out);
        }

        // quickshell ipc call dockpreview activate <address>   -> what a click on that window's card/dock icon does
        function activate(address: string): void {
            let ws = (typeof WindowTracker !== "undefined" && WindowTracker.windows) ? WindowTracker.windows : [];
            let want = address.replace(/^0x/, "");
            for (let i = 0; i < ws.length; i++) {
                if (String(ws[i].nativeId).replace(/^0x/, "") === want) { WindowTracker.focusWindow(ws[i]); return; }
            }
        }
    }
}
