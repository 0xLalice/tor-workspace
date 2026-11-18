import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"Chat";when:windowShown;visible:true;width:460;height:640
 Tor.TorDashboard {id:panel;anchors.fill:parent;showLaunchControls:true;showPowerControls:true;state:"ready";route:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:46},{country:"US",longitude:-100,latitude:40}]}
 SignalSpy {id:starts;target:panel;signalName:"chatStartRequested"}
 SignalSpy {id:stops;target:panel;signalName:"chatStopRequested"}
 SignalSpy {id:opens;target:panel;signalName:"chatOpenRequested"}
 function cleanup(){var d=findChild(panel,"chat-dialog");d.close();tryCompare(d,"visible",false);width=460}
 function init(){starts.clear();stops.clear();opens.clear();panel.torRunning=false;panel.chatState={state:"idle",url:""}}
 function test_room(){
  var action=findChild(panel,"launch-tor-chat");verify(action!==null)
  verify(!action.enabled);mouseClick(action);var dialog=findChild(panel,"chat-dialog");compare(dialog.visible,false)
  panel.torRunning=true;mouseClick(action);tryCompare(dialog,"opened",true)
  compare(starts.count,0);wait(50);mouseClick(findChild(dialog,"chat-start"));compare(starts.count,1)
  panel.chatState={state:"starting",url:""};verify(!findChild(dialog,"chat-open").enabled)
  panel.chatState={state:"ready",url:"http://example.onion"};verify(findChild(dialog,"chat-open").enabled);wait(50)
  mouseClick(findChild(dialog,"chat-copy"));compare(findChild(dialog,"chat-copy").text,"Copied")
  mouseClick(findChild(dialog,"chat-open"));compare(opens.count,1)
  compare(findChild(dialog,"chat-status").text,"Active")
  dialog.close();compare(stops.count,0)
  panel.active=false;panel.visible=false
  panel.visible=true;panel.active=true
  verify(findChild(panel,"chat-active-dot").visible)
  compare(findChild(panel,"chat-activity-label"),null)
  for(var layout of [0,3,7]){
   panel.interfaceVariation=layout;wait(50)
   var label=findChild(panel,"chat-active-dot")
   var position=label.mapToItem(panel,0,0)
   verify(position.x>=0&&position.x+label.width<=panel.width)
   grabImage(this).save("/tmp/tor-chat-active-"+layout+".png")
  }
  panel.interfaceVariation=0
  panel.openChat();tryCompare(dialog,"opened",true);wait(50)
  grabImage(this).save("/tmp/tor-chat-controls.png")
  mouseClick(findChild(dialog,"chat-stop"));compare(stops.count,1)
  panel.chatState={state:"stopped",url:""};verify(findChild(dialog,"chat-start").visible)
  verify(!findChild(panel,"chat-active-dot").visible)
  compare(findChild(panel,"chat-activity-label"),null)
  dialog.close()
 }
 function test_participant_counts_are_explicit(){
  panel.torRunning=true;panel.chatState={state:"ready",url:"http://example.onion",participants:0};panel.openChat()
  var d=findChild(panel,"chat-dialog");tryCompare(d,"opened",true)
  var label=findChild(d,"chat-status");compare(label.text,"0 connected")
  panel.chatState={state:"ready",url:"http://example.onion",participants:2};compare(label.text,"2 connected")
  panel.chatState={state:"ready",url:"http://example.onion"};compare(label.text,"Active")
  var close=findChild(d,"chat-close"),copy=findChild(d,"chat-copy")
  verify(close.width>=40&&close.height>=40);verify(copy.width>=40&&copy.height>=40)
 }
 function test_layout_data(){return [{tag:"dark",width:460,ink:"#eeeeee",surface:"#111111"},{tag:"narrow-light",width:280,ink:"#111111",surface:"#ffffff"}]}
 function test_layout(data){
  width=data.width;panel.torRunning=true
  panel.chatState={state:"starting",url:"",message:"Starting room…"}
  panel.openChat();var dialog=findChild(panel,"chat-dialog");tryCompare(dialog,"opened",true)
  dialog.ink=data.ink;dialog.surface=data.surface
  var stop=findChild(dialog,"chat-stop");tryCompare(stop,"activeFocus",true)
  panel.chatState={state:"ready",url:"http://example.onion",styleWarning:"Custom styling unavailable; using the standard OnionShare page."}
  var open=findChild(dialog,"chat-open");tryCompare(open,"activeFocus",true)
  compare(findChild(dialog,"chat-style-warning"),null)
  compare(findChild(dialog,"chat-room-row").height,64,"Same row height as shared files")
  verify(dialog.height<250,"Single room row and centered action: "+dialog.height)
  keyClick(Qt.Key_Tab);tryCompare(findChild(dialog,"chat-copy"),"activeFocus",true)
  keyClick(Qt.Key_Space);compare(dialog.copied,true)
  keyClick(Qt.Key_Tab);tryCompare(stop,"activeFocus",true)
  wait(50)
  for(var name of ["chat-open","chat-copy","chat-stop"]){
   var button=findChild(dialog,name)
   verify(button.x+button.width<=button.parent.width+1)
  }
  grabImage(this).save("/tmp/tor-chat-"+data.tag+".png")
  panel.chatState={state:"error",url:"",message:"Room did not become ready within 120 seconds. Retry."}
  tryCompare(findChild(dialog,"chat-start"),"activeFocus",true)
  compare(dialog.copied,false)
  verify(findChild(dialog,"chat-status").text.indexOf("120 seconds")>=0)
  var before=starts.count;keyClick(Qt.Key_Space);compare(starts.count,before+1)
  var stopped=stops.count;keyClick(Qt.Key_Escape);tryCompare(dialog,"opened",false);compare(stops.count,stopped)
  width=460
 }

}
