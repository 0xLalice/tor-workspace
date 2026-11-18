import ".."
import QtQuick
import QtQuick.Controls
OverlayPanel {
 id:root;objectName:"published-theme-chooser"
 property var themes:[]
 property string currentId:""
 signal chosen(string id)
 height:Math.min(parent.height-24,body.implicitHeight+2*padding)
 contentItem:ScrollView {
  clip:true;contentWidth:availableWidth
  OverlayBody {
   id:body;width:parent.width
   OverlayHeader {id:header;title:"Themes";closeName:"";ink:root.ink;accent:root.accent;onClosed:root.close()}
   Column {width:parent.width;spacing:0
   Repeater {
    model:root.themes
    OverlayAction {
     id:theme;required property var modelData;width:body.width;height:36
     text:modelData.name;ink:root.ink;accent:root.accent
     onClicked:{root.chosen(modelData.id);root.close()}
     contentItem:Item {
      Rectangle {anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;width:4;height:4;radius:ThemeDesign.radius(2);color:root.accent;visible:theme.modelData.id===root.currentId}
      Text {x:14;anchors.verticalCenter:parent.verticalCenter;width:parent.width-14;text:theme.text;color:root.ink;opacity:ThemeDesign.textOpacity(theme.hovered?1:.8);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);elide:Text.ElideRight}
     }
     background:Rectangle {color:Qt.alpha(root.accent,theme.hovered?.07:0);radius:ThemeDesign.radius(4);border.width:theme.activeFocus?1:0;border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.4))}
    }
   }
   }
  }
 }
}
