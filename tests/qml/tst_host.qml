import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"Host";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;showLaunchControls:true;showPowerControls:true;state:"ready";route:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:46},{country:"US",longitude:-100,latitude:40}]}
 SignalSpy {id:starts;target:panel;signalName:"hostStartRequested"}
 SignalSpy {id:stops;target:panel;signalName:"hostStopRequested"}
 function init(){starts.clear();stops.clear();panel.torRunning=false;panel.hostState={state:"stopped",source:{mode:"folder",folder:"",port:3000},url:""}}
 function cleanup(){findChild(panel,"host-dialog").close();tryCompare(findChild(panel,"host-dialog"),"visible",false);width=460}
 function test_modes(){
  panel.torRunning=true;mouseClick(findChild(panel,"launch-tor-website"));var d=findChild(panel,"host-dialog");tryCompare(d,"opened",true)
  verify(!findChild(d,"host-start").enabled);compare(starts.count,0)
  d.close();tryCompare(d,"visible",false);mouseClick(findChild(panel,"launch-tor-app"));tryCompare(d,"opened",true);verify(findChild(d,"host-port").visible);compare(d.mode,"app");compare(findChild(d,"host-app-mode"),null)
  compare(findChild(d,"host-persistent"),null);compare(findChild(d,"host-list"),null)
  mouseClick(findChild(d,"host-start"));compare(starts.count,1);compare(starts.signalArguments[0][0].port,3000);verify(starts.signalArguments[0][0].persistent===undefined)
  panel.hostState={state:"starting",source:{mode:"app",port:3000},url:""};verify(!findChild(d,"host-port").enabled)
  panel.hostState={state:"ready",source:{mode:"app",port:3000},url:"http://"+"a".repeat(56)+".onion"}
  waitForPolish(d.contentItem);waitForRendering(panel)
  mouseClick(findChild(d,"host-copy"));compare(findChild(d,"host-copy").text,"Copied")
  keyClick(Qt.Key_Escape);tryCompare(d,"opened",false);compare(stops.count,0)
  panel.openHost();tryCompare(d,"opened",true);wait(50);mouseClick(findChild(d,"host-stop"));compare(stops.count,1)
 }
 function test_distinct_actions_and_active_owner(){
  panel.torRunning=true
  for(var mode of ["folder","app"]){
   var other=mode==="folder"?"app":"website",own=mode==="folder"?"website":"app"
   panel.hostState={state:"ready",source:{mode:mode,folder:"/home/user/site",port:3000},url:"http://example.onion"}
   verify(findChild(panel,"launch-tor-"+own).enabled)
   verify(!findChild(panel,"launch-tor-"+other).enabled)
   panel.triggerAction(other);verify(!panel.hostOpened)
   panel.triggerAction(own);var d=findChild(panel,"host-dialog");tryCompare(d,"opened",true);compare(d.mode,mode)
   compare(findChild(d,"host-copy").width,40);compare(findChild(d,"host-stop").width,40)
   d.close();tryCompare(d,"visible",false)
  }
 }
 function test_invalid_port_and_error_preserve_layout(){
  panel.torRunning=true;panel.openApp();var d=findChild(panel,"host-dialog");tryCompare(d,"opened",true)
  var port=findChild(d,"host-port"),start=findChild(d,"host-start")
  for(var value of ["", "0", "65536"]){port.text=value;verify(!start.enabled)}
  port.text="3000";verify(start.enabled);mouseClick(start)
  panel.hostState={state:"error",source:{mode:"folder",folder:""},error:"No app is listening on this local port. Start your app first."}
  compare(d.mode,"app");compare(port.text,"3000");verify(port.visible)
  verify(findChild(d,"host-status").text.indexOf("Start your app")>=0)
 }
 function test_picker_reopens_without_losing_selection(){
  panel.torRunning=true;panel.openHost();var d=findChild(panel,"host-dialog");tryCompare(d,"opened",true)
  d.close();tryCompare(d,"visible",false)
  panel.serviceAvailable=false
  panel.selectHostFolder("/home/user/new site");tryCompare(d,"opened",true)
  compare(d.folder,"/home/user/new site");verify(!findChild(d,"host-start").enabled)
  panel.serviceAvailable=true;verify(findChild(d,"host-start").enabled)
 }
 function test_layout_data(){return [{tag:"dark",w:460,ink:"#eeeeee",surface:"#111111"},{tag:"light-narrow",w:280,ink:"#111111",surface:"#ffffff"}]}
 function test_layout(data){
  width=data.w;panel.torRunning=true;panel.openHost();var d=findChild(panel,"host-dialog");tryCompare(d,"opened",true)
  panel.selectHostFolder("/home/user/my website");compare(d.folder,"/home/user/my website")
  d.ink=data.ink;d.surface=data.surface
  verify(findChild(d,"host-start").enabled);wait(50);mouseClick(findChild(d,"host-start"));compare(starts.signalArguments[0][0].mode,"folder")
  panel.hostState={state:"error",source:{mode:"folder",folder:d.folder},url:"",error:"Onion publication timed out. Start again."}
  wait(50);verify(d.height<=height);verify(d.width<=width)
  for(var name of ["host-start","host-copy","host-open"]){var b=findChild(d,name);verify(b.x+b.width<=b.parent.width+1)}
  grabImage(this).save("/tmp/tor-host-website-"+data.tag+".png")
  d.close();tryCompare(d,"visible",false);panel.hostState={state:"stopped",source:{mode:"app",port:3000}};panel.openApp();tryCompare(d,"opened",true)
  wait(50);verify(d.height<=height);verify(findChild(d,"host-port").visible)
  grabImage(this).save("/tmp/tor-host-app-"+data.tag+".png")
 }
}
