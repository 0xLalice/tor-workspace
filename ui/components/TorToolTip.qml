import ".."
import QtQuick
import QtQuick.Controls

ToolTip {
 id:tip
 property string detail:""
 property color ink:ThemeColors.color("foreground")
 property color accent:ThemeColors.color("accent")
 property bool below:false
 property real cornerRadius:ThemeDesign.radius(2)
 delay:450
 timeout:0
 padding:10
 margins:8
 x:(parent.width-width)/2
 y:below?parent.height+8:-height-8
 background:Rectangle {
  color:ThemeColors.color("tooltipSurface");radius:tip.cornerRadius
  border.width:1;border.color:Qt.rgba(tip.accent.r,tip.accent.g,tip.accent.b,0.55)
 }
 contentItem:Item {
  implicitWidth:tip.detail?200:title.implicitWidth
  implicitHeight:copy.height
  Column {
   id:copy;width:parent.width;spacing:5
  Text {
   id:title;width:parent.width;text:tip.text;textFormat:Text.PlainText
   color:tip.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)
   wrapMode:Text.WordWrap
  }
  Text {
   width:parent.width;visible:tip.detail!=="";text:tip.detail;textFormat:Text.PlainText
   color:tip.ink;opacity:0.65;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10)
   wrapMode:Text.WordWrap;lineHeight:1.2
  }
 }
 }
 enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:100}}
 exit:Transition {NumberAnimation {property:"opacity";from:1;to:0;duration:80}}
}
