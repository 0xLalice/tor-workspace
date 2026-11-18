import ".."
import QtQuick
import "RouteGeometry.js" as Geometry
Item {
 id:root
 property var route:[]
 property var animatedRows:null
 property real longitude:0
 property real latitude:0
 property real roll:0
 property real zoom:1
 property real sphereSize:width
 property string selected:""
 property int hovered:-1
 property color accent:ThemeColors.color("uiAccent")
 signal selectedHop(var hop)
 readonly property var points:{
  if(!visible)return []
  var points=[],angle=roll*Math.PI/180
  for(var i=0;i<route.length;i++){
   var hop=route[i],v=Geometry.vector(hop)
   if(!v||!hop.fingerprint||!/^[a-fA-F0-9]{40}$/.test(hop.fingerprint))continue
   if(animatedRows!==null){
    var row=animatedRows.find(r=>r.enter&&r.life>.05&&Math.abs(r.longitude-hop.longitude)<.0001&&Math.abs(r.latitude-hop.latitude)<.0001)
    if(row)points.push({hop:hop,index:i,x:row.x+(width-sphereSize)/2,y:row.y+(height-sphereSize)/2})
    continue
   }
   var p=Geometry.project(v,longitude,latitude,sphereSize)
   if(p.z<.025)continue
   var dx=(p.x-sphereSize/2)*zoom,dy=(p.y-sphereSize/2)*zoom
   var x=width/2+dx*Math.cos(angle)-dy*Math.sin(angle),y=height/2+dx*Math.sin(angle)+dy*Math.cos(angle)
   points.push({hop:hop,index:i,ax:x,ay:y,x:x,y:y})
  }
  return points
 }
 function hit(x,y){
  var found=-1,distance=17
  for(var i=0;i<points.length;i++){var p=points[i],d=Math.hypot(x-p.x,y-p.y);if(d<distance){found=i;distance=d}}
  if(found<0)return found
  // A shared existing marker can represent several exact circuit identities.
  // Repeated clicks inspect each in circuit order without inventing more dots.
  var matches=[]
  for(var j=0;j<points.length;j++)if(Math.hypot(points[j].x-points[found].x,points[j].y-points[found].y)<1)matches.push(j)
  var current=matches.findIndex(i=>points[i].hop.fingerprint===selected)
  return matches[(current+1)%matches.length]
 }
 property real trajectoryHeight:.12
 property real trajectoryProfile:1
 function hitRoute(x,y){
  var legs=Geometry.legs(route),angle=roll*Math.PI/180
  for(var leg of legs){
   var previous=null
   for(var i=0;i<=48;i++){
    var p=Geometry.project(Geometry.arc(leg,i/48,trajectoryHeight,trajectoryProfile),longitude,latitude,sphereSize)
    if(!p.visible){previous=null;continue}
    var dx=(p.x-sphereSize/2)*zoom,dy=(p.y-sphereSize/2)*zoom
    var point={x:width/2+dx*Math.cos(angle)-dy*Math.sin(angle),y:height/2+dx*Math.sin(angle)+dy*Math.cos(angle)}
    if(previous){
     var vx=point.x-previous.x,vy=point.y-previous.y,length=vx*vx+vy*vy
     var t=length?Math.max(0,Math.min(1,((x-previous.x)*vx+(y-previous.y)*vy)/length)):0
     if(Math.hypot(x-previous.x-t*vx,y-previous.y-t*vy)<8)return true
    }
    previous=point
   }
  }
  return false
 }
 function activate(index){if(index>=0&&index<points.length)selectedHop(points[index].hop)}
 function restoreFocus(){for(var i=0;i<repeater.count;i++)if(repeater.itemAt(i).modelData.hop.fingerprint===selected){repeater.itemAt(i).forceActiveFocus();return}}
 Repeater {
  id:repeater;model:root.visible?root.points.length:0
  delegate:Item {
   required property int index
   readonly property var modelData:root.points[index]
   objectName:"relay-target-"+modelData.index
   x:modelData.x-16;y:modelData.y-16;width:32;height:32
   activeFocusOnTab:true
   Accessible.role:Accessible.Button;Accessible.name:(modelData.hop.role||"Relay")+" "+(modelData.hop.name||modelData.hop.fingerprint)
   Keys.onReturnPressed:root.activate(index)
   Keys.onSpacePressed:root.activate(index)
  }
 }
}
