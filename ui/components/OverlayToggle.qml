import ".."
import QtQuick
import QtQuick.Controls
CheckBox {
 id:root
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 spacing:10;padding:4;hoverEnabled:true
 indicator:Rectangle {
  x:root.leftPadding;y:(root.height-height)/2;width:26;height:14;radius:ThemeDesign.radius(7)
  color:Qt.alpha(root.accent,root.checked?.25:.06);border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(root.activeFocus?.8:.3))
  Rectangle {x:root.checked?14:3;y:3;width:8;height:8;radius:ThemeDesign.radius(4);color:root.checked?root.accent:root.ink;opacity:root.enabled?1:.4}
 }
 contentItem:Text {text:root.text;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);leftPadding:root.indicator.width+root.spacing;verticalAlignment:Text.AlignVCenter;opacity:root.enabled?1:.4}
 HoverHandler {cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
}
