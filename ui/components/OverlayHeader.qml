import ".."
import QtQuick

Item {
 id:root
 property string title:""
 property string titleName:""
 property Item nextFocus:null
 property Item previousFocus:null
 property bool centered:true
 property string closeName:""
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property alias closeControl:close
 signal closed()
 width:parent.width;height:40
 Text {objectName:root.titleName;x:root.centered?44:0;horizontalAlignment:root.centered?Text.AlignHCenter:Text.AlignLeft;anchors.verticalCenter:parent.verticalCenter;width:parent.width-(root.centered?88:44);text:root.title;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(14);font.weight:Font.Medium;elide:Text.ElideRight}
 OverlayIconButton {id:close;KeyNavigation.tab:root.nextFocus;KeyNavigation.backtab:root.previousFocus;objectName:root.closeName;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;kind:"close";text:"Close overlay";ink:root.ink;accent:root.accent;onClicked:root.closed()}
}
