import QtQuick
import QtQuick.Controls
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles

TestCase {
 id:test;name:"EncryptionPalette";when:windowShown;visible:true;width:420;height:300
 Tor.PeelLayersIllustration {id:diagram;width:340;active:false}
 Tor.OverlayPanel {id:dialog;parent:test;width:340;height:200;reducedMotion:true}
 function init(){Tor.ThemeDesign.design="original";Tor.ThemeColors.palette=Roles.jade;Tor.ThemeColors.overrides={};diagram.reducedMotion=false}
 function cleanup(){dialog.close();Tor.ThemeDesign.design="original";Tor.ThemeColors.palette=Roles.jade;Tor.ThemeColors.overrides={}}
 function test_osaka_appearance_and_animation_unchanged(){
  compare(diagram.keyColors.map(c=>String(c)).join(","),"#579ee8,#b58ae8,#d6a144")
  compare(String(Tor.ThemeColors.color("modalScrim")),"#88050907")
  var timeline=findChild(diagram,"encryption-timeline")
  compare(timeline.duration,14000);compare(timeline.from,0);compare(timeline.to,10)
  var bundle=findChild(diagram,"animated-https-bundle")
  for(var i=0;i<10;i++){
   diagram.clock=i+.5
   compare(bundle.layers,[3,2,1,0,0,0,1,2,3,0][i])
  }
  diagram.reducedMotion=true;verify(!bundle.visible)
  verify(findChild(diagram,"peel-static-stages").visible)
 }
 function test_roles_follow_each_palette_input_without_switching_design(){
  var before=diagram.keyColors.map(c=>String(c)),scrim=String(Tor.ThemeColors.color("modalScrim"))
  for(var entry of [{base:"bright_blue",index:0},{base:"magenta",index:1},{base:"bright_yellow",index:2}]){
   var palette=Object.assign({},Roles.jade);palette[entry.base]="#85c9ae"
   Tor.ThemeColors.palette=palette
   verify(String(diagram.keyColors[entry.index])!==before[entry.index])
   for(var i=0;i<3;i++)if(i!==entry.index)compare(String(diagram.keyColors[i]),before[i])
  }
  Tor.ThemeColors.palette=Object.assign({},Roles.jade,{darker_background:"#302040"})
  verify(String(Tor.ThemeColors.color("modalScrim"))!==scrim)
  fuzzyCompare(Qt.color(Tor.ThemeColors.color("modalScrim")).a,136/255,.0001)
 }
 function test_orbit_remains_unchanged(){
  Tor.ThemeDesign.design="meridian"
  compare(String(diagram.keyColors[0]),String(Tor.ThemeColors.color("diagramAccent")))
  compare(String(diagram.keyColors[1]),String(Tor.ThemeColors.legible(Tor.ThemeColors.color("magenta"),diagram.surface,4.5)))
  compare(String(diagram.keyColors[2]),String(Tor.ThemeColors.legible(Tor.ThemeColors.color("yellow"),diagram.surface,4.5)))
  compare(String(Tor.ThemeColors.color("modalScrim")),String(Qt.alpha(Tor.ThemeColors.color("darker_background"),.65)))
 }
 function test_open_dialog_updates_its_actual_dimmer(){
  dialog.open();tryCompare(dialog,"opened",true)
  function dimmer(){
   var children=Overlay.overlay.children
   for(var i=0;i<children.length;i++)if(children[i].color!==undefined&&children[i].width>=test.width)return children[i]
   return null
  }
  var shade=dimmer();verify(shade!==null)
  compare(String(shade.color),"#88050907")
  Tor.ThemeColors.palette=Object.assign({},Roles.jade,{darker_background:"#302040"})
  compare(String(shade.color),String(Tor.ThemeColors.color("modalScrim")))
  verify(String(shade.color)!=="#88050907")
 }
 function test_white_orbit_overlay_has_a_clear_edge_without_grey_wash(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/white.json"),false);xhr.send()
  Tor.ThemeColors.palette=JSON.parse(xhr.responseText);Tor.ThemeDesign.design="meridian"
  dialog.open();tryCompare(dialog,"opened",true)
  compare(dialog.background.border.width,1)
  verify(Tor.ThemeColors.contrast(dialog.background.border.color,dialog.background.color)>=3)
  verify(Tor.ThemeColors.luminance(dialog.background.color)>.9)
  verify(Tor.ThemeColors.luminance(Tor.ThemeColors.color("modalScrim"))>.9)
  Tor.ThemeColors.palette=Roles.jade
  compare(dialog.background.border.width,0)
 }
}
