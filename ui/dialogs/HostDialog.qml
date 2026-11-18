import ".."
import QtQuick
import QtQuick.Controls
import "../theme/ServiceStatus.js" as Status
OverlayPanel {
 id:root;objectName:"host-dialog"
 property var host:({state:"stopped",source:{mode:"folder",folder:"",port:3000},url:""})
 property bool torRunning:false
 property bool routingReady:true
 property string mode:"folder"
 property string folder:""
 property string pendingFolder:""
 property bool copied:false
 property bool editing:false
 readonly property bool activeHost:["starting","ready","stopping"].indexOf(host.state)>=0
 readonly property bool ready:host.state==="ready"
 signal startRequested(var source)
 signal stopRequested()
 signal openRequested()
 signal statusRequested()
 signal chooseRequested()
 closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
 function loadSource(){var s=root.host.source||{};if((s.mode||"folder")!==mode)return;folder=s.folder||"";port.text=String(s.port||3000)}
 function applySelectedFolder(){if(pendingFolder){mode="folder";folder=pendingFolder;pendingFolder="";editing=true}}
 function selectFolder(path){pendingFolder=path||"";if(opened)applySelectedFolder();else open()}
 function focusAction(){
  if(!opened)return
  if(ready)openButton.forceActiveFocus()
  else if(activeHost)stopButton.forceActiveFocus()
  else if(mode==="app"){port.forceActiveFocus();port.selectAll()}
  else choose.forceActiveFocus()
 }
 onOpened:{editing=false;loadSource();applySelectedFolder();statusRequested();Qt.callLater(focusAction)}
 onActiveHostChanged:Qt.callLater(focusAction)
 onReadyChanged:Qt.callLater(focusAction)
 onHostChanged:{copied=false;if(activeHost||!editing)loadSource()}
 onClosed:{copyTimer.stop();copied=false}
 Timer {id:copyTimer;interval:1400;onTriggered:root.copied=false}
 TextEdit {id:clipboard;visible:false}
 component Card:ActionCard {ink:root.ink;accent:root.accent}
 component Note:Text {width:parent.width;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);wrapMode:Text.Wrap;textFormat:Text.PlainText}
 readonly property string sourceName:mode==="app"?"localhost:"+((host.source||{}).port||3000):(folder.split("/").filter(Boolean).pop()||"Website")
 readonly property string statusText:root.host.error||(root.host.state==="error"?root.host.message||"Unavailable":"")||(!root.torRunning?"Tor is off":!root.routingReady?"Waiting for a Tor circuit…":root.ready?"Published":root.host.state==="starting"?"Publishing…":root.host.state==="stopping"?"Stopping…":"")
 readonly property color statusColor:Status.color(surface,host.error?"error":host.state)
 contentItem:OverlayBody {
  OverlayHeader {id:header;title:root.mode==="folder"?"Website folder":"Running app";closeName:"host-close";ink:root.ink;accent:root.accent;onClosed:root.close()}
  Column {
   width:parent.width;spacing:8;visible:!root.activeHost&&root.mode==="folder"
   Button {
    id:choose;objectName:"host-choose";width:parent.width;height:44;padding:10;hoverEnabled:true
    Accessible.name:root.folder?"Change website folder":"Choose website folder"
    onClicked:root.chooseRequested()
    background:Rectangle {radius:ThemeDesign.radius(4);color:Qt.alpha(root.ink,.04);border.color:Qt.alpha(root.accent,choose.activeFocus||choose.hovered?.65:.24)}
    contentItem:Row {
     spacing:10
     ActionGlyph {width:22;height:22;kind:"website";ink:root.ink;accent:root.accent}
     Text {width:parent.width-32;height:22;verticalAlignment:Text.AlignVCenter;text:root.folder?root.folder.split("/").filter(Boolean).pop():"Choose folder";elide:Text.ElideMiddle;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);textFormat:Text.PlainText}
    }
    TorToolTip {visible:choose.hovered&&!!root.folder;text:root.folder;ink:root.ink;accent:root.accent}
   }
   Note {text:"Serves a folder containing index.html.";opacity:ThemeDesign.textOpacity(.55)}
  }
  Column {
   width:parent.width;spacing:8;visible:!root.activeHost&&root.mode==="app"
   Row {
    anchors.horizontalCenter:parent.horizontalCenter;spacing:8;height:40
    Text {height:parent.height;verticalAlignment:Text.AlignVCenter;text:"localhost:";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12)}
    TextField {id:port;objectName:"host-port";width:84;height:40;enabled:!root.activeHost;text:"3000";placeholderText:"3000";color:root.ink;selectByMouse:true;Accessible.name:"Local app port";horizontalAlignment:TextInput.AlignHCenter
     onTextEdited:root.editing=true
     validator:IntValidator {bottom:1;top:65535}
     background:Rectangle {radius:ThemeDesign.radius(4);color:Qt.alpha(root.ink,.04);border.color:Qt.alpha(root.accent,port.activeFocus?.65:.24)}
    }
   }
   Note {text:"Start your app before publishing.";horizontalAlignment:Text.AlignHCenter;opacity:ThemeDesign.textOpacity(.55)}
  }
  Item {
   visible:root.activeHost;objectName:"host-source-row";width:parent.width;height:64
   Rectangle {width:7;height:7;radius:3.5;anchors.verticalCenter:parent.verticalCenter;color:root.statusColor}
   Column {
    x:14;width:parent.width-x-actions.width-8;anchors.verticalCenter:parent.verticalCenter;spacing:3
    Text {width:parent.width;text:root.sourceName;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);elide:Text.ElideMiddle;textFormat:Text.PlainText}
    Text {width:parent.width;text:root.statusText;color:root.statusColor;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);wrapMode:Text.WordWrap;textFormat:Text.PlainText}
   }
   Row {
    id:actions;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:2
    OverlayIconButton {objectName:"host-copy";kind:root.copied?"check":"copy";text:root.copied?"Copied":"Copy link";ink:root.ink;accent:root.accent;enabled:root.ready&&!!root.host.url;onClicked:{clipboard.text=root.host.url;clipboard.selectAll();clipboard.copy();root.copied=true;copyTimer.restart()}}
    OverlayIconButton {id:stopButton;objectName:"host-stop";kind:"stop";text:"Stop publishing";ink:Status.color(root.surface,"error");accent:ink;enabled:root.host.state!=="stopping"||!!root.host.error;onClicked:root.stopRequested()}
   }
  }
  Note {objectName:"host-status";visible:!root.activeHost&&!!text;text:root.statusText;color:root.host.error||root.host.state==="error"?Status.color(root.surface,"error"):root.ink}
  ActionCardRow {
   Card {id:startButton;kind:root.mode==="folder"?"website":"app";objectName:"host-start";text:root.host.state==="error"?"Retry":"Publish";visible:!root.activeHost;enabled:root.torRunning&&root.routingReady&&(root.mode==="folder"?!!root.folder:port.acceptableInput)
    onClicked:root.startRequested({mode:root.mode,folder:root.folder,port:Number(port.text)})}
   Card {id:openButton;objectName:"host-open";kind:"open";text:"Open site";visible:root.activeHost;enabled:root.ready&&root.routingReady;onClicked:root.openRequested()}
  }
 }
}
