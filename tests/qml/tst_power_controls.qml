import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"PowerControls";when:windowShown;visible:true;width:460;height:640
 Tor.TorDashboard {id:panel;anchors.fill:parent;showPowerControls:true;showLaunchControls:true;active:true;state:"offline";effectSettings:({transitionPreset:"ember",tunnel:true,layers:{tunnel:{rings:true,speed:.2}}})}
 SignalSpy {id:starts;target:panel;signalName:"startTor"}
 SignalSpy {id:stops;target:panel;signalName:"stopTor"}
 function test_stop_available_while_waiting_for_circuit(){
  panel.powerBusy=false;panel.torRunning=true;panel.state="starting"
  var power=findChild(panel,"tor-power-button");verify(power.enabled);compare(power.text,"Stop Tor")
  stops.clear();mouseClick(power);compare(stops.count,1)
  panel.torRunning=false;panel.state="offline"
 }
 function test_explicit_lifecycle(){
  var power=findChild(panel,"tor-power-button")
  compare(power.text,"Start Tor");compare(panel.route.length,0)
  verify(!findChild(panel,"launch-tor-browser").enabled)
  mouseClick(power);compare(starts.count,1);compare(panel.route.length,0)
  panel.powerBusy=true;panel.state="starting";verify(!power.enabled)
  panel.powerBusy=false;panel.torRunning=true;panel.state="ready"
  panel.route=[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"US",longitude:-77,latitude:39}]
  wait(60)
  var ember=findChild(panel.globe,"ember-transition")
  verify(ember.transitioning);compare(ember.oldRoute.length,0);compare(ember.newRoute.length,3)
  compare(power.text,"Stop Tor");mouseClick(power);compare(stops.count,1)
  panel.torRunning=false;panel.state="offline";panel.route=[];wait(40)
  verify(ember.retiring);compare(ember.oldRoute.length,3);compare(ember.newRoute.length,0)
  verify(ember.animating);verify(ember.transitioning)
  ember.advance(ember.retirementLifetime+1)
  compare(ember.oldRoute.length,0);compare(ember.newRoute.length,0);verify(!ember.initialized)
  compare(power.text,"Start Tor")
  grabImage(this).save("/tmp/tor-power-off.png")
  panel.torRunning=true;panel.state="ready";panel.route=[{country:"TH",longitude:101,latitude:15},{country:"FR",longitude:2,latitude:49},{country:"US",longitude:-77,latitude:39}];wait(40)
  verify(ember.transitioning);compare(ember.oldRoute.length,0)
 }
}
