.pragma library

// Availability is independent of the representative drawing and spare circuits.
// Exit-routed operations still check a real route at their launch boundary.
function available(c, checkedAt, now) {
    return checkedAt > 0 && now >= checkedAt && now - checkedAt < 10
        && c.heartbeat > 0 && now >= c.heartbeat && now - c.heartbeat < 10
        && c.running === true && c.serviceReady === true
        && (c.state === "ready" || c.state === "starting")
        && c.exitCountry === c.appliedCountry
}
