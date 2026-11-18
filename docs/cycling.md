# Cycling presentation (v0.1)

Review numbers remain stable: 1–6 and 9–15. The two products own their UI and
native sources independently; exported theme JSON is unchanged.

The action glyph opacity breathes over 2.4 seconds. Hidden, disabled and covered
actions stop animating, and reduced motion uses a steady accent. Built circuits
have a ten-second visible presentation budget. Hovering over the globe or opening
an overlay suspends the budget. Directory updates do not reset it. Expiry
restores the normal globe and cycling; Escape closes immediately. Workspace
exit and Tor shutdown cancel the presentation without requesting circuits.

Explanations use the shared 344-pixel panel with scrolling at small sizes. File
transfer owns a flat diagram and does not change the globe camera. Rendezvous
builds the connection, then sends packets in both directions until closed.
Encryption loops through request and response phases with separate K1, K2 and
K3 keys and an HTTPS lock. The protocol reference is
[the Tor introduction](https://spec.torproject.org/intro/).

Speed test renders only `measurement.tor.paths`, supplied by the existing
stream observer alongside `circuitIds`. Each path includes client and server
countries for its geographic return estimate. The compact route line displays
the intervening relay countries. An attributed Conflux pair uses a compact
diagonal diagram with short arrows: one client forks into both paths, which
rejoin at a single exit. The client is labeled with its attributed country.
Numbered circuit totals sit in aligned rows below the diagram, in route order.
Each total includes the client, all relays and the destination, then the return. Other circuits retain their route lines. Only a Tor-reported Conflux group adds a brief
explanation that the paths share one exit to improve speed. Missing attribution
or locations are hidden; the representative globe route is never a fallback.
No probes or backend measurement fields were added.

## Checks

`tests/qml/tst_cycling_cleanup.qml` covers animation lifetime, the circuit timer,
hover pause, expiry, Escape, workspace exit, Tor shutdown, multi-circuit speed
results, missing data and cancellation. `tst_cycling_retained.qml` covers the
remaining notes and geographic presentation. Both render normal and narrow
layouts with light/dark colors and motion enabled/disabled. Native builds and
the full backend/UI suites remain required before installation.
