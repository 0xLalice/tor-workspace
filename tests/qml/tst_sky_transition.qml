import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/BuiltinThemes.js" as Builtins

TestCase {
 id:test;name:"SkyTransition";when:windowShown;visible:true;width:420;height:600
 Tor.VoidBackground {id:sky;anchors.fill:parent;active:false}
 function init(){
  Tor.ThemeColors.animationEnabled=false;Tor.ThemeDesign.design="original"
  Tor.ThemeColors.palette=Roles.jade;Tor.ThemeColors.settingsSource=Builtins.entries[0].settings
  sky.active=false;sky.visible=true;sky.settings=Tor.ThemeColors.displayedSettings
  sky.animationTime=36000;sky.motionTime=18000
 }
 function cleanup(){sky.active=false;Tor.ThemeColors.animationEnabled=false}
 function test_speed_change_preserves_pixels_data(){return [{tag:"legacy",design:"original"},{tag:"coverage",design:"meridian"}]}
 function test_speed_change_preserves_pixels(data){
  failOnWarning(/.*/)
  Tor.ThemeDesign.design=data.design
  sky.settings=Object.assign({},Tor.ThemeColors.displayedSettings,{voidSpeed:1.67})
  waitForRendering(sky);var before=grabImage(sky)
  sky.settings=Object.assign({},sky.settings,{voidSpeed:.09})
  waitForRendering(sky)
  verify(before.equals(grabImage(sky)),"Changing velocity must not relocate an old star/cloud field")
 }
 function test_velocity_and_stalled_frames(){
  sky.active=true;sky.settings=Object.assign({},sky.settings,{voidSpeed:.09})
  var before=sky.motionTime
  sky.advance(.02);verify(Math.abs(sky.motionTime-before-.0018)<1e-8)
  sky.settings=Object.assign({},sky.settings,{voidSpeed:1.67});before=sky.motionTime
  sky.advance(.02);verify(Math.abs(sky.motionTime-before-.0334)<1e-8)
  before=sky.motionTime;sky.advance(60)
  verify(Math.abs(sky.motionTime-before-.0835)<1e-8,"Stalled frames must not fast-forward the sky")
  sky.active=false;before=sky.motionTime;sky.advance(60);compare(sky.motionTime,before)
  sky.active=true;sky.visible=false;sky.advance(60);compare(sky.motionTime,before)
  sky.visible=true;sky.settings=Object.assign({},sky.settings,{voidAnimate:false});sky.advance(60);compare(sky.motionTime,before)
 }
 function test_design_crossfade_and_rapid_retarget(){
  var before=Tor.ThemeColors.voidWeights.slice()
  Tor.ThemeColors.animationEnabled=true;Tor.ThemeDesign.design="meridian"
  compare(JSON.stringify(Tor.ThemeColors.voidWeights),JSON.stringify(before))
  tryCompare(Tor.ThemeColors,"transitioning",true);Tor.ThemeColors.transition.pause()
  Tor.ThemeColors.transitionProgress=.4
  compare(Tor.ThemeColors.voidWeights[0],.6);compare(Tor.ThemeColors.voidWeights[2],.4)
  compare(sky.effectLayerCount,2)
  before=Tor.ThemeColors.voidWeights.slice();Tor.ThemeDesign.design="porcelain"
  wait(1);Tor.ThemeColors.transition.pause()
  compare(JSON.stringify(Tor.ThemeColors.fromAppearance.voidWeights),JSON.stringify(before))
  Tor.ThemeColors.transitionProgress=.5
  compare(sky.effectLayerCount,3)
  verify(Math.abs(Tor.ThemeColors.voidWeights.reduce((a,b)=>a+b,0)-1)<1e-8)
  Tor.ThemeColors.animationEnabled=false;compare(sky.effectLayerCount,1)
  compare(Tor.ThemeColors.transitioning,false)
 }
}
