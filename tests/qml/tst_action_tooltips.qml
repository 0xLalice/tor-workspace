import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins

TestCase {
 id:test;name:"ActionTooltips";when:windowShown;visible:true;width:460;height:688
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready"
  showPowerControls:true;showLaunchControls:true;availableThemes:Builtins.entries
 }
 function init(){failOnWarning(/.*/)}
 function cleanup(){panel.closePresentation();panel.forceActiveFocus();mouseMove(panel,10,height-10);Tor.ThemeDesign.apply({})}
 function apply(index){panel.interfaceSettings=Object.assign({},Builtins.entries[index].interface,{reducedMotion:true});wait(20)}
 function test_mouse_return_data(){return [
  {tag:"classic-share",theme:0,button:"launch-tor-share",dialog:"file-share-dialog"},
  {tag:"orbit-share",theme:1,button:"orbit-share",dialog:"file-share-dialog"},
  {tag:"classic-options",theme:0,button:"tor-card-options",dialog:"tor-options"},
  {tag:"orbit-options",theme:1,button:"tor-card-options",dialog:"tor-options"}
 ]}
 function test_mouse_return(data){
  apply(data.theme)
  var button=findChild(panel,data.button),tip=findChild(button,"dashboard-action-tooltip"),dialog=findChild(panel,data.dialog)
  // Retained mouse focus is distinct from keyboard navigation focus.
  button.forceActiveFocus(Qt.MouseFocusReason)
  mouseMove(button,button.width/2,button.height/2);tryCompare(tip,"opened",true,1000)
  mouseClick(button);tryCompare(dialog,"opened",true)
  mouseMove(panel,10,height-10);dialog.close();tryCompare(dialog,"visible",false)
  mouseMove(panel,20,height-20);tryCompare(button,"hovered",false)
  tryCompare(tip,"visible",false,800)
  // Hover must work again after dismissing the overlay.
  mouseMove(button,button.width/2,button.height/2);tryCompare(tip,"opened",true,1000)
  mouseMove(panel,10,height-10);tryCompare(tip,"visible",false,800)
 }
 function test_keyboard_focus_keeps_help_data(){return [{tag:"classic",theme:0},{tag:"orbit",theme:1}]}
 function test_keyboard_focus_keeps_help(data){
  apply(data.theme);mouseMove(panel,10,height-10)
  var button=findChild(panel,data.theme?"orbit-share":"launch-tor-share"),tip=findChild(button,"dashboard-action-tooltip")
  panel.forceActiveFocus()
  for(var i=0;i<40&&!button.activeFocus;i++)keyClick(Qt.Key_Tab)
  verify(button.activeFocus);verify(button.visualFocus)
  tryCompare(tip,"opened",true,1000)
  keyClick(Qt.Key_Tab);tryCompare(tip,"visible",false,800)
 }
}
