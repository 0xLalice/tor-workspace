import ".."
import QtQuick
import QtQuick.Controls
Button {
 id:root
 property string kind:"close"
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 width:40;height:40;implicitWidth:40;implicitHeight:40;padding:9;hoverEnabled:true
 Accessible.name:text
 contentItem:ActionGlyph {kind:root.kind;ink:root.ink;accent:root.ink;preserveColor:root.kind==="stop"||root.kind==="remove";opacity:root.enabled?1:.35}
 background:Rectangle {radius:ThemeDesign.radius(6);color:Qt.alpha(root.ink,root.down?.16:root.hovered?.09:.025);border.width:root.activeFocus?1:0;border.color:root.accent}
 ToolTip.visible:hovered;ToolTip.text:text
 HoverHandler {cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
}
