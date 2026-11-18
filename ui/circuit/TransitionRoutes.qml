import ".."
import QtQuick
import "../theme/EffectSettings.js" as Effects
import "TransitionTiming.js" as Timing
import "TransitionGeometry.js" as Mesh

Canvas {
 id:root
 readonly property bool nativeReady:nativePainter.status===Loader.Ready
 onNativeReadyChanged:{invalidateGeometry();if(nativeReady&&visible)requestPaint()}
 property var nativeReleasedGroups:null
 function syncNativeGeometry(){
  if(!nativeReady)return
  nativePainter.item.setGeometry(0,oldWorldGeometry)
  nativePainter.item.setGeometry(1,newWorldGeometry)
  nativeReleasedGroups=null;invalidateGeometry()
 }
 NativeCircuitLoader {
  id:nativePainter;anchors.fill:parent;active:root.visible&&RenderCapabilities.nativeReady
  onLoaded:{item.antialiasing=Qt.binding(()=>root.antialiasing);item.smooth=Qt.binding(()=>root.smooth);root.syncNativeGeometry();root.requestPaint()}
 }
 property int completedPaintCount:0
 Connections {target:nativePainter.item;function onFramePainted(){root.completedPaintCount++;root.painted()}}
 property var settings:null // null selects the Basic renderer
 property int appearance:0
 property var oldRoute:[]
 property var newRoute:[]
 property real clock:0
 property real oldEpoch:0
 property bool oldWasRevealed:false
 property bool transitioning:false
 property real seconds:1.5
 property real fade:1.5
 property real delay:0.3
 property real interval:0.22
 property real lead:0
 property int retirementBehavior:0 // 0: finish, 1: fade on route, 2: release
 property real disappearanceDuration:12
 property real driftStrength:1
 property real visibleFraction:0.6
 property real renderResolution:1
 readonly property real releaseAt:Math.min(0.35,disappearanceDuration*0.2)
 readonly property real fadeBegins:disappearanceDuration*(retirementBehavior===2?visibleFraction:0.25)
 readonly property real retirementAlpha:!transitioning||retirementBehavior===0?1:1-Timing.smooth((clock-fadeBegins)/(disappearanceDuration-fadeBegins))
 readonly property real retirementLifetime:retirementBehavior===0?oldLifetime+fade:disappearanceDuration
 property var releaseCache:null
 function clearRelease(){releaseCache=null;dirty=true}
 onDriftStrengthChanged:clearRelease()
 onRetirementBehaviorChanged:clearRelease()
 onDisappearanceDurationChanged:clearRelease()
 onOldEpochChanged:clearRelease()
 property int activityStyle:2
 property real retiredOpacity:0.28
 property bool drawingOld:false
 property bool drawingTraffic:false
 readonly property real retirementMix:transitioning?Timing.smooth(clock/0.35):0
 function activityColor(value,isOld){
  if(!isOld||activityStyle<2||!transitioning||(drawingTraffic&&retirementBehavior===2&&activityStyle!==3))return value
  var tint=activityStyle===3?Qt.rgba(retirementWarm.r,retirementWarm.g,retirementWarm.b,0.85*retirementMix):Qt.rgba(retirementMuted.r,retirementMuted.g,retirementMuted.b,0.9*retirementMix)
  return Qt.tint(value,tint)
 }
 function activityOpacity(isOld,traffic){
  if(!isOld||!transitioning)return 1
  if(traffic&&retirementBehavior===2)return retirementAlpha
  if(activityStyle===0)return traffic?retirementAlpha:1
  var target=traffic?Math.max(0.55,retiredOpacity):retiredOpacity
  return (1+(target-1)*retirementMix)*(traffic?retirementAlpha:1)
 }
 property int mode:0
 property int ringStyle:1
 property real ringBand:0.22
 property int ringExitStyle:0
 property real ringExitDuration:6
 property real ringExitScatter:0.55
 property real ringExitStrength:1
 onRingExitStyleChanged:dirty=true
 onRingExitDurationChanged:dirty=true
 onRingExitScatterChanged:dirty=true
 onRingExitStrengthChanged:dirty=true
 function ringNoise(id){var n=Math.sin(id*127.1+311.7)*43758.5453;return n-Math.floor(n)}
 function ringExitProgress(id,position){
  var duration=Math.max(0.1,Math.min(ringExitDuration,retirementLifetime))
  var order=Timing.clamp(position/Math.max(1,oldMesh.length))
  var stagger=(order*(1-ringExitScatter)+ringNoise(id)*ringExitScatter)*0.55
  return Timing.smooth((clock/duration-stagger)/(1-stagger))
 }
 function exitingRingVisual(id,position){
  var progress=ringExitProgress(id,position)
  if(ringExitStyle===4)return {exit:true,progress:progress,alpha:progress<1?1:0,radius:1,coverage:1,rotation:0,width:1}
  // Keep the breakup visible; fade only after the fragments have separated.
  return {exit:true,progress:progress,alpha:1-Timing.smooth((progress-0.45)/0.55),
   radius:1,coverage:1,rotation:0,width:1+Math.sin(Math.PI*progress)*(ringExitStyle===2?2.2:0.7)}
 }

 property int teardownStyle:0
 property real teardownDuration:4
 property real teardownDelay:0.5
 readonly property real teardownFront:teardownStyle===0?-Infinity:Timing.teardownProgress(clock,teardownDelay,teardownDuration,teardownStyle)*(oldMesh.length+ringBand)
 function teardownOpacity(position){return teardownStyle===0?1:Timing.smooth((position-teardownFront)/ringBand)}
 property real revealDuration:0.75
 property bool followTail:true
 property real longitude:0
 property real latitude:0
 property real globeSize:400
 property real lift:0.22
 property real tubeRadius:1
 property int rails:4
 property color oldColor:ThemeColors.color("retiringRoute")
 property color newColor:ThemeColors.color("enteringRoute")
 property bool animating:true
 property bool smoothMotion:false
 readonly property var routePalette:Effects.colors(settings,appearance)
 readonly property var trajectory:settings?Effects.trajectory(settings):({height:lift,profile:1})
 readonly property var tunnel:Effects.layer(settings,"tunnel")
 readonly property real pathHeight:trajectory.height
 readonly property real pathProfile:trajectory.profile
 readonly property real pathRadius:settings?tunnel.tubeRadius:tubeRadius
 readonly property var oldMesh:Mesh.build(oldRoute,pathHeight,pathProfile,pathRadius)
 readonly property var newMesh:Mesh.build(newRoute,pathHeight,pathProfile,pathRadius)
 readonly property var oldRippleBases:Mesh.rippleBases(oldRoute)
 readonly property var newRippleBases:Mesh.rippleBases(newRoute)
 readonly property var streams:makeStreams()
 readonly property real fallbackHop:settings?6.25:seconds
 readonly property real slowestHop:streams.reduce(function(a,s){return Math.max(a,s.hop)},fallbackHop)
 readonly property real fastestHop:(streams.length?streams.reduce(function(a,s){return Math.min(a,s.hop)},Infinity):fallbackHop)
 readonly property real oldLifetime:streams.reduce(function(a,s){return Math.max(a,(oldMesh.length+s.tail)*s.hop)},oldMesh.length*fallbackHop)
 readonly property real tailDelay:streams.reduce(function(a,s){return Math.max(a,s.frozen?0:s.tail*s.hop)},0)
 readonly property real newLifetime:streams.reduce(function(a,s){return Math.max(a,(newMesh.length+s.tail)*s.hop)},newMesh.length*fallbackHop)
 readonly property real buildStart:mode===3?0:delay+(mode===1?retirementLifetime:0)
 readonly property real birthStart:buildStart+(mode===2?newMesh.length*fastestHop:0)
 readonly property real activatedAt:mode===3?0:birthStart
 function structureFront(leg){return mode===3?Timing.clamp(clock/revealDuration*newMesh.length-leg):Timing.front(clock,buildStart,fastestHop,leg,lead)}
 function structureOpacity(leg){var original=mode===3?1-Timing.smooth(clock/revealDuration):Timing.oldOpacity(clock-tailDelay,leg,slowestHop,fade,followTail);return Math.min(original,teardownOpacity(leg+0.5),retirementAlpha)}
 readonly property real finish:Math.max(retirementLifetime,birthStart+newLifetime)
 readonly property int oldPackets:countFlights(true)
 readonly property int newPackets:transitioning?countFlights(false):0
 readonly property var oldWorldGeometry:Mesh.prepare(oldMesh,angles)
 readonly property var newWorldGeometry:Mesh.prepare(newMesh,angles)
 readonly property var nativeOldGeometry:Mesh.references(oldWorldGeometry,0)
 readonly property var nativeNewGeometry:Mesh.references(newWorldGeometry,1)
 onOldWorldGeometryChanged:syncNativeGeometry()
 onNewWorldGeometryChanged:syncNativeGeometry()
 property var cachedProjection:null
 property string projectionKey:""
 property int projectionBuilds:0
 property int paintCount:0
 property bool dirty:true
 onDirtyChanged:if(dirty&&visible&&!animating)Qt.callLater(function(){if(root.dirty&&root.visible&&!root.animating){root.dirty=false;root.requestPaint()}})
 onOldColorChanged:dirty=true
 onNewColorChanged:dirty=true
 Connections {target:ThemeColors;function onPaletteChanged(){root.dirty=true} function onOverridesChanged(){root.dirty=true}}
 property color retirementWarm:ThemeColors.color("retirementWarm")
 property color retirementMuted:ThemeColors.color("retirementMuted")
 property color arrivalWarm:ThemeColors.color("arrivalWarm")
 readonly property string anglesKey:{
  var list=[],count=settings?(settings.tunnel&&tunnel.rails?Math.max(1,Math.round(tunnel.railCount)):0):rails
  for(var i=0;i<count;i++)list.push(i*Math.PI*2/count)
  if(!settings||(settings.tunnel&&tunnel.rings))for(var i=0;i<12;i++)list.push(i*Math.PI*2/12)
  return JSON.stringify(list.filter(function(a,i){return list.indexOf(a)===i}))
 }
 readonly property var angles:JSON.parse(anglesKey)
 readonly property string releaseShape:JSON.stringify(streams.map(s=>[s.key,s.type,s.hop,s.interval,s.tail,s.params.count,s.params.spread]))
 onReleaseShapeChanged:clearRelease()
 function invalidateGeometry(){cachedProjection=null;dirty=true}
 onOldMeshChanged:invalidateGeometry()
 onNewMeshChanged:invalidateGeometry()
 onAnglesChanged:invalidateGeometry()
 onSettingsChanged:dirty=true
 onActivityStyleChanged:clearRelease()
 onRetiredOpacityChanged:dirty=true
 onClockChanged:{if(clock===0)releaseCache=null;dirty=true}
 onLongitudeChanged:dirty=true
 onLatitudeChanged:dirty=true
 onGlobeSizeChanged:invalidateGeometry()
 onWidthChanged:dirty=true
 onHeightChanged:dirty=true
 onVisibleChanged:if(visible){dirty=true;requestPaint()}
 onTransitioningChanged:clearRelease()
 // Schedule with the animation frame, not a competing 16 ms timer. Leave
 // dirty set until onPaint consumes it, so a pending update cannot be lost.
 FrameAnimation {running:root.visible&&root.animating;onTriggered:if(root.dirty)root.requestPaint()}
 function makeStreams(){
  if(!settings)return [{key:"basic",type:"packet",hop:seconds,interval:interval,tail:0.045,params:{count:1,width:1,intensity:1,glow:0.25}}]
  var out=[]
  function add(key,type,count,speed,tail){
   // Production renderer moves 0.16 of a leg per second at speed 1.
   // Ring callers supply speed * 0.75, matching their 0.12 base rate.
   var p=Effects.layer(settings,key),hop=speed>0?1/(0.16*speed):Infinity,n=Math.max(1,Math.round(count));
   out.push({key:key,type:type,hop:hop,interval:hop/n,tail:tail,params:p,colors:colorTable(p,Math.max(1,Math.round(p.count))),count:n,frozen:speed<=0})
  }
  if(settings.packets){var p=Effects.layer(settings,"packets");add("packets","packet",p.count,p.speed,p.length)}
  if(settings.arcs){var p=Effects.layer(settings,"arcs");add("arcs","arc",p.count,p.speed,p.length)}
  if(settings.particles){var p=Effects.layer(settings,"particles");add("particles","dot",p.count,p.speed,0)}
  if(settings.tunnel){
   if(tunnel.stream)add("tunnel","packet",tunnel.streamCount,tunnel.speed*tunnel.streamSpeed,tunnel.streamLength)
  }
  return out
 }
 function flights(stream,isOld){
  if(isOld&&transitioning&&retirementBehavior!==0&&clock>=disappearanceDuration)return []
  return rawFlights(stream,isOld,clock)
 }
 function rawFlights(stream,isOld,atTime){
  if(stream.frozen){
   if(!isOld||oldWasRevealed)return atTime>=birthStart?[{id:0,birth:birthStart,head:0,tail:0}]:[]
   var fixed=[]
   for(var i=0;i<oldMesh.length*stream.count;i++){
    var head=i/stream.count;fixed.push({id:i,birth:0,head:head,tail:Math.max(0,head-stream.tail)})
   }
   return fixed
  }
  var now=isOld&&transitioning?atTime+oldEpoch:atTime
  // Long-lived steady generation. Same origin and cutoff before/after handover.
  var origin=isOld?(oldWasRevealed?0:-100000*stream.interval):birthStart
  var stop=isOld&&transitioning?oldEpoch:now
  return Timing.flights(now,origin,stop,stream.interval,stream.hop,isOld?oldMesh.length:newMesh.length,stream.tail)
 }
 function flightSummary(stream,isOld,atTime){
  if(stream.frozen){var fixed=rawFlights(stream,isOld,atTime);return {count:fixed.length,tail:fixed.length?fixed[0].tail:Infinity}}
  var now=isOld&&transitioning?atTime+oldEpoch:atTime
  var origin=isOld?(oldWasRevealed?0:-100000*stream.interval):birthStart
  var stop=isOld&&transitioning?oldEpoch:now
  var range=Timing.flightRange(now,origin,stop,stream.interval,stream.hop,isOld?oldMesh.length:newMesh.length,stream.tail)
  var count=Math.max(0,range.last-range.first+1)
  return {count:count,tail:count?Math.max(0,(now-(origin+range.last*stream.interval))/stream.hop-stream.tail):Infinity}
 }
 // The slowest remaining traffic tail clears rings from origin to destination.
 // Rings are decoration here, so they must not keep an empty old circuit alive.
 readonly property real oldTrafficTail:{
  if(!transitioning)return -Infinity
  var found=false,tail=Infinity
  for(var i=0;i<streams.length;i++){
   if(streams[i].type==="ring")continue
   found=true
   var summary=clock>=disappearanceDuration&&retirementBehavior!==0?{tail:Infinity}:flightSummary(streams[i],true,clock)
   tail=Math.min(tail,summary.tail)
  }
  return found?tail:-Infinity
 }
 function ringVisual(head,isOld){
  var clearance=ringOpacity(head,isOld)
  var leg=Math.floor(head)
  var arrival=!isOld&&transitioning?Timing.smooth((structureFront(leg)-(head-leg))/ringBand):1
  var life=Math.min(clearance,arrival),closing=isOld&&transitioning
  if(ringStyle===0)return {alpha:life,radius:1,coverage:1,rotation:0,width:1}
  if(ringStyle===1)return {alpha:Math.sqrt(life),radius:life,coverage:1,rotation:0,width:1+1.5*(1-life)}
  if(ringStyle===2)return {alpha:Math.sqrt(life),radius:0.8+0.2*life,coverage:life,rotation:(closing?1:-1)*(1-life)*Math.PI,width:1}
  if(ringStyle===3)return {alpha:life*life,radius:closing?1+1.8*(1-life):0.3+0.7*life,coverage:1,rotation:0,width:1+3*Math.sin(Math.PI*life)}
  return {alpha:Math.sqrt(life),radius:1,coverage:life,rotation:(1-life)*Math.PI*2,width:1.5}
 }
 function ringOpacity(head,isOld){
  if(!isOld||!transitioning)return 1
  if(oldTrafficTail===-Infinity)return Math.min(structureOpacity(Math.floor(head)),teardownOpacity(head),retirementAlpha)
  return Math.min(retirementAlpha,Timing.smooth((head-Math.max(oldTrafficTail,teardownFront))/ringBand))
 }
 function countFlights(isOld){
  if(isOld&&transitioning&&retirementBehavior!==0&&clock>=disappearanceDuration)return 0
  var atTime=isOld&&transitioning&&retirementBehavior===2&&clock>=releaseAt?releaseAt:clock,n=0
  for(var i=0;i<streams.length;i++)n+=flightSummary(streams[i],isOld,atTime).count
  return n
 }
 function colorTable(p,count){
  var base=Effects.effectColor(p,routePalette.effect),list=[];
  for(var i=0;i<count;i++)list.push(p.multicolor?Effects.mixedColor(p.colorMix||[],i,count,p.colorDistribution||"interleaved",base):base);
  return list;
 }
 function streamColor(stream,id,count,fallback){
  if(!settings)return fallback;
  return stream.colors[((id%count)+count)%count];
 }
 function color(p,id,count,fallback){
  if(!settings)return fallback
  var base=Effects.effectColor(p,routePalette.effect)
  return p.multicolor?Effects.mixedColor(p.colorMix||[],id%count,count,p.colorDistribution||"interleaved",base):base
 }

 function stroke(c,points,start,end,tint,width,alpha){
  if(end<=start||alpha<=0)return
  c.strokeStyle=activityColor(tint,drawingOld);c.lineWidth=width;c.globalAlpha=alpha*activityOpacity(drawingOld,drawingTraffic);c.beginPath()
  c.strokeGeometry(points.nativeSide,points.nativeLeg,points.lane,start,end)
 }
 function drawStructures(c,geometry,isOld){
  var basicColor=isOld?oldColor:newColor
  for(var k=0;k<geometry.length;k++){
   var g=geometry[k],front=isOld?1:structureFront(k)
   var opacity=isOld&&transitioning?structureOpacity(k):1
   if(opacity<=0||front<=0)continue
   if(!settings||settings.tunnel){
    var p=settings?tunnel:{width:1,intensity:1},railCount=settings?Math.max(1,Math.round(tunnel.railCount)):rails
    if(!settings||tunnel.rails)for(var r=0;r<railCount;r++)stroke(c,g.lanes[r*Math.PI*2/railCount],0,front,color(p,r,railCount,basicColor),0.65*p.width,0.3*opacity*p.intensity)
    if(!settings||tunnel.core)stroke(c,g.center,0,front,settings?(p.guideColor||routePalette.atmosphere):basicColor,0.7*p.width,0.3*opacity*p.intensity)
   }
   if(settings&&settings.packets){var p=Effects.layer(settings,"packets");stroke(c,g.center,0,front,p.guideColor||routePalette.atmosphere,0.8*p.width,0.24*opacity*p.intensity)}
   if(settings&&settings.ribbon){
    var p=Effects.layer(settings,"ribbon"),base=color(p,0,p.count,basicColor)
    stroke(c,g.center,0,front,base,5*p.width,0.2*opacity*p.intensity)
    for(var j=0;j<48;j++){
     var t=j/48,flow=Math.pow(0.5+0.5*Math.sin((t-clock*p.speed*0.16)*Math.PI*2*p.count+k),5)
     stroke(c,g.center,t,Math.min(front,t+1/48),color(p,j,p.count,base),2.3*p.width,(0.12+flow*0.72)*opacity*p.intensity)
    }
   }
  }
 }
 function ringEntranceTint(tint,head){
  if(!transitioning)return tint
  var leg=Math.floor(head),arrival=mode===3?head/Math.max(1,newMesh.length)*revealDuration:buildStart+Math.max(0,head-lead)*fastestHop
  var settled=Timing.smooth((clock-arrival)/Math.max(0.5,revealDuration*0.5))
  return Qt.tint(tint,Qt.rgba(arrivalWarm.r,arrivalWarm.g,arrivalWarm.b,1-settled))
 }
 function drawTunnelRing(c,g,t,head,isOld,p,tint,id,initialHead){
      var visual=isOld&&transitioning&&ringExitStyle!==0?exitingRingVisual(id,initialHead):ringVisual(head,isOld);if(visual.alpha<=0)return
      c.strokeStyle=isOld?activityColor(tint,true):ringEntranceTint(tint,head);c.lineWidth=0.8*p.width*visual.width;c.globalAlpha=0.65*p.intensity*visual.alpha*(visual.exit?Math.max(0.65,activityOpacity(isOld,false)):activityOpacity(isOld,false));c.beginPath()
      c.ring(g.nativeSide,g.nativeLeg,t,visual,ringStyle,ringExitStyle,ringExitScatter,ringExitStrength,id)
 }
 function drawTunnelRings(c,geometry,isOld){
  if(settings&&(!settings.tunnel||!tunnel.rings))return
  var p=settings?tunnel:{count:8,speed:1,width:1,intensity:1},count=Math.max(1,Math.round(p.count))
  var time=clock+(isOld&&transitioning?oldEpoch:0)
  for(var k=0;k<geometry.length;k++)for(var i=0;i<count;i++){
   // The theme's moving cross-sections belong to each tunnel leg, not traffic.
   var initial=(i/count+oldEpoch*0.12*p.speed)%1
   // Ease retiring cross-sections to rest instead of wrapping them to another node.
   var t=isOld&&transitioning&&ringExitStyle===4?initial:isOld&&transitioning&&ringExitStyle!==0?Math.min(0.999999,initial+0.12*p.speed*0.4*(1-Math.exp(-clock/0.4))):(i/count+time*0.12*p.speed)%1
   drawTunnelRing(c,geometry[k],t,k+t,isOld,p,color(p,i,count,isOld?oldColor:newColor),k*count+i,k+initial)
  }
 }
 function drawFlights(c,geometry,isOld){
  if(isOld&&transitioning&&retirementBehavior===2&&clock>=releaseAt){drawReleased(c);return}
  for(var s=0;s<streams.length;s++){
   var stream=streams[s],p=stream.params,items=flights(stream,isOld),count=Math.max(1,Math.round(p.count)),base=isOld?oldColor:newColor
   if(stream.type==="dot"){
    var colors=stream.colors.map(function(tint){return root.activityColor(tint,isOld)})
    if(geometry.length)c.dots(geometry[0].nativeSide,items,p,clock,activityOpacity(isOld,true),colors)
    continue
   }
   for(var j=0;j<items.length;j++){
    var flight=items[j],tint=streamColor(stream,flight.id,count,base),head=flight.head,tail=flight.tail
     for(var k=Math.floor(tail);k<=Math.floor(head)&&k<geometry.length;k++){
      var from=Math.max(0,tail-k),to=Math.min(1,head-k),w=stream.type==="arc"?1.6:stream.key==="tunnel"?1.3:2.2
      // Glow is a cheap second stroke, never a full offscreen texture per layer.
      if(p.glow>0)stroke(c,geometry[k].center,from,to,tint,(w+3*p.glow)*p.width,0.13*p.glow*p.intensity)
      stroke(c,geometry[k].center,from,to,tint,w*p.width,0.9*p.intensity)
     }
   }
  }
 }
 function releasedGroups(){
  if(releaseCache){
   // Refresh paint values while retaining the released world-space geometry.
   releaseCache.forEach(function(group){
    var stream=streams.find(s=>s.key===group.stream.key)||group.stream
    group.stream=stream
    group.items.forEach(flight=>flight.tint=activityColor(streamColor(stream,flight.id,Math.max(1,Math.round(stream.params.count)),oldColor),true))
   })
   return releaseCache
  }
  var groups=[]
  for(var i=0;i<streams.length;i++){
   var stream=streams[i],flights=rawFlights(stream,true,releaseAt),items=[]
   for(var j=0;j<flights.length;j++){
    var flight=Mesh.releaseFlight(oldMesh,flights[j],stream.hop)
    if(flight){
     flight.acceleration=flight.acceleration.map(function(v){return v*driftStrength})
     if(stream.type==="dot"&&stream.params.spread){
      var t=flights[j].head%1,spread=Math.sin(Math.PI*t)*stream.params.spread
      var phase=flight.id,offset=Mesh.screenOffset(Math.sin(phase*12.7+releaseAt)*spread,Math.cos(phase*4.7+releaseAt)*spread,longitude,latitude,globeSize)
      var rate=isFinite(stream.hop)?Math.PI*Math.cos(Math.PI*t)*stream.params.spread/stream.hop:0
      var velocityOffset=Mesh.screenOffset(Math.cos(phase*12.7+releaseAt)*spread+Math.sin(phase*12.7+releaseAt)*rate,-Math.sin(phase*4.7+releaseAt)*spread+Math.cos(phase*4.7+releaseAt)*rate,longitude,latitude,globeSize)
      flight.head=flight.head.map(function(v,n){return v+offset[n]})
      flight.points=flight.points.map(function(point){return point.map(function(v,n){return v+offset[n]})})
      flight.velocity=flight.velocity.map(function(v,n){return v+velocityOffset[n]})
     }
     flight.tint=activityColor(streamColor(stream,flight.id,Math.max(1,Math.round(stream.params.count)),oldColor),true)
     items.push(flight)
    }
   }
   groups.push({stream:stream,items:items})
  }
  releaseCache=groups;return groups
 }

 function drawReleased(c){
  if(clock>=disappearanceDuration)return
  var groups=releasedGroups()
  if(nativeReleasedGroups!==groups){c.setReleasedGroups(groups);nativeReleasedGroups=groups}
  c.released(Math.max(0,clock-releaseAt),activityOpacity(true,true))
 }
 function drawRipples(c,geometry,isOld){
  if(!settings||!settings.ripples)return
  var p=Effects.layer(settings,"ripples"),bases=isOld?oldRippleBases:newRippleBases
  var count=Math.max(1,Math.round(p.count))
  var time=clock+(isOld&&transitioning?oldEpoch:0)
  for(var i=0;i<bases.length;i++){
   var basis=bases[i],arrival=birthStart+basis.hop*fastestHop
   if(!isOld&&clock<arrival)continue
   var opacity=isOld&&transitioning?Math.min(retirementAlpha,Timing.oldOpacity(clock,Math.max(0,basis.hop-1),slowestHop,fade,true)):1
   if(opacity<=0)continue
   for(var r=0;r<count;r++){
    var phase=((time-(isOld?0:arrival))*p.speed*0.6+r/count+basis.index*0.13)%1
    c.globalAlpha=Math.sin(Math.PI*phase)*0.7*p.intensity*opacity*activityOpacity(isOld,false)
    c.strokeStyle=activityColor(color(p,r,count,routePalette.effect),isOld);c.lineWidth=(r===0?1.1:0.6)*p.width
    c.ripple(basis,0.015+phase*p.radius,smoothMotion?2:1)
   }
  }
 }
 // Released traffic and surface ripples no longer use projected tunnel points.
 // Only discard them once both the old structure and every exit ring are gone.
 function oldGeometryFinished(){
  if(!transitioning||retirementBehavior!==2||clock<releaseAt||mode!==3||clock<revealDuration)return false
  if(!settings||(settings.tunnel&&tunnel.rings)){
   if(ringExitStyle===0||clock<Math.max(.1,Math.min(ringExitDuration,retirementLifetime)))return false
  }
  return true
 }
 function paintRoute(c,geometry,isOld){
  drawingOld=isOld;drawingTraffic=false
  drawStructures(c,geometry,isOld);drawTunnelRings(c,geometry,isOld)
  drawingTraffic=true;drawFlights(c,geometry,isOld)
  drawingTraffic=false;drawRipples(c,geometry,isOld)
 }
 onPaint:{
  if(!visible||!nativeReady)return
  dirty=false;
  paintCount++
  var drawOld=!transitioning||clock<retirementLifetime
  var projectOld=drawOld&&!oldGeometryFinished()
  var key=longitude+":"+latitude+":"+globeSize+":"+projectOld
  var c=nativePainter.item
  c.beginFrame(longitude,latitude,globeSize,projectOld,transitioning&&clock>=buildStart)
  cachedProjection={old:projectOld?nativeOldGeometry:[],next:nativeNewGeometry}
  if(projectionKey!==key){projectionKey=key;projectionBuilds++}
  c.reset();c.scale(renderResolution,renderResolution);c.translate((width/renderResolution-globeSize)/2,(height/renderResolution-globeSize)/2)
  if(drawOld){paintRoute(c,cachedProjection.old,true)}
  if(transitioning&&clock>=buildStart){paintRoute(c,cachedProjection.next,false)}
  c.finishFrame()
 }
}
