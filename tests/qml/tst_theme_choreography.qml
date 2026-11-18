import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/SoftIllumination.js" as Soft
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/circuit/CircuitOrbit.js" as Orbit
TestCase {
 id:test;name:"ThemeChoreography";when:windowShown;visible:true;width:402;height:600
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;torRunning:true;state:"ready";installationReady:true;showPowerControls:true;showLaunchControls:true
  effectSettings:Tor.ThemeColors.displayedSettings
  route:[{country:"TH",longitude:101,latitude:15},{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:47},{country:"US",fingerprint:"exit",longitude:-77,latitude:39}]
  circuitId:"retained"
 }
 function select(index){
  var preset=Builtins.entries[index];panel.closePresentation()
  panel.appearance=preset.appearance;panel.interfaceSettings=preset.interface;panel.presetCamera=preset.camera
  Tor.ThemeColors.settingsSource=index===0?Soft.adopt(preset.settings):preset.settings
 }
 function init(){
  failOnWarning(/.*/);panel.active=false;panel.visible=true;Tor.RenderCapabilities.nativeReady=true
  Tor.ThemeColors.animationEnabled=false;Tor.ThemeColors.palette=Roles.jade;select(0);wait(40)
  var camera=findChild(panel.globe,"circuit-orbit-controller");camera.clock=600;camera.recovery=null;camera.inputTarget=null;camera.inputReleased=false;camera.tick(0)
 }
 function cleanup(){panel.active=false;panel.globe.reducedMotion=Qt.binding(function(){return panel.reducedMotion});Tor.ThemeColors.animationEnabled=false}
 function test_camera_and_framing_are_continuous(){
  panel.active=true;Tor.ThemeColors.animationEnabled=true
  var camera=findChild(panel.globe,"circuit-orbit-controller"),globe=panel.globe
  var radius=globe.screenRadius,width=globe.width,zoom=globe.zoomLevel,clock=camera.clock,yaw=globe.longitude
  select(1)
  compare(globe.width,width);compare(globe.screenRadius,radius);compare(globe.zoomLevel,zoom)
  tryCompare(Tor.ThemeColors,"transitioning",true)
  Tor.ThemeColors.transition.pause()
  // Sample the easing curve deterministically: overloaded renderers may skip
  // several wall-clock frames during wait(100), which is not a framing jump.
  for(var i=1;i<=34;i++){
   var t=i/34
   Tor.ThemeColors.transitionProgress=t<.5?4*t*t*t:1-Math.pow(-2*t+2,3)/2
   wait(16)
   verify(camera.clock>=clock,"Theme changes must not restart the orbit")
   verify(Math.abs(globe.longitude-yaw)<1,"No saved-pose flash: "+JSON.stringify({before:yaw,after:globe.longitude,clock:camera.clock,pose:camera.pose,recovery:camera.recovery,orbit:globe.circuitOrbit}))
   verify(Math.abs(globe.screenRadius-radius)<6,"No single-frame zoom jump")
   verify(Math.abs(globe.zoomLevel-zoom)<.04,"Framing must ease with the appearance")
   clock=camera.clock;yaw=globe.longitude;radius=globe.screenRadius;zoom=globe.zoomLevel
  }
  Tor.ThemeColors.animationEnabled=false;Tor.ThemeColors.animationEnabled=true
  compare(Tor.ThemeColors.transitioning,false);verify(panel.globe.circuitDisplayed)
  select(0);wait(650);var shown=globe.screenRadius;select(1)
  verify(Math.abs(globe.screenRadius-shown)<.01,"Retarget from the visible framing")
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  verify(camera.clock>=clock);verify(panel.globe.circuitDisplayed)
 }
 function test_parallax_is_bounded_and_only_for_internal_designs(){
  var sky=findChild(panel,"space-background")
  compare(sky.travel(0),0);var baseline=sky.motionTime
  Tor.ThemeColors.animationEnabled=true;select(1)
  tryCompare(Tor.ThemeColors,"transitioning",true);Tor.ThemeColors.transition.pause()
  Tor.ThemeColors.transitionProgress=.5
  verify(sky.travel(0)<0);verify(sky.travel(2)>0)
  verify(Math.abs(sky.travel(0))<=sky.travelDistance);verify(Math.abs(sky.travel(2))<=sky.travelDistance)
  compare(sky.motionTime,baseline,"Sweep never rewrites the accumulated background clock")
  Tor.ThemeColors.animationEnabled=false;compare(sky.travel(2),0)
  Tor.ThemeColors.animationEnabled=true
  Tor.ThemeColors.palette=Object.assign({},Roles.jade,{themeId:"test-palette",background:"#222222"})
  tryCompare(Tor.ThemeColors,"transitioning",true);Tor.ThemeColors.transition.pause();Tor.ThemeColors.transitionProgress=.5
  compare(sky.travel(2),0,"Desktop color changes must not trigger the internal-design sweep")
  Tor.ThemeColors.animationEnabled=false
 }
 function test_theme_does_not_reset_an_interactive_camera(){
  panel.active=true;Tor.ThemeColors.animationEnabled=true
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  camera.beginInput();camera.inputTarget=Object.assign({},camera.pose,{yaw:camera.pose.yaw+25,zoom:1.4})
  camera.pose=Object.assign({},camera.inputTarget)
  var yaw=camera.inputTarget.yaw,clock=camera.clock
  select(1);wait(150)
  verify(camera.inputTarget!==null);compare(camera.inputReleased,false)
  compare(camera.inputTarget.yaw,yaw);verify(camera.clock>=clock)
 }
 function test_inflight_return_adopts_selected_theme_data(){return [
  {tag:"zoom-only",yaw:0}, {tag:"drag-and-zoom",yaw:80}
 ]}
 function test_inflight_return_adopts_selected_theme(data){
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  var home=Orbit.pose(camera.config,camera.clock,camera.navigationRoute,camera.geography)
  camera.pose=Object.assign({},home,{yaw:home.yaw+data.yaw,zoom:2})
  camera.recoverFrom(camera.pose)
  for(var i=0;i<80;i++)camera.tick(.05)
  verify(camera.recovery!==null)
  var before=Object.assign({},camera.pose),clock=camera.clock,key=panel.globe.styleTransitionState.designKey
  // Pause frame advancement so the moment of retargeting can be checked exactly.
  panel.active=true;panel.globe.reducedMotion=true;Tor.ThemeColors.animationEnabled=true
  select(1);tryCompare(Tor.ThemeColors,"transitioning",true);Tor.ThemeColors.transition.pause()
  wait(20)
  compare(camera.clock,clock);compare(camera.pose,before)
  compare(camera.recoverySettings.blend,3);compare(camera.recoverySettings.maxRate,24)
  compare(camera.recoverySettings.delay,0,"Do not replay the idle pause")
  compare(camera.recovery.time,clock)
  var event=JSON.parse(JSON.stringify(camera.recovery)),policy=Object.assign({},camera.recoverySettings)
  for(var i=0;i<60;i++){
   camera.tick(.05)
   var expected=Orbit.rejoin(Orbit.configuration(camera.baseZoom,policy),camera.clock,camera.navigationRoute,event,camera.geography)
   for(var axis of ["yaw","pitch","roll","zoom"])fuzzyCompare(camera.pose[axis],expected[axis],.00001)
  }
  if(!data.yaw){
   home=Orbit.pose(camera.config,camera.clock,camera.navigationRoute,camera.geography)
   fuzzyCompare(camera.pose.zoom,home.zoom,.0001,"Zoom-only recovery finishes at Theme 2's speed without input")
  }
  compare(panel.globe.styleTransitionState.designKey,key)
 }
 function test_reverse_switch_adopts_classic_speed(){
  select(1);wait(20)
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  camera.pose=Object.assign({},camera.pose,{zoom:2});camera.recoverFrom(camera.pose)
  camera.tick(.05);var clock=camera.clock
  select(0);wait(20)
  compare(camera.clock,clock);compare(camera.recoverySettings.blend,16);compare(camera.recoverySettings.maxRate,4)
  compare(camera.recoverySettings.delay,0)
 }
 function test_reduced_motion_applies_framing_immediately(){
  select(1);panel.interfaceSettings=Object.assign({},panel.interfaceSettings,{reducedMotion:true})
  compare(Tor.ThemeColors.transitioning,false)
  compare(panel.globe.configuredZoom,.65);compare(Tor.ThemeColors.orbitMix,1)
  compare(findChild(panel,"space-background").travel(2),0)
 }
}
