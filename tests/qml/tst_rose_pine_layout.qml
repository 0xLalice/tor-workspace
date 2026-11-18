import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/ColorRoles.js" as Roles
TestCase {
 id:test;name:"LightPaletteLayouts";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready";installationReady:true;showPowerControls:true;showLaunchControls:true;availableThemes:Builtins.entries
  route:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:47},{country:"US",longitude:-77,latitude:39}]
 }
 function initTestCase(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/rose-pine.json"),false);xhr.send()
  Tor.ThemeColors.palette=JSON.parse(xhr.responseText);Tor.RenderCapabilities.nativeReady=true
 }
 function cleanupTestCase(){Tor.ThemeColors.palette=Roles.jade;Tor.ThemeDesign.design="original";Tor.RenderCapabilities.nativeReady=false}
 function test_light_overlays_data(){var layouts=[{tag:"classic-normal",index:0,narrow:false},{tag:"classic-narrow",index:0,narrow:true},{tag:"orbit-normal",index:1,narrow:false},{tag:"orbit-narrow",index:1,narrow:true}];return ["rose-pine","lupine","white"].reduce((rows,p)=>rows.concat(layouts.map(row=>Object.assign({},row,{palette:p,tag:p+"-"+row.tag}))),[])}
 function test_light_overlays(data){
  failOnWarning(/.*/);width=data.narrow?300:460;height=data.narrow?540:700
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/"+data.palette+".json"),false);xhr.send();Tor.ThemeColors.palette=JSON.parse(xhr.responseText)
  var preset=Builtins.entries[data.index]
  panel.appearance=preset.appearance;panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true})
  panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  wait(100)
  for(var item of [{open:"openOptions",name:"tor-options"},{open:"openShare",name:"file-share-dialog"},{open:"openChat",name:"chat-dialog"},{open:"openHost",name:"host-dialog"}]){
   panel[item.open]();var dialog=findChild(panel,item.name);tryCompare(dialog,"opened",true)
   verify(dialog.width<=width-24,item.name+" width");verify(dialog.height<=height-24,item.name+" height")
   waitForRendering(panel)
   grabImage(test).save("/tmp/tor-light-"+data.tag+"-"+item.name+".png")
   dialog.close();tryCompare(dialog,"visible",false)
  }
  panel.closePresentation()
 }
}
