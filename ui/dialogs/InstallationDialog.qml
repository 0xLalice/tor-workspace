import ".."
import QtQuick
import QtQuick.Controls

OverlayPanel {
 id:root;objectName:"installation-dialog"
 property bool busy:false
 property string feedback:""
 property bool agentAvailable:true
 signal installRequested()
 signal configureRequested()
 signal manualRequested()
 height:Math.min(parent.height-24,body.implicitHeight+2*padding)
 x:(parent.width-width)/2;y:(parent.height-height)/2
 closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
 onOpened:Qt.callLater(function(){launch.forceActiveFocus()})
 contentItem:OverlayBody {
  id:body
  OverlayHeader {title:"Installation";ink:root.ink;accent:root.accent;onClosed:root.close()}
  ActionCardRow {
   ActionCard {ink:root.ink;accent:root.accent;kind:"terminal"
    id:launch;objectName:"installation-install";text:root.agentAvailable?"Install":"Configure agent";enabled:!root.busy
    onClicked:{root.close();if(root.agentAvailable)root.installRequested();else root.configureRequested()}
   }
   ActionCard {ink:root.ink;accent:root.accent;kind:"terminal"
    objectName:"installation-manual";text:"Manual instructions";enabled:!root.busy
    onClicked:{root.close();root.manualRequested()}
   }
  }
  Text {width:parent.width;visible:text!=="";text:root.feedback;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:root.ink;opacity:ThemeDesign.textOpacity(.65);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
 }
}
