pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    function checkBatteryTier() {
        batteryTierProcess.running = false;
        batteryTierProcess.running = true;
    }

    function checkAcState() {
        acStateProcess.running = false;
        acStateProcess.running = true;
    }

    function checkGpuDock() {
        // Never kill an in-flight invocation: once it's past its debounce
        // and into its notify+restart sequence, it must be left to finish
        // (see gpu_dock_watch.sh) rather than being restarted mid-sleep.
        if (!gpuDockProcess.running) {
            gpuDockProcess.running = true;
        }
    }

    Process {
        id: batteryTierProcess
        running: false
        command: ["bash", Caching.qsDir + "/watchers/battery_tier_watch.sh"]
    }

    Process {
        id: acStateProcess
        running: false
        command: ["bash", Caching.qsDir + "/watchers/ac_state_watch.sh"]
    }

    Process {
        id: gpuDockProcess
        running: false
        command: ["bash", Caching.qsDir + "/watchers/gpu_dock_watch.sh"]
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.checkBatteryTier()
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.checkAcState()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.checkGpuDock()
    }

    Component.onCompleted: {
        root.checkAcState();
        root.checkBatteryTier();
        root.checkGpuDock();
    }
}
