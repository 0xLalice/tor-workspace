import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "LegacyPorcelain.js" as Legacy
import "../../ui/theme/ColorRoles.js" as Roles
TestCase {
 id:test;name:"DesignDetail";when:windowShown;visible:true;width:460;height:690
 property var lightPalette:({})
 property var route:[{country:"TH",longitude:101,latitude:15},{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:47},{country:"US",fingerprint:"exit",longitude:-77,latitude:39}]
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready";installationReady:true;route:test.route;circuitId:"a"}
 Component {id:spaceComponent;Tor.VoidBackground {width:460;height:690;active:false}}
 function changedPixels(a,b,stride){stride=stride||4;var count=0;for(var y=4;y<height;y+=stride)for(var x=4;x<width;x+=stride)if(String(a.pixel(x,y))!==String(b.pixel(x,y)))count++;return count}
 function initTestCase(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/catppuccin-latte.json"),false);xhr.send()
  lightPalette=JSON.parse(xhr.responseText)
 }
 function init(){failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true;panel.visible=true;panel.active=true;panel.route=test.route;panel.circuitId="a"}
 function cleanup(){panel.active=false;panel.closePresentation();Tor.ThemeDesign.design="original";Tor.ThemeColors.palette=Roles.jade}
 function test_detail_data(){return [{tag:"meridian-dark",index:1,light:false},{tag:"meridian-light",index:1,light:true},{tag:"porcelain-dark",index:2,light:false},{tag:"porcelain-light",index:2,light:true}]}
 function test_detail(data){
  Tor.ThemeColors.palette=data.light?lightPalette:Roles.jade
  // Consecutive rows can reuse the same interface object after cleanup reset
  // the singleton; select the intended design before resolving its colors.
  Tor.ThemeDesign.design=data.index===1?"meridian":"porcelain"
  var preset=(data.index===2?Legacy.preset:Builtins.entries[data.index]);panel.appearance=preset.appearance;panel.interfaceSettings=preset.interface;panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  // Exercise a real circuit replacement: selecting a design no longer reveals it.
  panel.circuitId="detail-"+data.tag
  var renderer=findChild(panel.globe,"design-route"),sphere=findChild(panel.globe,"globe-sphere")
  var space=findChild(panel,"space-background")
  compare(space.spaceStyle,data.index);verify(String(space.shader).endsWith("space-effects.frag.qsb"))
  compare(space.globeRadius,panel.globe.screenRadius)
  verify(panel.effectSettings.voidColor!==panel.effectSettings.voidFade)
  verify(Tor.ThemeColors.contrast(panel.effectSettings.voidStarColor,panel.effectSettings.voidColor)>=5)
  verify(panel.effectSettings.voidStars);verify(panel.effectSettings.voidDust);verify(panel.effectSettings.voidNebula);verify(panel.effectSettings.mapFill)
  tryCompare(renderer,"nativeReady",true);tryCompare(renderer,"building",true);verify(sphere.surfaceOptions.y<1)
  tryCompare(renderer,"building",false,3500);compare(sphere.surfaceOptions.y,1)
  waitForRendering(panel);grabImage(test).save("/tmp/tor-detail-"+data.tag+".png")
  var time=space.animationTime;wait(80);verify(space.animationTime>time)
  panel.visible=false;wait(80);time=space.animationTime;wait(100);compare(space.animationTime,time);panel.visible=true
  panel.route=[test.route[0],test.route[1],test.route[2],{country:"JP",fingerprint:"replacement",longitude:138,latitude:36}];panel.circuitId="b"
  tryCompare(renderer,"retiring",true);verify(sphere.departingCountries.w!==sphere.mappedCountries.w);verify(sphere.surfaceOptions.z<1)
  panel.interfaceSettings=Object.assign({},preset.interface,{reducedMotion:true});tryCompare(renderer,"retiring",false);compare(sphere.surfaceOptions.y,1);compare(sphere.surfaceOptions.z,1)
  wait(80);time=space.animationTime;wait(100);compare(space.animationTime,time)
  panel.active=false;wait(80);var clock=renderer.clock,paints=renderer.paintCount,time=panel.globe.time;wait(150);compare(renderer.clock,clock);compare(renderer.paintCount,paints);compare(panel.globe.time,time)
 }
 function test_original_renderer(){
  var preset=Builtins.entries[0];panel.appearance=preset.appearance;panel.interfaceSettings=preset.interface;panel.effectSettings=Tor.ThemeColors.resolveData(preset.settings)
  var space=findChild(panel,"space-background");compare(space.spaceStyle,0);verify(String(space.shader).endsWith("/void-effects.frag.qsb"))
 }
 function test_space_layers_data(){return test_detail_data()}
 function test_space_layers(data){
  panel.visible=false;Tor.ThemeDesign.design=data.index===1?"meridian":"porcelain"
  Tor.ThemeColors.palette=data.light?lightPalette:Roles.jade
  var preset=Tor.ThemeColors.resolveData((data.index===2?Legacy.preset:Builtins.entries[data.index]).settings)
  var space=createTemporaryObject(spaceComponent,test,{settings:Object.assign({},preset,{voidStars:false,voidDust:false,voidNebula:false,voidRays:false})})
  verify(space);waitForRendering(space);var empty=grabImage(space)
  space.settings=Object.assign({},preset,{voidNebula:false});waitForRendering(space);var stars=grabImage(space)
  // Subpixel pinpoints can fall between a coarse four-pixel sampling grid.
  verify(changedPixels(empty,stars,1)>30,"Star field must visibly render on this palette")
  space.settings=Object.assign({},preset,{voidStars:false,voidDust:false});waitForRendering(space);var clouds=grabImage(space)
  verify(changedPixels(empty,clouds)>1000,"Tinted nebula must visibly render on this palette")
  space.settings=preset;waitForRendering(space);grabImage(space).save("/tmp/tor-space-"+data.tag+".png")
 }
 function test_globe_occludes_space(){
  panel.visible=false;Tor.ThemeDesign.design="meridian"
  var preset=Tor.ThemeColors.resolveData(Builtins.entries[1].settings)
  var space=createTemporaryObject(spaceComponent,test,{globeRadius:135,settings:Object.assign({},preset,{voidStars:false,voidDust:false,voidNebula:false})})
  verify(space);waitForRendering(space);var empty=grabImage(space)
  space.settings=preset;waitForRendering(space);var filled=grabImage(space),inside=0,outside=0
  for(var y=4;y<690;y+=4)for(var x=4;x<460;x+=4){
   var changed=String(empty.pixel(x,y))!==String(filled.pixel(x,y)),distance=Math.hypot(x-230,y-345)
   if(distance<132&&changed)inside++;if(distance>138&&changed)outside++
  }
  compare(inside,0);verify(outside>1000)
  panel.visible=true;panel.interfaceSettings=Builtins.entries[1].interface
  panel.globe.temporaryZoom=1.5
  compare(findChild(panel,"space-background").globeRadius,panel.globe.screenRadius)
  compare(panel.globe.screenRadius,Math.min(panel.globe.width,panel.globe.height)*.42*1.5)
  panel.globe.temporaryZoom=NaN
 }
}
