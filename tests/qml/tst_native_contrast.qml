import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles

TestCase {
 id:test;name:"NativeContrast";when:windowShown;visible:true;width:120;height:120
 Rectangle {id:paper;anchors.fill:parent;color:"white"}
 Tor.NativeCircuitLoader {id:loader;anchors.fill:parent;onLoaded:item.antialiasing=true}
 readonly property var painter:loader.item
 function draw(){
  painter.reset();painter.beginFrame(0,0,120,false,false)
  painter.strokeStyle="black";painter.lineWidth=.65;painter.globalAlpha=.44
  painter.ripple({v:[0,0,1],u:[1,0,0],w:[0,1,0]},.55,1)
  painter.finishFrame()
  waitForRendering(painter);wait(30)
  return grabImage(test)
 }
 function ink(image){
  var total=0
  for(var y=0;y<height;y++)for(var x=0;x<width;x++)total+=1-image.pixel(x,y).r
  return total
 }
 function cleanup(){
  Tor.ThemeColors.palette=Roles.jade;Tor.ThemeDesign.design="original";paper.color="white"
  painter.strokeUnderlay=Qt.binding(()=>Tor.ThemeColors.treatment.circuitUnderlay?Tor.ThemeColors.treatmentValue(Tor.ThemeColors.treatment.circuitUnderlay):"transparent")
 }
 function test_light_palette_strengthens_actual_native_strokes(){
  Tor.ThemeDesign.design="meridian";Tor.ThemeColors.palette={themeId:"custom"}
  compare(painter.contrastGain,1);compare(painter.strokeScale,1)
  var baseline=draw(),before=ink(baseline)
  verify(before>0)
  Tor.ThemeColors.palette={themeId:"flexoki-light"}
  compare(painter.contrastGain,1.8);compare(painter.strokeScale,1.8)
  verify(ink(draw())>before*2,"Native strokes must become darker and thicker")
  Tor.ThemeColors.palette={themeId:"osaka-jade"}
  compare(painter.contrastGain,1);compare(painter.strokeScale,1)
  verify(baseline.equals(draw()),"Switching away must restore the original pixels")
 }
 function test_underlay_separates_dark_strokes_from_dark_surface(){
  Tor.ThemeColors.palette={themeId:"custom"};paper.color="black"
  painter.strokeUnderlay="transparent"
  var before=ink(draw())
  painter.strokeUnderlay="white"
  verify(ink(draw())<before-10,"A pale edge must remain visible beneath a dark route")
 }
}
