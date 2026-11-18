import ".."
import QtQuick

Column {
 id:root;objectName:"peel-layers-illustration"
 property bool active:false
 property bool reducedMotion:false
 property color ink:ThemeColors.color("uiText")
 property color surface:ThemeColors.color("background")
 property real clock:0
 readonly property int stage:Math.min(9,Math.floor(clock))
 readonly property bool response:stage>=5
 // Tor relay cells lose one layer outbound and gain one layer inbound.
 // https://spec.torproject.org/intro/
 readonly property var layerCounts:[3,2,1,0,0,0,1,2,3,0]
 readonly property int layers:layerCounts[stage]
 readonly property var keyColors:[ThemeColors.color("encryptionKey1"),ThemeColors.color("encryptionKey2"),ThemeColors.color("encryptionKey3")]
 readonly property var captions:["Request: client adds K3, K2, then K1.","Guard removes K1.","Middle removes K2.","Exit removes K3.","Website receives HTTPS content.","Response: website sends HTTPS content.","Exit adds K3.","Middle adds K2.","Guard adds K1.","Client removes K1, K2, then K3."]
 spacing:12
 onActiveChanged:if(active)clock=0
 NumberAnimation on clock {objectName:"encryption-timeline";running:root.active&&root.visible&&!root.reducedMotion;from:0;to:10;duration:14000;loops:Animation.Infinite}
 component Copy:Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);wrapMode:Text.WordWrap}
 component Bundle:Item {
  id:bundle;width:42;height:48
  property int layers:3
  Repeater {
   model:3
   Rectangle {
    required property int index
    width:42-index*8;height:ThemeDesign.definition.diagramSquareLayers?width:30-index*6;radius:ThemeDesign.radius(6);anchors.centerIn:parent
    color:"transparent";border.width:2;border.color:root.keyColors[index]
    visible:bundle.layers>=3-index
   }
  }
  Rectangle {width:16;height:18;radius:ThemeDesign.radius(3);anchors.centerIn:parent;color:root.surface;border.color:root.ink
   Rectangle {width:8;height:6;radius:ThemeDesign.radius(1);anchors.centerIn:parent;anchors.verticalCenterOffset:2;color:root.ink
    Rectangle {width:6;height:6;radius:ThemeDesign.radius(3);x:1;y:-4;color:"transparent";border.color:root.ink}
   }
  }
 }
 Row {
  width:parent.width
  Repeater {
   model:["Client","Guard\nK1","Middle\nK2","Exit\nK3","Website"]
   Column {
    id:participant
    required property string modelData
    required property int index
    width:parent.width/5
    Copy {width:parent.width;text:participant.modelData;horizontalAlignment:Text.AlignHCenter;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);color:participant.index>0&&participant.index<4?root.keyColors[participant.index-1]:root.ink}
    Row {
     visible:participant.index===0
     spacing:3;anchors.horizontalCenter:parent.horizontalCenter
     Repeater {model:3;Copy {required property int index;text:"K"+(index+1);color:root.keyColors[index];font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10)}}
    }
   }
  }
 }
 Item {
  width:parent.width;height:74;visible:!root.reducedMotion
  Rectangle {x:21;y:34;width:parent.width-42;height:1;color:root.ink;opacity:ThemeDesign.textOpacity(.25)}
  Bundle {
   objectName:"animated-https-bundle";layers:root.layers;y:10
   readonly property real position:{var t=root.clock;if(t<4)return Math.min(4,Math.floor(t)+Math.max(0,(t%1-.35)/.65));if(t<5)return 4;if(t<9)return Math.max(0,4-(Math.floor(t)-5)-Math.max(0,(t%1-.35)/.65));return 0}
   x:position*(parent.width-width)/4
  }
 }
 Copy {width:parent.width;visible:!root.reducedMotion;height:32;text:root.captions[root.stage]}
 Column {
  objectName:"peel-static-stages";width:parent.width;spacing:8;visible:root.reducedMotion
  Bundle {anchors.horizontalCenter:parent.horizontalCenter;layers:3}
  Copy {width:parent.width;text:"Request → Guard removes K1, Middle removes K2, Exit removes K3."}
  Copy {width:parent.width;text:"Response ← Exit adds K3, Middle adds K2, Guard adds K1. The client removes all three."}
 }
 Copy {width:parent.width;text:"HTTPS protects content between client and website.";font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);opacity:ThemeDesign.textOpacity(.7)}
}
