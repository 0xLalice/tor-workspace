import ".."
import QtQuick
import QtQuick.Controls

OverlayPanel {
 id:root;objectName:"update-dialog"
 property var update:({})
 property bool busy:false
 property string feedback:""
 signal updateRequested()
 signal checkRequested()
 height:Math.min(parent.height-24,body.implicitHeight+2*padding)
 x:(parent.width-width)/2;y:(parent.height-height)/2
 closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
 contentItem:ScrollView {
  id:scroll;clip:true;contentWidth:availableWidth;contentHeight:body.implicitHeight
  OverlayBody {
   id:body;width:scroll.availableWidth
   OverlayHeader {title:"Changelog";ink:root.ink;accent:root.accent;onClosed:root.close()}
   Repeater {
    objectName:"changelog-entries"
    model:root.update.releases||[]
    Column {
     id:release;required property var modelData;width:body.width;spacing:4
     Text {
      objectName:"release-"+release.modelData.kind
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:"v"+release.modelData.version+(release.modelData.kind==="available"?"  ·  Update available":"")
      color:release.modelData.kind==="available"?root.accent:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);font.weight:Font.DemiBold
     }
     Text {
      width:release.width;text:release.modelData.changes.join("\n");textFormat:Text.PlainText
      wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight
      color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);lineHeight:1.15
     }
    }
   }
   ActionCardRow {
    ActionCard {ink:root.ink;accent:root.accent;kind:"terminal"
     id:launch;objectName:"update-continue";enabled:root.update.canUpdate===true&&!root.busy
     visible:root.update.available===true;text:"Update";onClicked:root.updateRequested()
    }
    ActionCard {ink:root.ink;accent:root.accent;kind:"refresh"
     id:recheck;objectName:"update-recheck";enabled:!root.busy
     text:root.busy?"Checking…":"Check again";onClicked:root.checkRequested()
    }
   }
   OverlayFooter {ink:root.ink
    text:root.update.error||(root.update.available?"Your agent reviews and applies the update.":root.busy?"Checking for updates…":root.update.checked?"You're up to date.":root.update.managed===false?"Updates require a Git installation.":"Updates haven't been checked yet.")
   }
   Text {width:parent.width;visible:text!=="";text:root.feedback;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:root.ink;opacity:ThemeDesign.textOpacity(.65);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
  }
 }
}
