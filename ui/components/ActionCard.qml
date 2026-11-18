import ".."
import QtQuick
import QtQuick.Controls

Button {
 id:root
 property string kind:""
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 implicitWidth:64;implicitHeight:contentItem.implicitHeight;padding:0;hoverEnabled:true
 Accessible.name:text
 background:Item {}
 contentItem:Column {
  spacing:6;opacity:root.enabled?1:.4
  Rectangle {
   objectName:"action-card-surface";anchors.horizontalCenter:parent.horizontalCenter;width:40;height:40;radius:ThemeDesign.radius(4)
   color:Qt.alpha(root.accent,root.hovered?.12:.055);border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(root.activeFocus?.65:.32))
   ActionGlyph {anchors.centerIn:parent;width:24;height:24;kind:root.kind;ink:root.ink;accent:root.accent;glow:root.enabled&&(root.hovered||root.activeFocus)?1:0}
  }
  Text {width:parent.width;text:root.text;color:root.ink;opacity:ThemeDesign.textOpacity(.75);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;textFormat:Text.PlainText}
 }
 HoverHandler {cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
}
