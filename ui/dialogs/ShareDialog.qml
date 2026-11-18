import ".."
import QtQuick
import QtQuick.Controls
import "../theme/EffectSettings.js" as Effects
import "../theme/ServiceStatus.js" as Status

OverlayPanel {
 id:root;objectName:"file-share-dialog"
 property var settings:({})
 readonly property var style:Effects.fileSharingConfig(settings)
 property var shareState:({api:2,shares:[],readyCount:0})
 property var displayShares:[]
 property bool torRunning:false
 property bool submitting:false
 property bool routingReady:true
 property bool waiting:false
 signal chooseRequested()
 signal stopRequested(string id)
 signal retryRequested(string id)
 signal dismissRequested(string id)
 signal statusRequested()
 palette.window:surface;palette.base:surface;palette.text:ink;palette.buttonText:ink;palette.highlight:accent
 onOpened:{statusRequested();Qt.callLater(function(){addCard.forceActiveFocus()})}
 property string copiedId:""
 onClosed:{copyTimer.stop();copiedId=""}
 Timer {id:copyTimer;interval:1600;onTriggered:root.copiedId=""}
 TextEdit {id:clipboard;visible:false}
 function fileSize(bytes){if(!bytes)return "0 B";var units=["B","KB","MB","GB"];var i=Math.min(3,Math.floor(Math.log(bytes)/Math.log(1024)));return (bytes/Math.pow(1024,i)).toFixed(i?1:0)+" "+units[i]}
 onShareStateChanged:{
  var shares=shareState.shares||[]
  if(JSON.stringify(shares)!==JSON.stringify(displayShares)){var position=list.contentY;displayShares=shares;Qt.callLater(function(){list.contentY=Math.max(0,Math.min(position,list.contentHeight-list.height))})}
  var ids=shareState.selectedIds||[]
  if(ids.length)Qt.callLater(function(){var entries=root.shareState.shares||[];for(var i=0;i<entries.length;i++)if(entries[i].id===ids[0]){list.positionViewAtIndex(i,ListView.Contain);break}})
 }
 component ShareAction:OverlayIconButton {ink:root.ink;accent:root.accent}
 contentItem:OverlayBody {
  OverlayHeader {id:header;objectName:"share-header";title:"Share a file";centered:root.style.titleAlignment==="center";ink:root.ink;accent:root.accent;onClosed:root.close()}
  Text {width:parent.width;height:36;visible:!list.count;verticalAlignment:Text.AlignVCenter;objectName:"share-empty-status";text:root.waiting?"File selected · waiting for Tor…":root.submitting?"Preparing selected files…":"No files shared";color:root.ink;opacity:ThemeDesign.textOpacity(.45);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12)}
  ListView {
   id:list;objectName:"share-list";width:parent.width;visible:count>0
   height:Math.min(contentHeight,192,Math.max(64,(root.parent?root.parent.height:480)-310))
   clip:true;model:root.displayShares;boundsBehavior:Flickable.StopAtBounds
   ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
   delegate:Item {
    id:entry;required property var modelData;required property int index
    objectName:"share-row-"+modelData.id;width:list.width;height:64
    readonly property color statusColor:Status.color(root.surface,modelData.state)
    Accessible.role:Accessible.Grouping;Accessible.name:modelData.name||"File"
    Rectangle {width:parent.width;height:1;color:root.ink;opacity:ThemeDesign.textOpacity(.07);visible:entry.index>0}
    Rectangle {anchors.verticalCenter:parent.verticalCenter;width:7;height:7;radius:3.5;color:entry.statusColor}
    Column {
     x:14;anchors.verticalCenter:parent.verticalCenter;width:parent.width-14-actions.width-8;spacing:3
     Text {width:parent.width;text:entry.modelData.name||"File";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);elide:Text.ElideMiddle;textFormat:Text.PlainText}
     Text {objectName:"share-progress-"+entry.modelData.id;width:parent.width;text:entry.modelData.state==="ready"?"Sharing · "+root.fileSize(entry.modelData.size):entry.modelData.message||(entry.modelData.state==="error"?"Failed · retry":entry.modelData.state==="stopping"?"Stopping…":"Preparing…");textFormat:Text.PlainText;elide:Text.ElideRight;color:entry.statusColor;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10)}
     HoverHandler {id:rowHover;cursorShape:Qt.ArrowCursor}
     TorToolTip {visible:rowHover.hovered;text:entry.modelData.name||"File";detail:(entry.modelData.state!=="ready"?entry.modelData.message:entry.modelData.styleWarning)||"";ink:root.ink;accent:root.accent}
    }
    Row {
     id:actions;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:2
     ShareAction {objectName:"share-copy-"+entry.modelData.id;kind:root.copiedId===entry.modelData.id?"check":"copy";visible:entry.modelData.state!=="error";enabled:entry.modelData.state==="ready"&&!!entry.modelData.url;text:root.copiedId===entry.modelData.id?"Copied":"Copy link";Accessible.name:"Copy link";ToolTip.visible:hovered;ToolTip.text:root.copiedId===entry.modelData.id?"Copied":"Copy link";onClicked:{clipboard.text=entry.modelData.url;clipboard.selectAll();clipboard.copy();root.copiedId=entry.modelData.id;copyTimer.restart()}}
     ShareAction {objectName:"share-retry-"+entry.modelData.id;kind:"refresh";text:"Retry sharing";Accessible.name:"Retry";ToolTip.visible:hovered;ToolTip.text:"Retry";visible:entry.modelData.state==="error";enabled:root.torRunning&&root.routingReady;onClicked:root.retryRequested(entry.modelData.id)}
     ShareAction {objectName:"share-stop-"+entry.modelData.id;kind:entry.modelData.state==="error"?"remove":"stop";text:entry.modelData.state==="error"?"Remove failed share":"Stop sharing";ink:Status.color(root.surface,"error");enabled:entry.modelData.state!=="stopping"||entry.modelData.stopFailed===true;Accessible.name:entry.modelData.state==="error"?"Dismiss failed share":"Stop sharing "+entry.modelData.name;onClicked:entry.modelData.state==="error"?root.dismissRequested(entry.modelData.id):root.stopRequested(entry.modelData.id);ToolTip.visible:hovered;ToolTip.text:entry.modelData.state==="error"?"Dismiss":"Stop sharing"}
    }
   }
  }
  Column {
   objectName:"share-add-group";width:parent.width;spacing:6
   ActionCard {
    id:addCard;objectName:"share-choose";x:root.style.addAlignment==="center"?(parent.width-width)/2:0
    text:"Add file";kind:"share";ink:root.ink;accent:root.accent;enabled:root.torRunning&&root.routingReady
    onClicked:{root.close();root.chooseRequested()}
   }
  }
  OverlayFooter {objectName:"share-footer";horizontalAlignment:root.style.footerAlignment==="center"?Text.AlignHCenter:Text.AlignLeft;ink:root.ink;text:"Share files privately through a .onion link."}
  Text {objectName:"share-status";width:parent.width;wrapMode:Text.Wrap;textFormat:Text.PlainText;color:root.ink;opacity:ThemeDesign.textOpacity(.65);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);text:root.shareState.error||(root.submitting&&list.count?"Preparing selected files…":"")||(!root.torRunning?"Tor is off":!root.routingReady?"Waiting for a Tor circuit…":"");visible:!!text}
 }
}
