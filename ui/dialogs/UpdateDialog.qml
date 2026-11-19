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
   Column {
    width:parent.width
    spacing:2
    Repeater {
     objectName:"changelog-entries"
     model:root.update.releases||[]
     Item {
      id:release
      required property var modelData
      readonly property bool pending:modelData.kind==="available"
      readonly property bool installed:modelData.kind==="installed"
      readonly property string status:pending?"Update available":installed?"Installed":""
      readonly property string summary:(modelData.changes||[]).join(" ")
      width:parent.width
      implicitHeight:Math.max(version.implicitHeight,note.implicitHeight)+4
      Accessible.role:Accessible.StaticText
      Accessible.name:["v"+modelData.version,status,summary].filter(Boolean).join(". ")
      Text {
       id:version;objectName:"release-version"
       anchors.verticalCenter:parent.verticalCenter
       text:"v"+release.modelData.version+(release.pending?" ↑":release.installed?" ✓":"")
       width:Math.min(Math.max(implicitWidth,ThemeDesign.px(62)),release.width*0.4)
       textFormat:Text.PlainText;elide:Text.ElideRight
       color:release.pending?root.accent:root.ink
       font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);font.weight:Font.DemiBold
      }
      Text {
       id:note;objectName:"release-summary"
       anchors.left:version.right;anchors.leftMargin:6;anchors.right:parent.right
       anchors.verticalCenter:parent.verticalCenter
       text:release.summary;textFormat:Text.PlainText;elide:Text.ElideRight
       color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12)
      }
      HoverHandler {id:hover}
      TorToolTip {
       visible:hover.hovered&&(release.status!==""||note.truncated||version.truncated)
       text:"v"+release.modelData.version+(release.status?" · "+release.status:"")
       detail:note.truncated?release.summary:""
      }
     }
    }
   }
   Row {
    anchors.horizontalCenter:parent.horizontalCenter
    spacing:16
    OverlayAction {
     objectName:"update-continue";visible:root.update.available===true
     enabled:root.update.canUpdate===true&&!root.busy;text:"Update"
     onClicked:root.updateRequested()
    }
    OverlayAction {
     objectName:"update-recheck";enabled:!root.busy;text:root.busy?"Checking…":"Check again"
     onClicked:root.checkRequested()
    }
   }
   OverlayFooter {ink:root.ink;visible:text!==""
    text:root.update.error||(root.update.available||root.busy?"":root.update.checked?"You're up to date.":root.update.managed===false?"Updates require a Git installation.":"Updates haven't been checked yet.")
   }
   Text {width:parent.width;visible:text!=="";text:root.feedback;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:root.ink;opacity:ThemeDesign.textOpacity(.65);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
  }
 }
}
