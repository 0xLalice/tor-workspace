import ".."
import QtQuick
import "RouteGeometry.js" as Geometry

Canvas {
 id:root;objectName:"local-circuits-overlay"
 property var circuits:[]
 property var origin:({})
 function displayRoute(entry){return Geometry.vector(origin)&&entry.route.length?[Object.assign({},origin,{localDevice:true})].concat(entry.route):entry.route}
 onOriginChanged:if(visible)requestPaint()
 property bool showing:false
 property bool reducedMotion:false
 property real longitude:0
 property real latitude:0
 property color accent:ThemeColors.color("accent")
 property color secondary:ThemeColors.color("uiText")
 property var entries:[]
 property real clock:0
 property bool animating:false
 opacity:showing?1:0
 Behavior on opacity {NumberAnimation {duration:root.reducedMotion?0:200}}
 visible:showing||opacity>0
 function key(row){return row.id+":"+JSON.stringify(row.route)}
 function sync(initial){
  if(!showing)return
  var next={},old={},used={};entries.forEach(function(e){old[e.key]=e;used[e.slot]=true})
  circuits.forEach(function(row,i){var k=key(row),e=old[k]
   if(!e||e.removed!==undefined){
    var slot=0;while(used[slot])slot++;used[slot]=true
    e={key:k,id:row.id,route:row.route,slot:slot,start:clock+(initial?.2+i*.5/Math.max(1,circuits.length-1):0)}
   }
   next[k]=e
  })
  entries.forEach(function(e){if(!next[e.key]){if(e.removed===undefined)e.removed=clock;next[e.key]=e}})
  entries=Object.keys(next).map(function(k){return next[k]});animating=true;requestPaint()
 }
 onCircuitsChanged:sync(false)
 onShowingChanged:{if(showing){entries=[];sync(true)}else{animating=false;if(visible)requestPaint()}}
 onReducedMotionChanged:if(visible){animating=true;requestPaint()}
 onLongitudeChanged:if(visible)requestPaint()
 onLatitudeChanged:if(visible)requestPaint()
 onWidthChanged:if(visible)requestPaint()
 onAccentChanged:if(visible)requestPaint()
 onSecondaryChanged:if(visible)requestPaint()
 FrameAnimation {
  running:root.visible&&root.animating
  onTriggered:{root.clock+=Math.min(frameTime,.05);root.requestPaint()}
 }
 function circuitColor(slot){return Qt.hsla((.06+slot*.61803398875)%1,.75,.64,1)}
 function life(e){return e.removed!==undefined?(reducedMotion?0:Math.max(0,1-(clock-e.removed)/.3)):1}
 function amount(e){return reducedMotion?1:Math.max(0,Math.min(1,(clock-e.start)/.3))}
 onVisibleChanged:if(visible)requestPaint()
 onPaint:{
  if(!visible)return
  var c=getContext("2d");c.reset();var dots={},moving=false,retained=[]
  entries.forEach(function(e){
   var alpha=life(e),reveal=amount(e);if(alpha<=0)return
   retained.push(e);if(e.removed!==undefined||reveal<1)moving=true
   var color=circuitColor(e.slot)
   c.strokeStyle=color;c.lineWidth=1.3;c.lineCap="round"
   var route=displayRoute(e),legs=Geometry.legs(route)
   legs.forEach(function(leg){
    // Separate arcs sharing endpoints; every arc still meets the same relay dot.
    var lift=.055+.26*e.slot/(e.slot+8)
    var portion=Math.max(0,Math.min(1,reveal*Math.max(1,route.length-1)-leg.index))
    for(var back=1;back>=0;back--){
     c.globalAlpha=alpha*reveal*(back?.25:.95);c.beginPath();var drawing=false
     for(var n=0;n<=96*portion;n++){
      var p=Geometry.project(Geometry.arc(leg,n/96,lift),longitude,latitude,width)
      // Back-side paths are faint and dashed rather than silently omitted.
      if((back?!p.visible:p.visible)&&(!back||n%8<5)){
       if(drawing)c.lineTo(p.x,p.y);else c.moveTo(p.x,p.y);drawing=true
      }else drawing=false
     }c.stroke()
    }
   })
   route.forEach(function(hop,i){
    var v=Geometry.vector(hop);if(!v||reveal<i/Math.max(1,route.length-1))return
    var p=Geometry.project(v,longitude,latitude,width)
    var k=hop.localDevice?"local-device":hop.fingerprint
    if(!k)return
    if(!dots[k]||dots[k].alpha<alpha*reveal)dots[k]={x:p.x,y:p.y,alpha:alpha*reveal,back:p.z<0,localDevice:hop.localDevice===true}
   })
  })
  Object.keys(dots).forEach(function(k){var p=dots[k];c.globalAlpha=p.alpha*(p.back?.3:.95);c.fillStyle=root.secondary;c.beginPath();c.arc(p.x,p.y,p.localDevice?3:2,0,Math.PI*2);c.fill();if(p.localDevice){c.strokeStyle=root.secondary;c.lineWidth=1;c.beginPath();c.arc(p.x,p.y,6,0,Math.PI*2);c.stroke()}})
  root.animating=moving
  if(retained.length!==entries.length)root.entries=retained
 }
}
