import QtQuick
import Quickshell.Io

Item {
    id:root
    visible:false
    required property string pluginPath
    property string purpose:"installation"
    property bool busy:false
    signal failed(string purpose)
    signal departing()

    function launch(command, purpose) {
        if (busy) return
        root.purpose = purpose || "installation"
        busy = true
        departing()
        // A user service owns the terminal across plugin reloads and updates.
        launcher.command = ["systemd-run", "--user", "--wait", "--collect", "--quiet",
            "--property=Type=exec", "--working-directory=" + pluginPath,
            "bash", pluginPath + "install/launch-action.sh", "--failure-target",
            root.purpose === "update" ? "updateFailed" : "installationFailed"].concat(command)
        Qt.callLater(function() { launcher.running = true })
    }

    function finish(code) {
        if (!busy) return
        busy = false
        if (code !== 0) failed(purpose)
    }

    Process {
        id:launcher
        workingDirectory:root.pluginPath
        onExited:code=>root.finish(code)
        onRunningChanged:if(!running)Qt.callLater(function(){
            if(root.busy&&!launcher.running)root.finish(-1)
        })
    }
}
