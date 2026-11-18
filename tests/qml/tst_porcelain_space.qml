import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "LegacyPorcelain.js" as Legacy
TestCase {
 id:test;name:"PorcelainSpace";when:windowShown;visible:true;width:460;height:690
 Tor.VoidBackground {id:space;anchors.fill:parent;active:false;globeRadius:145;globeCenter:Qt.vector2d(230,345)}
 function test_layers_data(){return [{tag:"jade",light:false},{tag:"light",light:true}]}
 function test_layers(data){
  failOnWarning(/.*/);Tor.ThemeDesign.design="porcelain"
  Tor.ThemeColors.palette=data.light?Object.assign({},Roles.jade,{background:"#eff1f5",foreground:"#4c4f69",accent:"#1e66f5",cyan:"#179299",orange:"#fe640b",magenta:"#8839ef",bright_yellow:"#df8e1d",themeId:"catppuccin-latte"}):Roles.jade
  var preset=Tor.ThemeColors.resolveData(Legacy.preset.settings)
  var blank=Object.assign({},preset,{voidStars:false,voidDust:false,voidNebula:false,voidRays:false,paperGrain:0})
  space.settings=blank;space.animationTime=37;waitForRendering(space);var empty=grabImage(space)
  space.settings=Object.assign({},preset,{voidNebula:false,paperGrain:0});waitForRendering(space);var stars=grabImage(space)
  var outside=0,inside=0
  for(var y=0;y<690;y++)for(var x=0;x<460;x++){
   if(String(empty.pixel(x,y))===String(stars.pixel(x,y)))continue
   if(Math.hypot(x-230,y-345)<143)inside++;else outside++
  }
  compare(inside,0,"Stars must not appear through the clay globe")
  verify(outside>150,"Fine dust, pinpoints and glints must visibly render on light paper")
  space.settings=preset;waitForRendering(space);var first=grabImage(space)
  space.animationTime=80;waitForRendering(space);verify(!first.equals(grabImage(space)),"The quiet field must move and twinkle")
  space.settings=Object.assign({},blank,{voidNebula:true});waitForRendering(space);verify(!empty.equals(grabImage(space)),"Both-color illumination must render")
 }
}
