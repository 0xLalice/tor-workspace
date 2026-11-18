import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 id:test;name:"ExitCountryRecovery";when:windowShown;visible:true;width:500;height:700
 property var route:[{country:"TH"},{country:"DE"},{country:"FR"},{country:"US"}]
 Component {id:dashboardFactory;Tor.TorDashboard {}}
 SignalSpy {id:chosen;signalName:"exitCountryChosen"}
 SignalSpy {id:pinned;signalName:"countryRestrictionChosen"}
 function test_recovery_data(){
  var rows=[]
  for(var layout=0;layout<=14;layout++)rows.push({tag:"layout-"+layout,layout:layout})
  return rows
 }
 function test_recovery(data){
  failOnWarning(/.*/)
  var panel=createTemporaryObject(dashboardFactory,test,{width:500,height:700,active:true,showLaunchControls:true,showPowerControls:true,torRunning:true,state:"ready",route:test.route,exitCountry:"US",exitCountries:[{code:"",name:"Automatic"},{code:"US",name:"United States"},{code:"NL",name:"Netherlands"}],interfaceSettings:{layout:data.layout,reducedMotion:true}})
  verify(panel)
  chosen.target=panel;pinned.target=panel;chosen.clear();pinned.clear()
  var selector=findChild(panel,data.layout===0?"exit-country-selector":"interface-exit-country-selector")
  verify(selector);tryCompare(selector,"visible",true)
  panel.route=[]
  for(var state of ["starting","error","unavailable","error"]){
   panel.state=state;panel.busy=state==="starting"
   verify(selector.visible);verify(selector.enabled)
   selector.open();verify(selector.opened)
   selector.choose(2);compare(chosen.signalArguments[chosen.count-1][0],"NL")
   var pin=findChild(selector,"exit-country-pin")
   verify(pin.visible);verify(pin.enabled)
   mouseClick(pin);compare(pinned.signalArguments[pinned.count-1][0],"")
  }
  // The footer's old route finishes fading out, but recovery stays accessible.
  wait(data.layout===0?1300:20)
  verify(selector.visible);verify(selector.enabled)
  compare(selector.observedCountry,"")
  panel.exitCountry="";verify(!findChild(selector,"exit-country-pin").visible)
  selector.open();verify(selector.opened);selector.choose(0)
  compare(chosen.signalArguments[chosen.count-1][0],"")
  panel.route=test.route;panel.state="ready"
  compare(selector.observedCountry,"US")
  panel.powerBusy=true;verify(!selector.visible||!selector.enabled)
  panel.powerBusy=false;panel.torRunning=false;verify(!selector.visible)
  panel.torRunning=true;panel.installationReady=false;verify(!selector.visible||!selector.enabled)
 }
}
