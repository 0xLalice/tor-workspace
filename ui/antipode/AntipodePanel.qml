import ".."
import QtQuick
import QtQuick.Controls
Item {
 id:root;objectName:"antipode-panel"
 required property var controller
 property color ink:"white"
 property color accent:"cyan"
 property color surface:"black"
 visible:controller.showing
 MouseArea {anchors.fill:parent}
 Rectangle {
  objectName:"antipode-controls";width:Math.min(344,parent.width-24);height:content.implicitHeight+32
  x:(parent.width-width)/2;y:parent.height-height-12
  radius:ThemeDesign.radius(8);color:root.surface;border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.24))
  OverlayBody {
   id:content;x:16;y:16;width:parent.width-32
   OverlayHeader {title:"Farthest exit";closeName:"antipode-close";ink:root.ink;accent:root.accent;onClosed:controller.close()}
   Text {
    width:parent.width;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);wrapMode:Text.WordWrap
    text:{var r=controller.result;if(controller.loading)return "Loading exit countries…";if(controller.error)return controller.error;if(!r)return "";return r.winner.countryName+" · ~"+Number(r.distanceKm).toLocaleString(Qt.locale(),"f",0)+" km geographically\n"+r.winner.exitCount+" running exits"}
   }
   OverlayFooter {visible:!!controller.result&&controller.result.stale;width:parent.width;ink:root.ink;text:"Cached result"}
   ActionCardRow {
    ActionCard {objectName:"antipode-replay";kind:"play";text:"Replay";enabled:!controller.loading&&!!controller.result;ink:root.ink;accent:root.accent;onClicked:controller.replay()}
    ActionCard {objectName:"antipode-refresh";kind:"refresh";text:controller.error?"Retry":"Refresh";enabled:!controller.loading;ink:root.ink;accent:root.accent;onClicked:controller.open(true)}
   }
  }
 }
}
