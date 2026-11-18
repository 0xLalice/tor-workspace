import ".."
import QtQuick
import QtQuick.Controls

Rectangle {
 id:root;objectName:"relay-card"
 property int variant:0
 property var hop:({})
 property var info:({})
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property color surface:ThemeColors.color("background")
 property bool expanded:false
 readonly property var local:info.local||({})
 readonly property var remote:info.remote||({})
 signal closed()
 function field(key){return local[key]!==undefined?local[key]:remote[key]}
 function value(v){return v===undefined||v===null||v===""?"Unavailable":String(v)}
 function bandwidth(v){return typeof v!=="number"?"Unavailable":v>=1000000?(v/1000000).toFixed(1)+" MB/s":(v/1000).toFixed(1)+" kB/s"}
 component InfoButton:Button {
  id:button;flat:true;padding:4
  contentItem:Text {text:button.text;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter}
  background:Rectangle {radius:ThemeDesign.radius(4);color:button.hovered?Qt.alpha(root.accent,.1):"transparent";border.width:button.activeFocus?1:0;border.color:root.accent}
 }
 color:ThemeDesign.definition.opaqueRelay?surface:variant===1?Qt.alpha(surface,.8):variant===2?Qt.alpha(surface,.9):surface
 border.color:Qt.alpha(accent,ThemeDesign.borderAlpha(.35));border.width:variant===1||variant===3?0:1;radius:ThemeDesign.radius(variant===2?12:variant===0?10:0)
 Rectangle {height:1;width:parent.width;color:root.accent;opacity:.6;visible:root.variant===1}
 Rectangle {width:2;height:parent.height;color:root.accent;opacity:.6;visible:root.variant===3}
 height:Math.min(implicitHeight,parent?parent.height*.58:340)
 implicitHeight:content.implicitHeight+28
 focus:true
 Keys.onEscapePressed:root.closed()
 MouseArea {anchors.fill:parent;onWheel:wheel=>wheel.accepted=true}
 Flickable {
  anchors.fill:parent;anchors.margins:14;contentHeight:content.implicitHeight;clip:true
  boundsBehavior:Flickable.StopAtBounds
  ScrollBar.vertical:ScrollBar {}
  Column {
   id:content;width:parent.width;spacing:8
   Row {
    width:parent.width
    Text {width:parent.width-30;text:root.value(root.field("nickname")||root.hop.name);textFormat:Text.PlainText;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(15);elide:Text.ElideRight}
    InfoButton {objectName:"relay-close";width:30;height:25;text:"×";flat:true;onClicked:root.closed();Accessible.name:"Close relay information"}
   }
   Text {width:parent.width;wrapMode:Text.Wrap;text:root.value(root.hop.role)+" · "+root.value(root.hop.countryName||root.remote.country_name||root.hop.country)+" (approximate)";color:root.accent;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
   Text {
    width:parent.width;wrapMode:Text.Wrap;textFormat:Text.PlainText;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);opacity:ThemeDesign.textOpacity(.75)
    text:(root.field("running")===undefined?"Status unavailable":root.field("running")?"Reported running":"Reported not running")+" · "+(root.local.running!==undefined&&root.local.observedAt?"local · "+new Date(root.local.observedAt*1000).toISOString().replace("T"," ").slice(0,19)+" UTC":root.value(root.remote.publishedAt)+" UTC")
   }
   Text {text:"Advertised bandwidth   "+root.bandwidth(root.field("advertised_bandwidth"));color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
   Text {text:"First seen   "+root.value(root.remote.first_seen)+(root.remote.first_seen?" UTC":"");color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
   Text {visible:!!(root.info.loading||root.info.cached||root.info.unavailable);text:root.info.loading?"Loading details…":root.info.unavailable?"Additional data unavailable":root.info.cached?"Onionoo · "+root.value(root.remote.publishedAt)+" UTC · cached":"";color:root.ink;opacity:ThemeDesign.textOpacity(.5);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10)}
   InfoButton {objectName:"relay-details";text:(root.expanded?"▾":"▸")+" Technical details";flat:true;onClicked:root.expanded=!root.expanded;padding:0;height:26}
   Column {
    visible:root.expanded;width:parent.width;spacing:8
    Row {
     width:parent.width
     TextEdit {id:fingerprint;objectName:"relay-fingerprint";width:parent.width-38;readOnly:true;selectByMouse:true;wrapMode:TextEdit.WrapAnywhere;text:root.hop.fingerprint||"";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
     InfoButton {text:"⧉";width:38;height:28;flat:true;Accessible.name:"Copy fingerprint";onClicked:{fingerprint.selectAll();fingerprint.copy();fingerprint.deselect()}}
    }
    TextEdit {width:parent.width;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;textFormat:TextEdit.PlainText;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)
     text:"Relay addresses   "+root.value((root.field("or_addresses")||[]).join(", "))+"\nNetwork / AS   "+root.value([root.remote.as,root.remote.as_name].filter(Boolean).join(" · "))+"\nTor   "+root.value(root.field("version"))+"\nFlags   "+root.value((root.field("flags")||[]).join(" · "))
    }
   }
  }
 }
}
