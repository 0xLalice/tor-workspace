import ".."
import QtQuick
import QtQuick.Controls
import "../theme/ServiceStatus.js" as Status
OverlayPanel {
 id:root;objectName:"chat-dialog"
 property var room:({state:"idle",url:""})
 property bool torRunning:false
 readonly property bool activeRoom:["starting","preparing","ready","stopping"].indexOf(room.state)>=0
 readonly property bool ready:room.state==="ready"&&!!room.url
 readonly property string phase:room.state||"idle"
 signal startRequested()
 signal stopRequested()
 signal openRequested()
 signal statusRequested()
 closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
 function focusAction(){
  if(!opened)return
  if(ready)openButton.forceActiveFocus()
  else if(activeRoom&&stopButton.enabled)stopButton.forceActiveFocus()
  else if(startButton.visible&&startButton.enabled)startButton.forceActiveFocus()
  else header.closeControl.forceActiveFocus()
 }
 onOpened:{statusRequested();Qt.callLater(focusAction)}
 onPhaseChanged:Qt.callLater(focusAction)
 onReadyChanged:Qt.callLater(focusAction)
 onTorRunningChanged:Qt.callLater(focusAction)
 onRoomChanged:{if(copiedUrl!==room.url){copied=false;copiedTimer.stop()}}
 property bool copied:false
 property string copiedUrl:""
 onClosed:{copiedTimer.stop();copied=false}
 Timer {id:copiedTimer;interval:1400;onTriggered:root.copied=false}
 TextEdit {id:clipboard;visible:false}
 readonly property bool countKnown:ready&&typeof room.participants==="number"
 readonly property color statusColor:Status.color(surface,phase)
 readonly property string statusText:root.room.error||(root.phase==="error"?root.room.message||"Unavailable":"")||(!root.torRunning?"Tor is off":root.phase==="starting"||root.phase==="preparing"?"Starting…":root.phase==="stopping"?"Stopping…":root.ready?(root.countKnown?root.room.participants+" connected":"Active"):"No room")
 contentItem:OverlayBody {
  OverlayHeader {id:header;title:"Chat";closeName:"chat-close";nextFocus:root.ready?openButton:root.activeRoom?stopButton:startButton;ink:root.ink;accent:root.accent;onClosed:root.close()}
  Item {
   objectName:"chat-room-row";width:parent.width;height:root.activeRoom?64:Math.max(36,statusLabel.implicitHeight)
   Rectangle {visible:root.activeRoom;width:7;height:7;radius:3.5;anchors.verticalCenter:parent.verticalCenter;color:root.statusColor}
   Column {
    x:root.activeRoom?14:0;anchors.verticalCenter:parent.verticalCenter;width:parent.width-x-(root.activeRoom?actions.width+8:0);spacing:3
    Text {visible:root.activeRoom;width:parent.width;text:"Chat room";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);elide:Text.ElideRight}
    Text {id:statusLabel;objectName:"chat-status";width:parent.width;text:root.statusText;textFormat:Text.PlainText;wrapMode:Text.WordWrap
     color:root.activeRoom||root.phase==="error"?root.statusColor:root.ink;opacity:root.activeRoom||root.phase==="error"?1:ThemeDesign.textOpacity(.45)
     font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(root.activeRoom?10:12)
    }
    HoverHandler {id:statusHover}
    TorToolTip {visible:statusHover.hovered;text:root.room.styleWarning||(root.ready&&!root.countKnown?"Connection count unavailable for this room":root.ready?"Connected browsers, including yours":"");ink:root.ink;accent:root.accent}
   }
   Row {
    id:actions;visible:root.activeRoom;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:2
    OverlayIconButton {id:copyButton;objectName:"chat-copy";KeyNavigation.tab:stopButton;KeyNavigation.backtab:openButton;kind:root.copied?"check":"copy";text:root.copied?"Copied":"Copy link";ink:root.ink;accent:root.accent;enabled:root.ready;onClicked:{clipboard.text=root.room.url;clipboard.selectAll();clipboard.copy();root.copiedUrl=root.room.url;root.copied=true;copiedTimer.restart()}}
    OverlayIconButton {id:stopButton;objectName:"chat-stop";KeyNavigation.tab:header.closeControl;KeyNavigation.backtab:copyButton;kind:"stop";text:"Stop room";ink:Status.color(root.surface,"error");accent:ink;enabled:root.phase!=="stopping"||!!root.room.error;onClicked:root.stopRequested()}
   }
  }
  Item {
   width:parent.width;height:root.activeRoom?openButton.implicitHeight:startButton.implicitHeight
   ActionCard {id:startButton;objectName:"chat-start";anchors.horizontalCenter:parent.horizontalCenter;kind:root.phase==="error"?"refresh":"chat";text:root.phase==="error"?"Retry":"Create room";visible:!root.activeRoom;enabled:root.torRunning;ink:root.ink;accent:root.accent;onClicked:root.startRequested()}
   ActionCard {id:openButton;objectName:"chat-open";KeyNavigation.tab:copyButton;KeyNavigation.backtab:header.closeControl;anchors.horizontalCenter:parent.horizontalCenter;kind:"open";text:"Open chat";visible:root.activeRoom;enabled:root.ready;ink:root.ink;accent:root.accent;onClicked:root.openRequested()}
  }
 }
}
