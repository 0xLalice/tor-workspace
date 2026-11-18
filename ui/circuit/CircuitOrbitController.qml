import ".."
import QtQuick
import "CircuitOrbit.js" as Orbit
import "RouteGeometry.js" as Geometry
QtObject {
 id:root
 property bool enabled:false
 property bool reducedMotion:false
 property var route:[]
 property var navigationRoute:[]
 readonly property var geography:Orbit.prepareRoute(navigationRoute)
 property real baseZoom:1
 property real previousBaseZoom:1
 property var releaseSettings:({})
 // A selected style applies to the current complete-pose return as well as
 // future input. Coalesce style bindings before adopting their final policy.
 readonly property string releaseKey:JSON.stringify(releaseSettings)
 onReleaseKeyChanged:Qt.callLater(adoptRecoveryPolicy)
 property var recoverySettings:({})
 property var config:Orbit.configuration(baseZoom,recovery?recoverySettings:releaseSettings)
 property real clock:0
 property var pose:null
 property var initialPose:null
 property bool frameInitialZoom:false
 property var recovery:null
 property var inputTarget:null
 property bool inputReleased:false
 property bool initialized:false
 property string acceptedGeography:""
 function recoverFrom(value,continuing){
  var policy=Orbit.configuration(baseZoom,releaseSettings).release
  if(continuing)policy.delay=0
  recoverySettings=policy;recovery={time:clock,pose:value}
 }
 function adoptRecoveryPolicy(){
  if(!initialized||!recovery||inputTarget)return
  var next=Orbit.configuration(baseZoom,releaseSettings).release
  if(next.blend===recoverySettings.blend&&next.maxRate===recoverySettings.maxRate)return
  // Rebase all axes on the displayed pose, without resetting the orbit clock
  // or replaying the user's idle delay. Zoom and rotation keep one easing curve.
  recoverFrom(Object.assign({},pose),true)
 }
 // Only hidden/opening framing is immediate. Visible user recovery always
 // interpolates the complete pose through the single recovery event below.
 function frameZoom(){
  if(!initialized||!pose)return
  var zoom=Orbit.pose(config,clock,navigationRoute,geography).zoom
  if(inputTarget)inputTarget=Object.assign({},inputTarget,{zoom:zoom})
  if(recovery)recovery={time:recovery.time,pose:Object.assign({},recovery.pose,{zoom:Orbit.pose(config,recovery.time,navigationRoute,geography).zoom})}
  pose=Object.assign({},pose,{zoom:zoom})
 }
 function retarget(force){
  if(!enabled)return;
  if(route.some(function(h){return Geometry.vector(h)!==null}))navigationRoute=route;
  var key=JSON.stringify(navigationRoute.map(function(h){return [h.longitude,h.latitude]}));
  if(initialized&&!force&&key===acceptedGeography)return;
  acceptedGeography=key;
  if(!initialized){initialized=true;pose=initialPose||Orbit.pose(config,clock,navigationRoute,geography);if(initialPose)recoverFrom(pose);if(frameInitialZoom)frameZoom()}
  else if(!inputTarget)recoverFrom(pose);
 }
 Component.onCompleted:retarget()
 onRouteChanged:retarget()
 onEnabledChanged:if(enabled)retarget(true)
 // Framing is a theme property, not a new orbit. Preserve clock, pose and
 // interaction offsets as the central appearance transition changes its zoom.
 onBaseZoomChanged:{
  var previous=Orbit.configuration(previousBaseZoom,releaseSettings)
  function difference(time){return Orbit.pose(root.config,time,root.navigationRoute,root.geography).zoom-Orbit.pose(previous,time,root.navigationRoute,root.geography).zoom}
  if(initialized&&pose){
   var shift=difference(clock)
   pose=Object.assign({},pose,{zoom:Orbit.clamp(pose.zoom+shift,.5,2.5)})
   if(inputTarget)inputTarget=Object.assign({},inputTarget,{zoom:Orbit.clamp(inputTarget.zoom+shift,.5,2.5)})
   if(recovery)recovery={time:recovery.time,pose:Object.assign({},recovery.pose,{zoom:Orbit.clamp(recovery.pose.zoom+difference(recovery.time),.5,2.5)})}
  }
  previousBaseZoom=baseZoom
  if(!initialized)retarget()
 }
 function beginInput(){if(!pose)return;inputTarget=inputTarget||Object.assign({},pose);inputReleased=false}
 function finishInput(){inputReleased=true}
 function wheel(steps,held){
  beginInput();if(!inputTarget)return;
  inputTarget=Object.assign({},inputTarget,{zoom:Orbit.clamp(inputTarget.zoom*Math.exp(Orbit.clamp(steps*.6*.07,-.18,.18)),.5,2.5)});
  inputReleased=!held;
  if(reducedMotion)pose=Object.assign({},inputTarget);
 }
 function drag(x1,y1,x2,y2){
  beginInput();if(!inputTarget)return;
  var p=inputTarget,s=.8*.65;
  var next=Geometry.dragOrientation(p.yaw,p.pitch,p.roll+p.tilt,x1,y1,x1+(x2-x1)*s,y1+(y2-y1)*s);
  inputTarget=Object.assign({},p,{yaw:next.longitude,pitch:Orbit.clamp(next.latitude,-80,80),roll:next.roll-p.tilt});
  if(reducedMotion)pose=Object.assign({},inputTarget);
 }
 function tick(dt){
  if(!enabled)return;
  if(!initialized)retarget();
  if(!initialized)return;
  dt=Math.min(dt,.05);clock+=dt;
  if(inputTarget){
   pose=Orbit.smoothInput(pose,inputTarget,dt);
   if(inputReleased&&Orbit.inputError(pose,inputTarget)<.01){recoverFrom(pose);inputTarget=null;inputReleased=false}
  }else {
   pose=Orbit.rejoin(config,clock,navigationRoute,recovery,geography);
   if(recovery&&clock-recovery.time>config.release.delay&&Orbit.inputError(pose,Orbit.pose(config,clock,navigationRoute,geography))<.00001)recovery=null;
  }
 }
 function reset(){if(initialized){beginInput();inputTarget=Orbit.pose(config,clock,navigationRoute,geography);if(reducedMotion)pose=Object.assign({},inputTarget);finishInput()}}
 function restart(){
  clock=0;inputTarget=null;inputReleased=false;recovery=null;initialized=false;pose=null;acceptedGeography=""
  retarget(true)
 }
}
