import ".."
import QtQuick
import QtQuick.Controls

OverlayPanel {
 id:root;objectName:"darknet-dialog"
 property bool torRunning:false
 signal launchRequested()
 onOpened:Qt.callLater(function(){if(launch.enabled)launch.forceActiveFocus();else header.closeControl.forceActiveFocus()})
 contentItem:OverlayBody {
  OverlayHeader {id:header;title:"Darknet";closeName:"darknet-close";ink:root.ink;accent:root.accent;onClosed:root.close()}
  OverlayFooter {ink:root.ink;horizontalAlignment:Text.AlignLeft;opacity:ThemeDesign.textOpacity(.8);text:"⚠️ You’re entering the darknet.\nBe cautious with links and downloads."}
  OverlayFooter {ink:root.ink;horizontalAlignment:Text.AlignLeft;text:"Ahmia (juhanur...4csyd.onion) is an open-source search engine founded by security researcher Juha Nurmi."}
  Text {objectName:"darknet-launch-status";visible:!root.torRunning;width:parent.width;text:"Start Tor to continue.";color:root.ink;opacity:ThemeDesign.textOpacity(.6);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
  ActionCardRow {
   ActionCard {id:launch;objectName:"darknet-open";text:"Open Ahmia";kind:"darknet";ink:root.ink;accent:root.accent;enabled:root.torRunning
    onClicked:{root.launchRequested();root.close()}
   }
  }
 }
}
