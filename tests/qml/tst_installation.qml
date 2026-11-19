import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/EffectSettings.js" as Effects
TestCase {
 name:"Installation";when:windowShown;visible:true;width:500;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;showPowerControls:true;showLaunchControls:true;active:true;installationReady:false;interfaceSettings:Effects.interfaceConfig(Builtins.entries[0].interface)}
 SignalSpy {id:launch;target:panel;signalName:"installationRequested"}
 SignalSpy {id:manual;target:panel;signalName:"installationManualRequested"}
 function test_manual_instructions(){
  panel.installationReady=false
  panel.openInstallation();tryCompare(panel,"installationOpened",true);wait(150)
  mouseClick(findChild(panel,"installation-manual"));tryCompare(manual,"count",1)
  tryCompare(panel,"installationOpened",false);wait(250)
 }
 function test_globe_and_two_step_installation(){
  compare(Tor.RenderCapabilities.nativeReady,false)
  verify(panel.globe.visible)
  tryCompare(panel.globe,"mapReady",true)
  var button=findChild(panel,"installation-button")
  verify(button.visible)
  var power=findChild(panel,"tor-power-button")
  verify(power.visible);verify(!power.enabled)
  compare(panel.interfaceVariation,3)
  var globeCenter=panel.globe.mapToItem(panel,panel.globe.width/2,panel.globe.height/2)
  fuzzyCompare(button.x+button.width/2,globeCenter.x,1)
  fuzzyCompare(button.y+button.height/2,globeCenter.y,1)
  var positions=[],lastY=-1
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var action=findChild(panel,"launch-tor-"+kind),pos=action.mapToItem(panel,0,0)
   verify(pos.x>panel.width*.75);verify(pos.y>lastY);lastY=pos.y
   positions.push({kind:kind,x:pos.x,y:pos.y})
  }
  var powerPosition=power.mapToItem(panel,0,0)
  var themes=findChild(panel,"tor-card-themes"),themeRight=themes.mapToItem(panel,themes.width,0)
  verify(themeRight.x<powerPosition.x)
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var action=findChild(panel,"launch-tor-"+kind)
   verify(action.visible);verify(!action.enabled);mouseClick(action)
  }
  verify(!panel.shareOpened&&!panel.chatOpened&&!panel.hostOpened&&!panel.darknetOpened)
  compare(launch.count,0)
  mouseClick(button);tryCompare(panel,"installationOpened",true)
  compare(launch.count,0)
  var next=findChild(panel,"installation-install");compare(next.text,"Install");wait(100);mouseClick(next);tryCompare(launch,"count",1)
  tryCompare(panel,"installationOpened",false)
  verify(!panel.installationReady);verify(button.visible);verify(!power.enabled)
  panel.installationReady=true
  verify(!button.visible);verify(power.visible);verify(power.enabled)
  compare(power.mapToItem(panel,0,0),powerPosition)
  for(var before of positions){
   var after=findChild(panel,"launch-tor-"+before.kind).mapToItem(panel,0,0)
   compare(after.x,before.x);compare(after.y,before.y)
  }
  verify(panel.globe.visible)
 }
}
