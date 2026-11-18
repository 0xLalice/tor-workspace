import ".."
import QtQuick

Item {
 id:root
 property string kind:""
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property bool preserveColor:false
 readonly property color drawingInk:enabled&&!preserveColor?ThemeColors.actionColor(ink,accent,glow>0):ink
 readonly property color drawingAccent:drawingInk
 readonly property real drawingWidth:ThemeColors.actionStroke(1.2,enabled&&glow>0)
 property real glow:0
 implicitWidth:24;implicitHeight:24
 ShareFileGlyph {anchors.fill:parent;visible:root.kind==="share";ink:root.drawingInk;accent:root.drawingAccent;glow:root.glow}
 Canvas {
  id:drawing;anchors.fill:parent;visible:root.kind!=="share"
  onWidthChanged:requestPaint()
  onHeightChanged:requestPaint()
  onVisibleChanged:if(visible)requestPaint()
  Connections {target:root;function onKindChanged(){drawing.requestPaint()}function onInkChanged(){drawing.requestPaint()}function onDrawingInkChanged(){drawing.requestPaint()}function onDrawingAccentChanged(){drawing.requestPaint()}function onDrawingWidthChanged(){drawing.requestPaint()}function onGlowChanged(){drawing.requestPaint()}}
  onPaint:{
   var c=getContext("2d");c.reset();var size=Math.min(width,height);c.translate((width-size)/2,(height-size)/2);c.scale(size/22,size/22)
   c.strokeStyle=Qt.tint(root.drawingInk,Qt.alpha(root.drawingAccent,.25*root.glow));c.shadowColor=root.drawingAccent;c.shadowBlur=ThemeColors.actionShadow(root.glow);c.lineWidth=root.drawingWidth
   if(root.kind==="browser"){
    c.beginPath();c.arc(11,11,8,0,Math.PI*2);c.stroke();c.beginPath();c.ellipse(7,3,8,16);c.moveTo(3,11);c.lineTo(19,11);c.stroke()
   }else if(root.kind==="terminal"){
    c.strokeRect(2,4,18,14);c.beginPath();c.moveTo(6,8);c.lineTo(9,11);c.lineTo(6,14);c.moveTo(12,14);c.lineTo(16,14);c.stroke()
   }else if(root.kind==="chat"){
    c.beginPath();c.moveTo(3,4);c.lineTo(19,4);c.lineTo(19,15);c.lineTo(9,15);c.lineTo(5,19);c.lineTo(5,15);c.lineTo(3,15);c.closePath();c.stroke()
    c.beginPath();c.moveTo(7,8);c.lineTo(15,8);c.moveTo(7,11);c.lineTo(12,11);c.stroke()
   }else if(root.kind==="options"){
    for(var i=0;i<3;i++){var y=5+i*6,x=i===1?14:8;c.beginPath();c.moveTo(3,y);c.lineTo(19,y);c.stroke();c.strokeRect(x-2,y-2,4,4)}
   }else if(root.kind==="darknet"){
    c.beginPath();c.moveTo(2,11);c.quadraticCurveTo(11,0,20,11);c.quadraticCurveTo(11,22,2,11);c.stroke();c.beginPath();c.arc(11,11,3,0,Math.PI*2);c.stroke();c.beginPath();c.moveTo(3,3);c.lineTo(19,19);c.stroke()
   }else if(root.kind==="website"){
    c.beginPath();c.moveTo(2,6);c.lineTo(9,6);c.lineTo(11,8);c.lineTo(20,8);c.lineTo(20,18);c.lineTo(2,18);c.closePath();c.stroke();c.beginPath();c.moveTo(2,6);c.lineTo(2,4);c.lineTo(9,4);c.lineTo(11,6);c.lineTo(18,6);c.stroke()
   }else if(root.kind==="app"){
    c.strokeRect(2,3,18,16);c.beginPath();c.moveTo(2,7);c.lineTo(20,7);c.moveTo(8,10);c.lineTo(5,13);c.lineTo(8,16);c.moveTo(14,10);c.lineTo(17,13);c.lineTo(14,16);c.stroke()
   }else if(root.kind==="host"){
    c.strokeRect(3,3,16,16);c.beginPath();c.moveTo(3,7);c.lineTo(19,7);c.moveTo(11,16);c.lineTo(11,10);c.moveTo(8,13);c.lineTo(11,10);c.lineTo(14,13);c.stroke()
   }else if(root.kind==="close"){
    c.beginPath();c.moveTo(5,5);c.lineTo(17,17);c.moveTo(17,5);c.lineTo(5,17);c.stroke()
   }else if(root.kind==="remove"){
    c.strokeRect(6,7,10,12);c.beginPath();c.moveTo(4,5);c.lineTo(18,5);c.moveTo(9,3);c.lineTo(13,3);c.moveTo(9,10);c.lineTo(9,16);c.moveTo(13,10);c.lineTo(13,16);c.stroke()
   }else if(root.kind==="copy"){
    c.strokeRect(4,7,10,12);c.beginPath();c.moveTo(8,7);c.lineTo(8,3);c.lineTo(18,3);c.lineTo(18,15);c.lineTo(14,15);c.stroke()
   }else if(root.kind==="stop"){
    c.strokeRect(5,5,12,12)
   }else if(root.kind==="refresh"){
    c.lineCap="round";c.lineJoin="round";c.beginPath();c.arc(11,11,7,-Math.PI*.2,Math.PI*1.5);c.stroke();c.beginPath();c.moveTo(7.5,1);c.lineTo(11,4);c.lineTo(7.5,7);c.stroke()
   }else if(root.kind==="open"){
    c.beginPath();c.moveTo(10,4);c.lineTo(4,4);c.lineTo(4,18);c.lineTo(18,18);c.lineTo(18,12);c.moveTo(10,12);c.lineTo(18,4);c.moveTo(12,4);c.lineTo(18,4);c.lineTo(18,10);c.stroke()
   }else if(root.kind==="play"){
    c.beginPath();c.moveTo(7,4);c.lineTo(18,11);c.lineTo(7,18);c.closePath();c.stroke()
   }else if(root.kind==="check"){
    c.beginPath();c.moveTo(4,11);c.lineTo(9,16);c.lineTo(18,6);c.stroke()
   }else if(root.kind==="record"){
    c.beginPath();c.arc(11,11,6,0,Math.PI*2);c.stroke()
   }else{
    c.strokeRect(3,3,6,6);c.strokeRect(13,3,6,6);c.strokeRect(3,13,6,6);c.fillStyle=root.drawingAccent;c.fillRect(13,13,6,6)
   }
   c.strokeStyle=root.drawingAccent;c.fillStyle=root.drawingAccent
   if(root.kind==="browser"){c.beginPath();c.moveTo(3,11);c.lineTo(19,11);c.stroke()}
   else if(root.kind==="terminal")c.fillRect(12,13.4,4,1.2)
   else if(root.kind==="chat"){c.beginPath();c.moveTo(7,11);c.lineTo(12,11);c.stroke()}
   else if(root.kind==="host")c.fillRect(4,4,14,2)
  }
 }
}
