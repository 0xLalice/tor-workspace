import ".."
import QtQuick
import "../circuit/RouteGeometry.js" as Geo
Canvas {
 id:root;objectName:"antipode-diagram"
 required property var controller
 required property var globe
 property color ink:"white"
 property color accent:"cyan"
 readonly property string labelFont:ThemeDesign.canvasFont(12)
 onLabelFontChanged:if(visible)requestPaint()
 visible:controller.showing&&!!controller.result&&!controller.loading&&!controller.error
 readonly property var pose:visible?[globe.longitude,globe.latitude,globe.sceneRoll,globe.zoomLevel,controller.elapsed,controller.result,width,height]:null
 onPoseChanged:if(visible)requestPaint()
 onVisibleChanged:if(visible)requestPaint()
 onInkChanged:if(visible)requestPaint()
 onAccentChanged:if(visible)requestPaint()
 function project(v){
  var size=width*(globe.appearance===8?.82:1),p=Geo.project(v,globe.longitude,globe.latitude,size);
  var x=p.x-size/2,y=p.y-size/2,r=globe.sceneRoll*Math.PI/180;
  return {x:width/2+(x*Math.cos(r)-y*Math.sin(r))*globe.zoomLevel,y:height/2+(x*Math.sin(r)+y*Math.cos(r))*globe.zoomLevel,z:p.z}
 }
 onPaint:{
  if(!visible)return
  var c=getContext("2d");c.reset()
  var result=controller.result,stage=controller.stage;
  function marker(point,label,color,hidden,below){
   var p=project(Geo.vector(point));if(p.z<0&&!hidden)return
   c.globalAlpha=p.z<0?.5:1;c.fillStyle=color;c.beginPath();c.arc(p.x,p.y,5,0,Math.PI*2);c.fill();c.font=root.labelFont;
   var textWidth=c.measureText(label).width;
   c.fillText(label,Math.max(8,Math.min(width-textWidth-8,p.x+10)),p.y+(below?20:-10));c.globalAlpha=1
  }
  if(stage===1){
   c.fillStyle=accent;c.globalAlpha=.35
   result.countries.forEach(function(country){var p=project(Geo.vector(country));if(p.z>=0){c.beginPath();c.arc(p.x,p.y,2.5,0,Math.PI*2);c.fill()}})
   c.globalAlpha=1
  }
  if(stage===0||controller.reducedMotion)marker(result.origin,result.origin.countryName||result.origin.country||"Your country",ink,controller.reducedMotion,false)
  if(stage>=1)marker(result.winner,result.winner.countryName,accent,controller.reducedMotion,true)
 }
}
