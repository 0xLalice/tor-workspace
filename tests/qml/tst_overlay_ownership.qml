import QtQuick
import QtTest
import "../../ui" as Tor

TestCase {
 id:test;name:"OverlayOwnership";when:windowShown;visible:true;width:460;height:688
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready"
  showPowerControls:true;showLaunchControls:true
  interfaceSettings:({reducedMotion:true})
 }
 SignalSpy {id:shareStop;target:panel;signalName:"shareStopRequested"}
 SignalSpy {id:chatStop;target:panel;signalName:"chatStopRequested"}
 SignalSpy {id:hostStop;target:panel;signalName:"hostStopRequested"}
 function init(){panel.closePresentation();panel.forceActiveFocus();shareStop.clear();chatStop.clear();hostStop.clear()}
 function cleanup(){panel.closePresentation();Tor.ThemeDesign.apply({})}
 function test_programmatic_routes_are_exclusive(){
  panel.openShare();tryCompare(panel,"shareOpened",true)
  panel.openChat();tryCompare(panel,"chatOpened",true);tryCompare(panel,"shareOpened",false)
  panel.openWebsite();tryCompare(panel,"hostOpened",true);tryCompare(panel,"chatOpened",false)
  panel.openOptions();tryCompare(panel,"optionsOpened",true);tryCompare(panel,"hostOpened",false)
  panel.openShare();tryCompare(panel,"shareOpened",true);tryCompare(panel,"optionsOpened",false)
  panel.closePresentation();compare(shareStop.count,0);compare(chatStop.count,0);compare(hostStop.count,0)
 }
 function test_picker_return_uses_the_same_route(){
  panel.openChat();tryCompare(panel,"chatOpened",true)
  panel.shareChoosing=true;panel.shareSelection=["/fixture"]
  tryCompare(panel,"shareOpened",true);tryCompare(panel,"chatOpened",false)
  panel.selectHostFolder("/fixture-folder")
  tryCompare(panel,"hostOpened",true);tryCompare(panel,"shareOpened",false)
 }
}
