import QtQuick
import Quickshell.Io

// One serialized JSON request stream. Read/Stop remain usable during repair.
Item {
    id: root
    visible: false
    required property string script
    property string executable: "python3"
    property bool executableAvailable: true
    property bool startAllowed: false
    property var startActions: ["start"]
    property string failureMessage: "Service unavailable."
    property var queue: []
    property string action: "status"
    property var payload: ({})
    property bool busy: false
    readonly property bool starting: (busy && action === "start") || queue.some(item => item.action === "start")
    signal received(var value)
    signal failed(string message)

    function send(action, payload) {
        // Polls are expendable; user commands keep their order.
        if (action === "status" && (busy || queue.length)) return
        queue = queue.concat([{action: action, payload: payload || {}}])
        drain()
    }

    function reject(message) {
        failed(message)
        Qt.callLater(drain)
    }

    function drain() {
        if (busy || !queue.length) return
        var next = queue[0]
        queue = queue.slice(1)
        if (!executableAvailable) {
            reject("Python is unavailable. Restore Python to run service commands.")
            return
        }
        if (startActions.includes(next.action) && !startAllowed) {
            reject("Tor is not available. Start Tor and retry.")
            return
        }
        action = next.action
        payload = next.payload
        busy = true
        worker.command = [executable, "-B", script, action]
        worker.running = true
    }

    function finish(code) {
        if (!busy) return
        busy = false
        try {
            var value = JSON.parse(response.text)
            if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid response")
            if (code !== 0 && !value.error) value.error = failureMessage
            received(value)
        } catch (e) {
            failed(failureMessage)
        }
        Qt.callLater(drain)
    }

    Process {
        id: worker
        stdinEnabled: true
        onStarted: write(JSON.stringify(root.payload) + "\n")
        stdout: StdioCollector {id: response; waitForEnd: true}
        onExited: code => root.finish(code)
        // Failed exec may emit runningChanged without exited in Quickshell.
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (root.busy && !worker.running) root.finish(-1)
        })
    }
}
