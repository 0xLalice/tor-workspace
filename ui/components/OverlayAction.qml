import ".."
import QtQuick
import QtQuick.Controls

Button {
 id:root
 property int textAlignment:Text.AlignLeft
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 hoverEnabled:true;padding:6;leftPadding:0;rightPadding:0
 contentItem:Text {text:root.text;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);opacity:root.enabled?ThemeDesign.textOpacity(root.hovered?1:.8):.4;horizontalAlignment:root.textAlignment;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
 background:Item {
  Rectangle {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:parent.width;height:1;color:root.accent;visible:root.activeFocus||root.checked;opacity:ThemeDesign.textOpacity(.6)}
 }

 HoverHandler {cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
}
