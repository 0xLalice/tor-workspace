import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"Updates";when:windowShown;visible:true;width:500;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true}
 SignalSpy {id:updates;target:panel;signalName:"updateRequested"}
 SignalSpy {id:checks;target:panel;signalName:"updateCheckRequested"}
 function init(){
  panel.active=true;panel.updateBusy=false
  panel.updateStatus={available:false,canUpdate:false,currentVersion:"0.1",checked:true,managed:true,releases:[{version:"0.1",kind:"installed",changes:["Current release features."]}]}
  updates.clear();checks.clear()
 }
 function cleanup(){panel.active=false;tryCompare(findChild(panel,"update-dialog"),"visible",false);tryCompare(findChild(panel,"tor-options"),"visible",false)}
 function openFromVersion(){
  var version=findChild(panel,"tor-version")
  waitForPolish(version);wait(150);mouseClick(version)
  tryCompare(panel,"updateOpened",true)
  compare(checks.count,1);compare(updates.count,0)
 }
 function entry(index){return findChild(panel,"changelog-entries").itemAt(index)}
 function versionOf(index){return findChild(entry(index),"release-version")}
 function test_current_version_opens_history(){
  var version=findChild(panel,"tor-version")
  compare(version.text,"v0.1");verify(!version.updateAvailable)
  verify(version.x>findChild(panel,"tor-header-logo").x)
  openFromVersion()
  compare(versionOf(0).text,"v0.1 ✓")
  verify(!findChild(panel,"update-continue").visible)
 }
 function test_update_badge_new_entry_and_action(){
  panel.updateStatus=Object.assign({},panel.updateStatus,{available:true,canUpdate:true,latestVersion:"0.2",releases:[
   {version:"0.2",kind:"available",changes:["Review each new feature in the changelog before installing the available update.","Read the second change in full."]},
   {version:"0.1",kind:"installed",changes:["Current release features."]}
  ]})
  verify(findChild(panel,"tor-version").updateAvailable)
  openFromVersion()
  compare(versionOf(0).text,"v0.2 ↑")
  var latest=entry(0), second=entry(1), note=findChild(latest,"release-summary")
  compare(note.text,panel.updateStatus.releases[0].changes.join(" "))
  compare(note.lineCount,1)
  verify(note.truncated)
  compare(latest.height,second.height)
  verify(latest.height<=note.implicitHeight+6)
  compare(second.y,latest.y+latest.height+2)
  verify(latest.Accessible.name.indexOf("Read the second change in full.")>=0)
  var next=findChild(panel,"update-continue")
  wait(100);mouseClick(next);tryCompare(updates,"count",1)
  panel.updateStatus=Object.assign({},panel.updateStatus,{canUpdate:false,error:"Local changes need attention."})
  verify(!next.enabled);mouseClick(next);compare(updates.count,1)
  mouseClick(findChild(panel,"update-recheck"));tryCompare(checks,"count",2)
 }
 function test_offline_still_shows_installed_history(){
  panel.updateStatus=Object.assign({},panel.updateStatus,{checked:false,error:"Could not check for updates."})
  openFromVersion()
  verify(entry(0).visible)
  verify(!findChild(panel,"tor-version").updateAvailable)
  verify(!findChild(panel,"update-continue").visible)
 }
 function test_options_uses_same_overlay(){
  panel.updateStatus=Object.assign({},panel.updateStatus,{available:true,latestVersion:"0.2"})
  panel.openOptions();tryCompare(findChild(panel,"tor-options"),"opened",true)
  var action=findChild(panel,"update-action");waitForPolish(action);wait(150)
  mouseClick(action);tryCompare(panel,"updateOpened",true)
  compare(versionOf(0).text,"v0.1 ✓")
 }
}
