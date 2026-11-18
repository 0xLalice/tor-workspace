import ".."
import QtQuick
import QtQuick.Controls

Popup {
 id:root
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property color surface:ThemeColors.color("background")
 property bool reducedMotion:false
 font.family:ThemeDesign.fontFamily
 font.pixelSize:ThemeDesign.px(12)
 width:Math.min(344,parent.width-24)
 x:(parent.width-width)/2;y:Math.max(8,(parent.height-height)/2)
 padding:ThemeDesign.padding;modal:true;dim:true;focus:true
 closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
 background:Rectangle {color:root.surface;radius:ThemeDesign.radius(8);border.width:ThemeColors.treatment.overlayOutline?1:ThemeDesign.definition.outline;border.color:ThemeColors.treatmentColor("overlayBorder")||Qt.alpha(root.accent,ThemeDesign.borderAlpha(.24))}
 Overlay.modal:Rectangle {color:ThemeColors.color("modalScrim")}
 enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:root.reducedMotion?0:180}}
 exit:Transition {NumberAnimation {property:"opacity";to:0;duration:root.reducedMotion?0:180}}
}
