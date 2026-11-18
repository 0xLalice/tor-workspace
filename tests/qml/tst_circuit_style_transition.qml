import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/ColorRoles.js" as Roles

TestCase {
 id:test;name:"CircuitStyleTransition";when:windowShown;visible:true;width:402;height:600
 property var hops:[{country:"TH",longitude:101,latitude:15},{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:47},{country:"US",fingerprint:"exit",longitude:-77,latitude:39}]
 Tor.TorDashboard {id:panel;anchors.fill:parent;torRunning:true;state:"ready";installationReady:true;showPowerControls:true;effectSettings:Tor.ThemeColors.displayedSettings}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 function select(index){
  var preset=Builtins.entries[index]
  panel.closePresentation();panel.appearance=preset.appearance;panel.interfaceSettings=preset.interface
  Tor.ThemeColors.settingsSource=preset.settings
 }
 function init(){
  failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true
  panel.active=false;panel.visible=true;Tor.ThemeColors.animationEnabled=false;Tor.ThemeColors.palette=Roles.jade
  panel.route=[];wait(10);select(0);panel.circuitId="accepted";panel.route=hops;wait(30)
  panel.active=true;renew.clear()
 }
 function cleanup(){panel.active=false;Tor.ThemeColors.animationEnabled=false}
 function test_switch_crossfades_without_new_circuit(){
  var classic=findChild(panel,"ember-transition"),design=findChild(panel,"design-route")
  var key=classic.acceptedKey,accepted=classic.acceptedRoute,designAccepted=design.accepted
  var mesh=classic.oldMesh,designMesh=design.mesh
  verify(classic.initialized);verify(panel.globe.circuitDisplayed);compare(design.acceptedKey,key)
  wait(80);var clock=classic.clock
  Tor.ThemeColors.animationEnabled=true;select(1)
  tryCompare(Tor.ThemeColors,"transitioning",true);wait(500)
  verify(classic.opacity>0&&classic.opacity<1);verify(design.opacity>0&&design.opacity<1)
  verify(classic.visible&&design.visible);verify(!classic.transitioning);verify(!design.building);verify(!design.retiring)
  verify(classic.clock>=clock);compare(classic.acceptedKey,key);compare(design.acceptedKey,key)
  verify(classic.acceptedRoute===accepted);verify(design.accepted===designAccepted)
  verify(classic.oldMesh===mesh);verify(design.mesh===designMesh);verify(panel.globe.circuitDisplayed)
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  compare(classic.visible,false);compare(classic.nativeReady,false);verify(design.nativeReady)
  var paints=classic.paintCount;clock=classic.clock;wait(80);compare(classic.paintCount,paints);compare(classic.clock,clock)
  select(0);wait(350);select(1);wait(350);select(0)
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  compare(classic.acceptedKey,key);compare(design.acceptedKey,key)
  verify(!classic.transitioning);verify(!design.building);verify(!design.retiring)
  verify(panel.globe.circuitDisplayed);compare(design.visible,false);compare(design.nativeReady,false)
  compare(renew.count,0)
 }
 function test_real_replacements_still_animate(){
  var classic=findChild(panel,"ember-transition"),design=findChild(panel,"design-route")
  panel.circuitId="new-classic";tryCompare(classic,"transitioning",true)
  verify(classic.clock<classic.revealDuration);compare(classic.newRoute.length,4)
  select(1);wait(50);verify(!design.building) // A style switch does not replay this route.
  panel.circuitId="new-design";tryCompare(design,"building",true);verify(design.retiring)
  compare(design.accepted.length,4);compare(design.outgoing.length,4);compare(renew.count,0)
 }
 function test_hidden_theme_switch_keeps_ready_snapshot(){
  panel.active=false;panel.visible=false;select(1);wait(30);select(0);wait(30)
  panel.visible=true;panel.active=true;wait(30)
  var classic=findChild(panel,"ember-transition"),design=findChild(panel,"design-route")
  verify(classic.initialized);verify(!classic.transitioning);verify(!design.building)
  verify(panel.globe.circuitDisplayed);compare(renew.count,0)
 }
}
