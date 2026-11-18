import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/EffectSettings.js" as Effects
import "../../ui/circuit/CircuitOrbit.js" as Camera
TestCase {
 id:test;name:"OrbitLayout";when:windowShown;visible:true;width:460;height:640
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready";showPowerControls:true;showLaunchControls:true
  route:[{country:"TH",longitude:101,latitude:15},{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:47},{country:"US",fingerprint:"exit",longitude:-77,latitude:39}]
  availableThemes:Builtins.entries;currentThemeId:"meridian"
 }
 SignalSpy {id:launch;target:panel;signalName:"launchBrowser"}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 function init(){
  failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true
  var preset=Effects.snapshot(Builtins.entries[1]);panel.appearance=preset.appearance
  panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true});panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  panel.torRunning=true;panel.active=true;launch.clear();renew.clear()
 }
 function cleanup(){panel.closePresentation();panel.active=false;Tor.ThemeDesign.fontScale=1;Tor.ThemeDesign.fontFamily=Qt.application.font.family}
 function test_geometry_data(){return [{tag:"normal",w:460,h:640,scale:1},{tag:"narrow",w:280,h:420,scale:1},{tag:"large-font",w:460,h:640,scale:1.5}]}
 function test_geometry(data){
  width=data.w;height=data.h;Tor.ThemeDesign.fontScale=data.scale;wait(100)
  var ring=findChild(panel,"orbit-controls"),buttons=[]
  verify(ring.visible);verify(!findChild(panel,"tor-action-cards").visible)
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var button=findChild(ring,"orbit-"+kind)
   verify(button!==null);verify(button.width>=44)
   var p=button.mapToItem(panel,0,0)
   verify(p.x>=0&&p.x+button.width<=width);verify(p.y>=30&&p.y+button.height<=height)
   compare(findChild(ring,"orbit-label-"+kind),null)
   for(var b of buttons)verify(Math.hypot(button.x-b.x,button.y-b.y)>=button.width+4,"Buttons overlap")
   buttons.push(button)
  }
  var radii=buttons.map(b=>Math.hypot(b.x+b.width/2-ring.width/2,b.y+b.height/2-ring.height/2))
  for(var r of radii)fuzzyCompare(r,radii[0],.01,"Every action belongs to the same circle")
  var spacing=Math.hypot(buttons[0].x-buttons[1].x,buttons[0].y-buttons[1].y)
  for(var i=0;i<buttons.length;i++){
   var a=buttons[i]
   verify(a.y+a.height/2<=ring.height/2+.01,"No action below the globe’s equator")
   if(i){var b=buttons[i-1];fuzzyCompare(Math.hypot(a.x-b.x,a.y-b.y),spacing,.01,"Even spacing along the open arc")}
  }
  fuzzyCompare(buttons[0].y+buttons[0].height/2,ring.height/2,.01)
  fuzzyCompare(buttons[6].y+buttons[6].height/2,ring.height/2,.01)
  for(var i=0;i<3;i++){
   fuzzyCompare(buttons[i].x+buttons[6-i].x+buttons[i].width,ring.width,.01)
   fuzzyCompare(buttons[i].y,buttons[6-i].y,.01)
  }
  var space=findChild(panel,"space-background"),center=panel.globe.mapToItem(space,panel.globe.width/2,panel.globe.height/2)
  compare(space.globeCenter.x,center.x);compare(space.globeCenter.y,center.y)
  var rail=findChild(panel,"circuit-rail"),globeCenter=panel.globe.mapToItem(panel,panel.globe.width/2,panel.globe.height/2)
  verify(globeCenter.y<=height/2+1&&globeCenter.y>=height*.33,"Compact panels reserve room below the circular actions")
  for(var button of buttons)verify(rail.y>=ring.y+button.y+button.height,"Circuit must clear every action")
  verify(rail.y+rail.height*panel.uiScale<=findChild(panel,"rotating-tor-note").y,"Circuit must precede cycling action: "+(rail.y+rail.height*panel.uiScale)+" / "+findChild(panel,"rotating-tor-note").y)
  compare(findChild(panel,"orbit-speed"),null);compare(findChild(panel,"orbit-circuits"),null)
  var first=buttons[0],x=first.x,y=first.y,radius=panel.globe.screenRadius
  verify(radius<ring.ringRadius-first.width/2,"Default globe obscures controls")
  waitForRendering(panel);grabImage(test).save("/tmp/jade-orbit-"+data.tag+".png")
  panel.globe.zoomCamera(1.2);wait(40);compare(first.x,x);compare(first.y,y)
  panel.globe.clearPresentation()
  compare(renew.count,0);compare(launch.count,0)
 }
 function test_header_matches_classic(){
  width=460;height=640
  function positions(){return ["tor-header-logo","tor-card-options","tor-card-themes","tor-power-button"].map(function(name){
   var item=findChild(panel,name),p=item.mapToItem(panel,0,0);verify(item.visible,name+" must be visible");return {x:p.x,y:p.y,w:item.width,h:item.height}
  })}
  var orbit=positions(),classic=Effects.snapshot(Builtins.entries[0])
  panel.interfaceSettings=classic.interface;panel.appearance=classic.appearance;wait(20)
  compare(positions(),orbit)
 }
 function test_camera_starts_small_after_theme_and_route_changes(){
  var controller=findChild(panel.globe,"circuit-orbit-controller")
  panel.globe.zoomCamera(2);panel.globe.restartCamera();wait(40)
  verify(panel.globe.zoomLevel<=.81);verify(!controller.inputTarget)
  panel.route=panel.route.slice();controller.tick(.02)
  verify(panel.globe.zoomLevel<=.81)
 }
 function test_orbit_zoom_returns_faster(){
  panel.active=false
  var controller=findChild(panel.globe,"circuit-orbit-controller")
  controller.restart();controller.recovery=null;controller.tick(0);controller.beginInput()
  controller.inputTarget=Object.assign({},controller.pose,{zoom:2,yaw:controller.pose.yaw+120})
  controller.pose=Object.assign({},controller.inputTarget);controller.finishInput()
  for(var i=0;i<210;i++)controller.tick(.05)
  var home=Camera.pose(controller.config,controller.clock,controller.navigationRoute,controller.geography)
  verify(Math.abs(controller.pose.zoom-home.zoom)<.001,"Orbit zoom must recover even after a large rotation")
  var classic=Camera.configuration(.7),homeClassic=Camera.pose(classic,0,panel.route),event={time:0,pose:Object.assign({},homeClassic,{zoom:2,yaw:homeClassic.yaw+120})}
  verify(Camera.rejoin(classic,10.5,panel.route,event).zoom>1.5,"Classic must retain its slower recovery")
 }
 function test_open_discards_hidden_zoom_data(){return [{tag:"motion",reduced:false},{tag:"reduced",reduced:true}]}
 function test_open_discards_hidden_zoom(data){
  panel.active=false;panel.interfaceSettings=Object.assign({},panel.interfaceSettings,{reducedMotion:data.reduced})
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  camera.clock=40;camera.inputTarget=null;camera.recovery=null;camera.tick(0)
  camera.pose=Object.assign({},camera.pose,{yaw:camera.pose.yaw+30,zoom:2})
  camera.recoverFrom(camera.pose)
  var yaw=camera.pose.yaw,clock=camera.clock,key=panel.globe.styleTransitionState.designKey
  panel.active=true
  fuzzyCompare(panel.globe.zoomLevel,Camera.pose(camera.config,clock,camera.navigationRoute,camera.geography).zoom,.0001)
  compare(camera.pose.yaw,yaw);compare(camera.clock,clock);compare(panel.globe.styleTransitionState.designKey,key)
  compare(renew.count,0)
 }
 function test_first_camera_pose_is_framed(){
  panel.active=false
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  panel.globe.temporaryZoom=2
  camera.restart()
  fuzzyCompare(panel.globe.zoomLevel,Camera.pose(camera.config,0,camera.navigationRoute,camera.geography).zoom,.0001)
 }
 function test_open_finishes_paused_inspection(){
  panel.active=true;panel.globe.focusRelay(panel.route[1],1)
  panel.globe.advanceInspection(1);verify(panel.globe.zoomLevel>1.5)
  panel.active=false;panel.globe.leaveRelay();panel.active=true
  verify(!panel.globe.inspectionCamera);verify(panel.globe.zoomLevel<.81)
 }
 function test_rotation_and_zoom_share_progress_data(){return [
  {tag:"zoom-only",yaw:0,pitch:0,roll:0},
  {tag:"small-drag",yaw:25,pitch:10,roll:5},
  {tag:"large-drag",yaw:120,pitch:15,roll:20}
 ]}
 function test_rotation_and_zoom_share_progress(data){
  panel.active=false
  var camera=findChild(panel.globe,"circuit-orbit-controller")
  camera.restart();camera.clock=30;camera.recovery=null;camera.inputTarget=null;camera.tick(0)
  var initial=Object.assign({},camera.pose),offset={yaw:data.yaw,pitch:data.pitch,roll:data.roll,zoom:2-initial.zoom}
  camera.pose=Object.assign({},initial,{yaw:initial.yaw+offset.yaw,pitch:initial.pitch+offset.pitch,roll:initial.roll+offset.roll,zoom:2})
  camera.recoverFrom(camera.pose)
  var duration=Math.max(camera.config.release.blend,1.875*Math.max(Math.abs(data.yaw),Math.abs(data.pitch),Math.abs(data.roll))/camera.config.release.maxRate)
  for(var progress of [0,.25,.5,.75,1]){
   camera.clock=30+camera.config.release.delay+duration*progress;camera.tick(0)
   var home=Camera.pose(camera.config,camera.clock,camera.navigationRoute,camera.geography),weight=1-Camera.smoother(progress)
   for(var axis of ["yaw","pitch","roll","zoom"]){
    if(offset[axis])fuzzyCompare((camera.pose[axis]-home[axis])/offset[axis],weight,.00001,axis+" must share recovery progress")
   }
  }
  compare(camera.recovery,null)
 }
 function test_arc_default_is_more_zoomed_out(){
  var classic=Builtins.entries[0],arc=Builtins.entries[1]
  verify(arc.settings.zoom<classic.settings.zoom)
  compare(panel.globe.configuredZoom,.65)
 }
 function test_keyboard_and_offline_actions(){
  width=460;height=640;wait(50)
  var browser=findChild(panel,"orbit-browser"),terminal=findChild(panel,"orbit-terminal"),options=findChild(panel,"tor-card-options")
  browser.forceActiveFocus();verify(browser.activeFocus);keyClick(Qt.Key_Tab);verify(terminal.activeFocus)
  options.forceActiveFocus();keyClick(Qt.Key_Space);tryCompare(findChild(panel,"tor-options"),"opened",true)
  panel.closePresentation();panel.torRunning=false;wait(20)
  verify(!browser.enabled);verify(options.enabled);verify(findChild(panel,"tor-card-themes").enabled)
  compare(launch.count,0);compare(renew.count,0)
 }
 function test_unavailable_actions_are_visibly_disabled(){
  panel.serviceAvailable=false
  var saved=panel.route,logo=findChild(panel,"tor-header-logo"),outline=findChild(logo,"onion-outline")
  for(var state of ["offline","starting","error","ready"]){
   panel.torRunning=state!=="offline";panel.state=state;panel.route=[];wait(20)
   verify(!logo.circuitReady);verify(!findChild(logo,"onion-light").visible);compare(outline.opacity,.28)
   for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
    var button=findChild(panel,"orbit-"+kind);verify(!button.enabled);compare(button.opacity,.28);mouseClick(button)
    panel.triggerAction(kind)
   }
   compare(launch.count,0);verify(!panel.shareOpened&&!panel.chatOpened&&!panel.hostOpened&&!panel.darknetOpened)
   verify(findChild(panel,"tor-power-button").enabled);verify(findChild(panel,"tor-card-options").enabled)
   waitForRendering(panel);grabImage(test).save("/tmp/tor-orbit-"+state+".png")
  }
  panel.route=saved;panel.state="ready";panel.serviceAvailable=true;verify(findChild(panel,"orbit-browser").enabled)
 }
 function test_font_and_palette_are_live(){
  var label=findChild(panel,"tor-version").contentItem
  Tor.ThemeDesign.fontFamily="serif";compare(label.font.family,"serif")
  Tor.ThemeDesign.fontScale=1.5;compare(label.font.pixelSize,Math.round(10*panel.headerScale*1.5))
  var ink=Qt.color(Tor.ThemeColors.color("uiText"));verify(ink.g>ink.r&&ink.g>ink.b,"Orbit text should use jade greens")
  var previous=Tor.ThemeColors.palette
  Tor.ThemeColors.palette=Object.assign({},previous,{background:"#202020",foreground:"#eeeeee",accent:"#90b0d0"})
  compare(String(panel.background),"#202020")
  Tor.ThemeColors.palette=previous
 }
}
