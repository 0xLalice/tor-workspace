import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "LegacyPorcelain.js" as Legacy
import "../../ui/circuit/CircuitOrbit.js" as Orbit
TestCase {
 id:test;name:"PorcelainLive";when:windowShown;visible:true;width:460;height:640
 property var preset:Legacy.preset
 property var route:[{country:"TH",longitude:101,latitude:15},{country:"LU",fingerprint:"guard",longitude:6,latitude:50},{country:"DE",fingerprint:"middle",longitude:10,latitude:51},{country:"JP",fingerprint:"exit",longitude:138,latitude:36}]
 Tor.TorDashboard {id:panel;anchors.fill:parent;anchors.margins:20;active:true;installationReady:true;showPowerControls:true;showLaunchControls:true;torRunning:true;canChange:true;state:"ready";route:test.route;circuitId:"live";availableThemes:Builtins.entries;currentThemeId:"porcelain";exitCountry:"JP";exitCountries:[{code:"",name:"Automatic"},{code:"JP",name:"Japan"},{code:"NL",name:"Netherlands"}]}
 SignalSpy {id:browser;target:panel;signalName:"launchBrowser"}
 SignalSpy {id:terminal;target:panel;signalName:"launchTerminal"}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 SignalSpy {id:country;target:panel;signalName:"exitCountryChosen"}
 function init(){
  failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true;panel.active=true;panel.torRunning=true;panel.powerBusy=false;panel.installationReady=true
  panel.appearance=preset.appearance;panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true});panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  browser.clear();terminal.clear();renew.clear();country.clear();wait(80)
 }
 function cleanup(){panel.closePresentation();width=460;height=640}
 function test_complete_dashboard(){
  for(var name of ["tor-header-logo","tor-logo-next-phrase","tor-version","tor-power-button","tor-card-options","tor-card-themes","theme-circuit-interface","lab-circuit-action","rotating-tor-note"]){
   var item=findChild(panel,name);verify(item!==null,name);verify(item.visible,name+" must be visible")
  }
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){var item=findChild(panel,"launch-tor-"+kind);verify(item!==null);verify(item.visible,"Missing direct action: "+kind);verify(item.enabled)}
  compare(findChild(panel,"paper-clay-dashboard"),null)
  compare(findChild(panel,"paper-more-menu"),null)
 }
 function test_controls(){
  mouseClick(findChild(panel,"launch-tor-browser"));compare(browser.count,1)
  mouseClick(findChild(panel,"launch-tor-terminal"));compare(terminal.count,1)
  mouseClick(findChild(panel,"lab-circuit-action"));compare(renew.count,1)
  var selector=findChild(findChild(panel,"theme-circuit-interface"),"interface-exit-country-selector");verify(selector);selector.open();verify(selector.opened);selector.choose(2);compare(country.count,1);compare(country.signalArguments[0][0],"NL")
  for(var item of [{button:"tor-card-options",dialog:"tor-options"},{button:"tor-card-themes",dialog:"published-theme-chooser"},{button:"launch-tor-share",dialog:"file-share-dialog"},{button:"launch-tor-chat",dialog:"chat-dialog"},{button:"launch-tor-website",dialog:"host-dialog"},{button:"launch-tor-app",dialog:"host-dialog"},{button:"launch-tor-darknet",dialog:"darknet-dialog"}]){
   mouseClick(findChild(panel,item.button));var dialog=findChild(panel,item.dialog);tryCompare(dialog,"opened",true);waitForRendering(panel);grabImage(test).save("/tmp/tor-porcelain-"+item.dialog+".png");dialog.close();tryCompare(dialog,"visible",false)
  }
 }
 function test_network_disabled(){
  panel.torRunning=false;wait(60)
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"])verify(!findChild(panel,"launch-tor-"+kind).enabled)
  verify(findChild(panel,"tor-card-themes").enabled);verify(findChild(panel,"tor-power-button").enabled)
  compare(browser.count,0);compare(terminal.count,0)
 }
 function test_bounds_data(){return [{tag:"normal",w:460,h:640},{tag:"narrow",w:280,h:420}]}
 function test_bounds(data){
  width=data.w;height=data.h;wait(60)
  for(var name of ["launch-tor-browser","launch-tor-terminal","launch-tor-share","launch-tor-chat","launch-tor-website","launch-tor-app","launch-tor-darknet","tor-card-options","tor-card-themes","tor-power-button"]){
   var item=findChild(panel,name);verify(item.visible,name);var a=item.mapToItem(test,0,0),b=item.mapToItem(test,item.width,item.height);verify(a.x>=0&&a.y>=0,name+" start");verify(b.x<=test.width&&b.y<=test.height,name+" bounds")
  }
  var space=findChild(panel,"space-background");compare(space.globeRadius,panel.globe.screenRadius);compare(space.globeCenter.x,space.width/2)
  grabImage(test).save("/tmp/tor-porcelain-dashboard-"+data.tag+".png")
 }
 function test_camera_data(){return [{tag:"motion",moving:true},{tag:"still",moving:false}]}
 function test_camera(data){
  panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:!data.moving});wait(100)
  var globe=panel.globe,pointer=findChild(globe,"globe-pointer");verify(!globe.externalCamera);verify(globe.circuitOrbit);verify(pointer.enabled)
  var yaw=globe.longitude,pitch=globe.latitude
  mousePress(pointer,pointer.width*.40,pointer.height*.65);mouseMove(pointer,pointer.width*.60,pointer.height*.72,40);mouseRelease(pointer,pointer.width*.60,pointer.height*.72);wait(180)
  verify(Math.abs(globe.longitude-yaw)>1||Math.abs(globe.latitude-pitch)>1,"Drag must rotate")
  var zoom=globe.zoomLevel;mouseWheel(pointer,pointer.width*.40,pointer.height*.65,0,600);wait(400);verify(globe.zoomLevel>zoom,"Wheel must zoom")
  var controller=findChild(globe,"circuit-orbit-controller"),pose=Orbit.pose(controller.config,controller.clock,controller.navigationRoute,controller.geography),deviation=Orbit.inputError(controller.pose,pose)
  mouseDoubleClickSequence(pointer,pointer.width*.40,pointer.height*.65);tryVerify(()=>Orbit.inputError(controller.pose,pose)<Math.max(.01,deviation*.5),1500,"Reset must return toward automatic camera")
 }
}
