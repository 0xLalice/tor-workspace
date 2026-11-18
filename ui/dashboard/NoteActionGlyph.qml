import ".."
import QtQuick

// Small, borderless action cards: labels remain available to hover and assistive technology.
Canvas {
 id:root
 property string action:""
 property color ink:"white"
 property color accent:ink
 property real glow:0
 readonly property color drawingInk:enabled?ThemeColors.actionColor(ink,accent,glow>0):ink
 readonly property color drawingAccent:drawingInk
 // Identical hover/focus emphasis for every internal theme.
 readonly property real drawingWidth:enabled&&glow>0?1.8:1.15
 onDrawingWidthChanged:if(visible)requestPaint()
 property real phase:0
 property bool twinkle:false
 onActionChanged:if(visible)requestPaint()
 onInkChanged:if(visible)requestPaint()
 onAccentChanged:if(visible)requestPaint()
 onDrawingAccentChanged:if(visible)requestPaint()
 onDrawingInkChanged:if(visible)requestPaint()
 onGlowChanged:if(visible)requestPaint()
 onPhaseChanged:if(visible)requestPaint()
 onTwinkleChanged:if(visible)requestPaint()
 onVisibleChanged:if(visible)requestPaint()
 onPaint:{
  if(!visible)return
  var ink=root.drawingInk,accent=root.drawingAccent
  var c=getContext("2d");c.reset();c.scale(width/22,height/22)
  c.strokeStyle=ink;c.fillStyle=ink;c.shadowColor=accent;c.shadowBlur=5*root.glow;c.lineWidth=root.drawingWidth;c.lineCap="round";c.lineJoin="round"
  function line(points){c.beginPath();c.moveTo(points[0],points[1]);for(var i=2;i<points.length;i+=2)c.lineTo(points[i],points[i+1]);c.stroke()}
  function circle(x,y,r){c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.stroke()}
  function dot(x,y,r){c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill()}
  switch(action){
  case "illuminate":
   var stars=[[5,7,2],[16,4,1.5],[13,16,2],[3,17,1]]
   for(var i=0;i<stars.length;i++){c.globalAlpha=twinkle?.35+.65*(i%2?phase:1-phase):.8;c.fillStyle=i===1?accent:ink;dot(stars[i][0],stars[i][1],stars[i][2])}break
  case "onion-address":circle(8,8,4);line([11,11,18,18,18,14]);line([15,15,17,13]);break
  case "onion-meeting":circle(11,11,2);line([3,5,7,5,11,9]);line([19,17,15,17,11,13]);dot(3,5,1);dot(19,17,1);break
  case "local-circuits":line([4,17,10,5,18,13]);circle(4,17,2);circle(10,5,2);circle(18,13,2);break
  case "file-transfer":line([5,3,13,3,17,7,17,19,5,19,5,3]);line([13,3,13,7,17,7]);line([8,13,14,13,11,10]);line([14,13,11,16]);break
  case "peel-layers":line([3,8,11,4,19,8,11,12,3,8]);line([3,12,11,16,19,12]);line([3,16,11,20,19,16]);break
  case "browser-protections":
   c.beginPath();c.arc(11,11,8,Math.PI,Math.PI*2);c.stroke();
   c.beginPath();c.arc(11,11,5,Math.PI,Math.PI*2);c.stroke();
   line([3,11,3,14]);line([6,11,6,16]);line([9,12,9,19]);line([12,10,12,17]);line([15,11,15,19]);line([19,11,19,15]);break
  case "compare-speed":c.beginPath();c.arc(11,13,8,Math.PI,Math.PI*2);c.stroke();line([3,13,3,17,19,17,19,13]);line([11,13,15,8]);dot(11,13,1);break
  case "snowflake":
   for(var n=0;n<6;n++){c.save();c.translate(11,11);c.rotate(n*Math.PI/3);line([0,0,0,-8]);line([-2,-5,0,-3,2,-5]);c.restore()}break
  case "onion-location":circle(11,11,8);line([7,11,15,11,12,8]);line([15,11,12,14]);break
  case "antipode":circle(11,11,8);line([5,17,17,5]);c.fillStyle=accent;dot(5,17,2);dot(17,5,2);break
  }
 }
}
