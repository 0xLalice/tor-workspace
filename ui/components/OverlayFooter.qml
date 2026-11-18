import ".."
import QtQuick
Text {
 property color ink:ThemeColors.color("uiText")
 horizontalAlignment:Text.AlignHCenter
 width:parent.width;color:ink;opacity:ThemeDesign.textOpacity(.55);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)
 textFormat:Text.PlainText;wrapMode:Text.WordWrap;lineHeight:1.15
}
