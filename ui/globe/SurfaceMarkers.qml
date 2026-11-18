import ".."
import QtQuick
import "SurfaceGeometry.js" as Motion
Canvas {
 id:root
 property var config
 property var departureConfig:config
 onDepartureConfigChanged:if(visible)requestPaint()
 property var settings:({})
 property var routeA:[]
 property var routeB:[]
 property real clock:0
 property var pose
 property real sphereSize:width
 // Compact screen-space footprint applies to every look, including saved drafts.
 readonly property real markerScale:0.4
 readonly property var preparedMarkers:visible?Motion.prepareMarkers(routeA,routeB):[]
 readonly property var rows:visible&&config&&pose?Motion.projectMarkers(preparedMarkers,config,clock,pose,sphereSize,departureConfig):[]
 property int selected:0
 readonly property string labelFont:ThemeDesign.canvasFont(config&&config.labels?config.labels.size:12)
 onLabelFontChanged:if(visible)requestPaint()
 onConfigChanged:if(visible)requestPaint()
 onSettingsChanged:if(visible)requestPaint()
 onRouteAChanged:if(visible)requestPaint()
 onRouteBChanged:if(visible)requestPaint()
 onClockChanged:if(visible)requestPaint()
 onPoseChanged:if(visible)requestPaint()
 onWidthChanged:if(visible)requestPaint()
 onHeightChanged:if(visible)requestPaint()
 onVisibleChanged:if(visible)requestPaint()
 onPaint:{
  if(!visible||!config||!pose)return;
  var ctx=getContext("2d");ctx.reset();
  var rows=root.rows,occupied=[];
  function dot(x,y,r){ctx.beginPath();ctx.arc(x,y,Math.max(.1,r),0,Math.PI*2);ctx.fill()}
  rows.forEach(function(row){
   if(row.life<=0)return;
   var style=row.enter?config:departureConfig,m=style.marker,l=style.labels;
   var x=row.x+(width-sphereSize)/2,y=row.y+(height-sphereSize)/2,r=m.size*row.scale*markerScale;
   var normal=Qt.color(m.theme?(settings.markerColor||settings.mapColor||ThemeColors.color("transitionLight")):m.color),old=Qt.color(m.oldColor),blend=row.enter?(row.shared?1:1-m.blend*(1-row.progress)):0;
   var color=Qt.rgba(Motion.mix(old.r,normal.r,blend),Motion.mix(old.g,normal.g,blend),Motion.mix(old.b,normal.b,blend),1);
   ctx.fillStyle=color;ctx.strokeStyle=color;ctx.globalAlpha=row.life*m.opacity;
   if(m.glow>0&&m.halo>0){var grad=ctx.createRadialGradient(x,y,0,x,y,r*(1+m.halo*.45));grad.addColorStop(0,color);grad.addColorStop(1,"transparent");ctx.fillStyle=grad;ctx.globalAlpha=row.life*m.opacity*Math.min(1,m.glow);dot(x,y,r*(1+m.halo*.45));ctx.fillStyle=color;ctx.globalAlpha=row.life*m.opacity}
   if(m.halo>0){ctx.lineWidth=.5;ctx.beginPath();ctx.arc(x,y,r*(1+m.halo*.15),0,Math.PI*2);ctx.stroke()}
   if(row.kind===4&&!row.shared){for(var k=0;k<6;k++){var a=Motion.hash(k+row.index*17)*Math.PI*2,spread=(row.enter?1-row.progress:row.progress)*style.markerMotion.height;dot(x+Math.cos(a)*spread,y+Math.sin(a)*spread,r*.45)}}else dot(x,y,r);
   if(!l.mode||(l.mode===1&&row.index!==selected))return;
   var progress=Motion.progress(clock-l.delay,row.index,style,row.enter,true),fade=row.shared?1:row.enter?Motion.smooth(progress*(style.markerTiming||style.timing).enter/l.fade):1-Motion.smooth(progress*(style.markerTiming||style.timing).exit/l.fade);
   if(fade<=0)return;
   var label=row.country+(l.text?" · "+row.name:""),lx=x+r+l.offset,ly=y,box;
   var labelSize=ThemeDesign.px(l.size);
   ctx.font=ThemeDesign.canvasFont(l.size);box={x:lx,y:ly-labelSize,w:ctx.measureText(label).width+6,h:labelSize+6};
   if(l.suppress&&occupied.some(function(b){return box.x<b.x+b.w&&box.x+box.w>b.x&&box.y<b.y+b.h&&box.y+box.h>b.y}))return;
   occupied.push(box);ctx.globalAlpha=fade*.8;ctx.fillStyle=ThemeColors.color("markerLabelSurface");ctx.fillRect(box.x-3,box.y,box.w,box.h);ctx.globalAlpha=fade;ctx.fillStyle=color;ctx.fillText(label,lx,ly);
  });
 }
}
