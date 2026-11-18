import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 id:test;name:"OverlayPolish";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;showLaunchControls:true}
 Tor.ShortcutRow {id:shortcut;visible:false;width:320;bindings:({open:{key:"SUPER + U"},move:{key:"SUPER + SHIFT + U"}})}
 Tor.CircuitToolTip {id:routeTip;route:[{role:"You",country:"TH"},{role:"Guard",country:"DE"},{role:"Middle",country:"CH"},{role:"Exit",country:"NL"}]}
 SignalSpy {id:changes;target:shortcut;signalName:"changed"}
 SignalSpy {id:darknet;target:panel;signalName:"launchDarknet"}
 function cleanup(){
  shortcut.visible=false;panel.active=false
  for(var name of ["tor-options","published-theme-chooser","darknet-dialog","chat-dialog","host-dialog","file-share-dialog"])tryCompare(findChild(panel,name),"visible",false)
  panel.active=true
 }
 function test_dialogs_compact(){
  for(var item of [{open:"openChat",name:"chat-dialog",limit:230},{open:"openHost",name:"host-dialog",limit:370},{open:"openShare",name:"file-share-dialog",limit:340},{open:"openDarknet",name:"darknet-dialog",limit:240}]){
   panel[item.open]();var dialog=findChild(panel,item.name);tryCompare(dialog,"opened",true)
   waitForRendering(panel);verify(dialog.height<item.limit,item.name+" height "+dialog.height)
   grabImage(test).save("/tmp/tor-polish-"+item.name+".png")
   dialog.close();tryCompare(dialog,"visible",false)
  }
 }
 function test_darknet_single_action(){
  panel.openDarknet();var dialog=findChild(panel,"darknet-dialog");tryCompare(dialog,"opened",true)
  compare(findChild(dialog,"darknet-back"),null)
  var go=findChild(dialog,"darknet-open");compare(go.text,"Open Ahmia")
  mouseClick(go);compare(darknet.count,1);tryCompare(dialog,"visible",false)
 }
 function test_shortcut_pair_input(){
  changes.clear();shortcut.visible=true
  var field=findChild(shortcut,"shortcut-key");field.forceActiveFocus();field.selectAll()
  keyClick(Qt.Key_I)
  compare(changes.count,1);compare(changes.signalArguments[0][0],"pair");compare(changes.signalArguments[0][1],"I")
 }
 function test_route_tooltip_is_contextual(){
  compare(routeTip.text,"Last observed route · DE → CH → NL")
  verify(routeTip.detail.indexOf("DE · Guard")>=0)
  verify(routeTip.detail.indexOf("CH · Middle")>=0)
  verify(routeTip.detail.indexOf("NL · Exit")>=0)
  routeTip.exitAction=true;verify(routeTip.detail.indexOf("lock exit")>=0)
 }
 function test_options_themes(){
  panel.shortcutStatus={bindings:{open:{key:"SUPER + U"},move:{key:"SUPER + SHIFT + U"}}}
  panel.openOptions();var options=findChild(panel,"tor-options");tryCompare(options,"opened",true);waitForRendering(panel)
  verify(options.height<panel.height);grabImage(test).save("/tmp/tor-polish-options.png")
  options.close();tryCompare(options,"visible",false)
  panel.availableThemes=[{id:"a",name:"Original"},{id:"b",name:"Quiet"}];panel.currentThemeId="a"
  mouseClick(findChild(panel,"theme-action"));var themes=findChild(panel,"published-theme-chooser");tryCompare(themes,"opened",true);waitForRendering(panel)
  verify(themes.height<230);grabImage(test).save("/tmp/tor-polish-themes.png")
 }
}
