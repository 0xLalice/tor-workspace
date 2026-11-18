import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/shell/TorAvailability.js" as Availability
TestCase {
 name:"ActionAvailability";when:windowShown;visible:true;width:500;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;showPowerControls:true;state:"ready";route:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:46},{country:"US",longitude:-100,latitude:40}];showLaunchControls:true;active:true}
 SignalSpy {id:shares;target:panel;signalName:"shareStartRequested"}
 SignalSpy {id:stops;target:panel;signalName:"stopTor"}
 SignalSpy {id:speedStarts;target:panel;signalName:"speedStartRequested"}
 property var observedRoute:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:46},{country:"US",longitude:-100,latitude:40}]
 function init(){panel.installationReady=true;panel.powerBusy=false;panel.torRunning=false;panel.serviceAvailable=true;panel.route=observedRoute;panel.state="ready";panel.connectionMessage="";shares.clear();stops.clear()}
 function test_repair_still_allows_stop_but_no_network_start(){
  panel.torRunning=true;panel.installationReady=false
  verify(!panel.networkEnabled)
  var power=findChild(panel,"tor-power-button");verify(power.enabled);compare(power.text,"Stop Tor")
  mouseClick(power);compare(stops.count,1)
  panel.torRunning=false;verify(!power.enabled)
 }
 function test_unavailable_service_disables_actions_even_with_retained_drawing(){
  panel.torRunning=true
  for(var state of ["starting","unavailable","error"]){
   panel.state=state;panel.connectionMessage="Building a Tor circuit…"
   panel.serviceAvailable=false
   verify(!panel.networkEnabled)
   verify(!findChild(panel,"tor-header-logo").circuitReady)
   verify(findChild(panel,"origin-status").visible)
   compare(findChild(panel,"origin-status").text,"Building a Tor circuit…")
   for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
    var card=findChild(panel,"launch-tor-"+kind)
    verify(!card.enabled);compare(card.opacity,.28)
   }
   verify(findChild(panel,"tor-power-button").enabled)
  }
  panel.state="ready";panel.serviceAvailable=true
  verify(panel.networkEnabled);verify(!findChild(panel,"origin-status").visible)
 }
 function test_idle_keeps_actions_and_open_overlay_without_a_drawing(){
  var c={running:true,state:"ready",serviceReady:true,heartbeat:100,exitCountry:"DE",appliedCountry:"DE",policyReady:true,circuitId:"1"}
  panel.torRunning=true;panel.serviceAvailable=Availability.available(c,100,100)
  panel.openChat();var dialog=findChild(panel,"chat-dialog");tryCompare(dialog,"opened",true)
  c.state="starting";c.policyReady=false;c.circuitId="";panel.route=[]
  for(var i=0;i<30;i++){
   c.heartbeat=100+i*3
   panel.serviceAvailable=Availability.available(c,c.heartbeat,c.heartbeat)
   verify(panel.networkEnabled);verify(dialog.opened)
   for(var kind of ["browser","terminal","share","chat","website","app","darknet"])
    verify(findChild(panel,"launch-tor-"+kind).enabled)
  }
  verify(findChild(panel,"tor-header-logo").circuitReady)
  dialog.close();tryCompare(dialog,"visible",false)
 }
 function test_availability_rejects_stale_failed_and_uninitialized_service(){
  var c={running:true,state:"starting",serviceReady:true,heartbeat:100,exitCountry:"DE",appliedCountry:"DE"}
  verify(Availability.available(c,100,100))
  verify(!Availability.available(c,100,111));verify(!Availability.available(c,90,100))
  for(var change of [{running:false},{serviceReady:false},{state:"error"},{state:"unavailable"},{appliedCountry:"FR"},{heartbeat:0}])
   verify(!Availability.available(Object.assign({},c,change),100,100))
 }
 function test_unverified_or_stale_policy_disables_retained_route(){
  panel.torRunning=true;panel.state="ready";panel.serviceAvailable=false
  verify(!panel.networkEnabled)
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var card=findChild(panel,"launch-tor-"+kind);verify(!card.enabled);compare(card.opacity,.28)
  }
  verify(!findChild(panel,"tor-header-logo").circuitReady)
  panel.serviceAvailable=true;verify(panel.networkEnabled)
 }
 function test_disabled_cards(){
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var card=findChild(panel,"launch-tor-"+kind)
   verify(!card.enabled);compare(card.opacity,.28);mouseClick(card)
  }
  verify(!panel.shareOpened&&!panel.chatOpened&&!panel.hostOpened&&!panel.darknetOpened)
  verify(findChild(panel,"theme-action").enabled)
  verify(findChild(panel,"launch-tor-options").enabled)
  verify(findChild(panel,"tor-power-button").enabled)
  panel.torRunning=true
  for(var kind of ["browser","terminal","share","chat","website","app","darknet"]){
   var card=findChild(panel,"launch-tor-"+kind)
   verify(card.enabled);compare(card.opacity,1)
  }
 }
 function test_overlay_gate_data(){
  var rows=[]
  for(var action of [{kind:"share",open:"openShare",dialog:"file-share-dialog"},{kind:"chat",open:"openChat",dialog:"chat-dialog"},{kind:"website",open:"openWebsite",dialog:"host-dialog"},{kind:"app",open:"openApp",dialog:"host-dialog"},{kind:"darknet",open:"openDarknet",dialog:"darknet-dialog"}]){
   for(var busy of [false,true])rows.push({tag:action.kind+(busy?"-busy":"-off"),action:action,busy:busy})
  }
  return rows
 }
 function test_overlay_gate(data){
  var action=data.action,dialog=findChild(panel,action.dialog)
  panel[action.open]();compare(dialog.visible,false)
  panel.torRunning=true
  mouseClick(findChild(panel,"launch-tor-"+action.kind));tryCompare(dialog,"opened",true)
  if(data.busy)panel.powerBusy=true;else panel.torRunning=false
  tryCompare(dialog,"visible",false)
  panel[action.open]();compare(dialog.visible,false)
  var card=findChild(panel,"launch-tor-"+action.kind)
  verify(!card.enabled);compare(card.opacity,.28)
  panel.powerBusy=false;panel.torRunning=true
  panel[action.open]();tryCompare(dialog,"opened",true)
  dialog.close();tryCompare(dialog,"visible",false)
 }
 function test_late_picker_does_not_reopen(){
  panel.torRunning=true;panel.shareChoosing=true
  panel.torRunning=false;verify(!panel.shareChoosing)
  panel.shareSelection=["/tmp/late.txt"]
  compare(shares.count,0);compare(findChild(panel,"file-share-dialog").visible,false)
  panel.selectHostFolder("/tmp/late-folder")
  compare(findChild(panel,"host-dialog").visible,false)
  // Turning Tor back on must not revive a canceled file selection.
  panel.torRunning=true;panel.shareSelection=["/tmp/another-late.txt"]
  compare(shares.count,0);compare(findChild(panel,"file-share-dialog").visible,false)
 }
 function test_speed_requires_verified_circuit_but_cancel_remains_available(){
  panel.torRunning=true;panel.serviceAvailable=false;speedStarts.clear()
  var speed=findChild(panel,"speed-comparison");speed.open();tryCompare(speed,"opened",true)
  var action=findChild(speed,"speed-start")
  verify(!action.enabled);mouseClick(action);speed.start();compare(speedStarts.count,0)
  panel.serviceAvailable=true;verify(action.enabled);mouseClick(action);compare(speedStarts.count,1)
  panel.serviceAvailable=false;verify(action.enabled);compare(action.text,"Cancel")
  mouseClick(action);verify(!speed.running);verify(!action.enabled)
  speed.close();tryCompare(speed,"visible",false);panel.serviceAvailable=true
 }
}
