import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "LegacyPorcelain.js" as Legacy
TestCase {
 id:test;name:"RoseEffects";when:windowShown;visible:true;width:460;height:690
 property var route:[{country:"TH",longitude:101,latitude:15},{country:"LU",longitude:6,latitude:50},{country:"DE",longitude:10,latitude:51},{country:"JP",longitude:138,latitude:36}]
 property var preset:Legacy.preset
 Tor.TorDashboard {id:panel;anchors.fill:parent;anchors.margins:20;active:true;torRunning:true;state:"ready";installationReady:true;route:test.route;circuitId:"rose"}
 function init(){
  failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true
  panel.visible=true;panel.active=true;panel.route=route;panel.circuitId="rose"
  panel.globe.externalCamera=true;panel.globe.longitude=-48;panel.globe.latitude=18;panel.globe.viewRoll=-9;panel.globe.automaticRotation=false
  panel.appearance=preset.appearance;panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true})
  panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
 }
 function test_atmosphere_data(){return [{tag:"jade",light:false},{tag:"light",light:true}]}
 function test_atmosphere(data){
  Tor.ThemeColors.palette=data.light?Object.assign({},Roles.jade,{background:"#eff1f5",foreground:"#4c4f69",accent:"#1e66f5",cyan:"#179299",orange:"#fe640b",magenta:"#8839ef",bright_yellow:"#df8e1d",themeId:"catppuccin-latte"}):Roles.jade
  var settings=Tor.ThemeColors.resolveData(preset.settings)
  panel.effectSettings=Object.assign({},settings,{roseAtmosphere:0,voidStars:false,voidDust:false,voidNebula:false})
  tryCompare(panel.globe,"mapReady",true);panel.globe.time=37;waitForRendering(panel);wait(800)
  var circuits=findChild(panel.globe,"design-route");compare(circuits.materialKind,8)
  circuits.clock=3.5;circuits.dirty=true;waitForRendering(panel);var bare=grabImage(test)
  panel.effectSettings=Object.assign({},panel.effectSettings,{roseAtmosphere:settings.roseAtmosphere});waitForRendering(panel)
  var halo=grabImage(test),changed=0
  for(var y=100;y<470;y+=2)for(var x=0;x<440;x+=2)if(String(bare.pixel(x,y))!==String(halo.pixel(x,y)))changed++
  verify(changed>1000,"The rose/ochre atmospheric veil must be visibly rendered")
  panel.globe.time=70;waitForRendering(panel);verify(!halo.equals(grabImage(test)),"Atmospheric light must drift gently")
 }
 function test_native_lifecycle(){
  Tor.ThemeColors.palette=Roles.jade;panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:false})
  panel.route=[route[0],route[1],route[2],{country:"FR",longitude:2,latitude:47}];panel.circuitId="replacement"
  var circuits=findChild(panel.globe,"design-route")
  tryCompare(circuits,"retiring",true);tryCompare(circuits,"building",true);tryCompare(circuits,"building",false,4000)
  panel.visible=false;wait(100);var clock=circuits.clock,paints=circuits.paintCount;wait(150);compare(circuits.clock,clock);compare(circuits.paintCount,paints)
  panel.visible=true;panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true});wait(100);clock=circuits.clock;wait(150);compare(circuits.clock,clock)
 }
}
