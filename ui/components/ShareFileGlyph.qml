import ".."
import QtQuick

Canvas {
 id:root
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property real glow:0
 readonly property real drawingWidth:ThemeColors.actionStroke(1.2,enabled&&glow>0)
 onDrawingWidthChanged:requestPaint()
 implicitWidth:22;implicitHeight:22
 onInkChanged:requestPaint()
 onAccentChanged:requestPaint()
 onGlowChanged:requestPaint()
 onVisibleChanged:if(visible)requestPaint()
 onPaint:{
  var c=getContext("2d");c.reset();c.scale(width/22,height/22)
  c.strokeStyle=Qt.tint(ink,Qt.alpha(accent,.25*glow));c.shadowColor=accent;c.shadowBlur=ThemeColors.actionShadow(glow);c.lineWidth=root.drawingWidth
  c.beginPath();c.moveTo(5,3);c.lineTo(13,3);c.lineTo(17,7);c.lineTo(17,19);c.lineTo(5,19);c.closePath();c.stroke()
  c.beginPath();c.moveTo(13,3);c.lineTo(13,7);c.lineTo(17,7);c.stroke()
  c.strokeStyle=accent;c.beginPath();c.moveTo(8,12);c.lineTo(14,12);c.moveTo(11,9);c.lineTo(14,12);c.lineTo(11,15);c.stroke()
 }
}
