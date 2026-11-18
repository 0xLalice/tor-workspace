import ".."
import QtQuick

// Native plugins must resolve against the filesystem, not Quickshell's qs: URLs.
// Keep palette bindings in the host context so there is only one theme singleton.
Loader {
 id:root
 source: Qt.resolvedUrl("CircuitPainter.qml").toString().replace(/^qs:/, "file:")
 Binding {target:root.item;property:"contrastGain";value:ThemeColors.visualTreatment.circuitInkGain;when:root.item!==null}
 Binding {target:root.item;property:"strokeScale";value:ThemeColors.visualTreatment.circuitStrokeScale;when:root.item!==null}
 Binding {target:root.item;property:"strokeUnderlay";value:ThemeColors.visualTreatment.circuitUnderlay;when:root.item!==null}
}
