import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/ColorRoles.js" as Roles

TestCase {
 id:test;name:"FlexokiAtmosphere";when:windowShown;visible:true;width:460;height:690
 Tor.VoidBackground {id:space;anchors.fill:parent;active:false}
 function initTestCase(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/flexoki-light.json"),false);xhr.send()
  Tor.ThemeColors.palette=JSON.parse(xhr.responseText)
 }
 function cleanupTestCase(){Tor.ThemeColors.palette=Roles.jade;Tor.ThemeDesign.design="original"}
 function capture(){waitForRendering(space);wait(40);return grabImage(space)}
 function changed(a,b,threshold){
  var count=0
  for(var y=20;y<height-20;y+=3)for(var x=20;x<width-20;x+=3){
   var p=a.pixel(x,y),q=b.pixel(x,y)
   if(Math.max(Math.abs(p.r-q.r),Math.abs(p.g-q.g),Math.abs(p.b-q.b))>threshold)count++
  }
  return count
 }
 function test_colored_clouds_on_cream_data(){return [{tag:"classic",index:0,design:"original"},{tag:"orbit",index:1,design:"meridian"}]}
 function test_colored_clouds_on_cream(data){
  Tor.ThemeDesign.design=data.design
  var settings=Tor.ThemeColors.resolveData(Builtins.entries[data.index].settings)
  space.settings=Object.assign({},settings,{voidStars:false,voidDust:false,voidNebula:false,voidRays:false})
  var bare=capture()
  space.settings=Object.assign({},space.settings,{voidNebula:settings.voidNebula,voidRays:settings.voidRays})
  var clouds=capture()
  var colored=changed(bare,clouds,.04)
  verify(colored>(data.design==="original"?1500:500),"Colored clouds must remain visible on the cream surface")
  if(data.design==="meridian")
   verify(colored<9000,"Orbit must retain a localized band, leaving most of the void untouched")
  space.settings=Object.assign({},space.settings,{spaceSecondaryColor:settings.voidLightColor})
  verify(changed(clouds,capture(),.02)>500,"The secondary hue must visibly contribute to the void")
  if(data.design==="original"){
   verify(String(space.shader).indexOf("space-effects")>=0)
   Tor.ThemeColors.palette=Object.assign({},Tor.ThemeColors.palette,{themeId:"custom"})
   verify(String(space.shader).indexOf("void-effects")>=0)
   Tor.ThemeColors.palette=Object.assign({},Tor.ThemeColors.palette,{themeId:"flexoki-light"})
  }
 }
 function test_white_smoke_is_visible_but_orbit_stays_restrained_data(){
  return test_colored_clouds_on_cream_data()
 }
 function test_white_smoke_is_visible_but_orbit_stays_restrained(data){
  var previous=Tor.ThemeColors.palette
  try {
   var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/white.json"),false);xhr.send()
   Tor.ThemeColors.palette=JSON.parse(xhr.responseText);Tor.ThemeDesign.design=data.design
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[data.index].settings)
   space.settings=Object.assign({},settings,{voidStars:false,voidDust:false,voidNebula:false,voidRays:false})
   var bare=capture()
   space.settings=Object.assign({},space.settings,{voidNebula:settings.voidNebula,voidRays:settings.voidRays})
   var visible=changed(bare,capture(),.04)
   verify(visible>500,"Smoke must visibly render on the white surface")
   if(data.design==="meridian")verify(visible<9000,"Orbit's smoke must remain localized")
  }finally{Tor.ThemeColors.palette=previous}
 }
 function test_rose_pine_clouds_and_stars_on_light_surfaces_data(){return ["rose-pine","lupine"].reduce((rows,p)=>rows.concat(test_colored_clouds_on_cream_data().map(row=>Object.assign({},row,{palette:p,tag:p+"-"+row.tag}))),[])}
 function test_rose_pine_clouds_and_stars_on_light_surfaces(data){
  var previous=Tor.ThemeColors.palette
  try {
   var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/"+data.palette+".json"),false);xhr.send()
   Tor.ThemeColors.palette=JSON.parse(xhr.responseText);Tor.ThemeDesign.design=data.design
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[data.index].settings)
   space.settings=Object.assign({},settings,{voidStars:false,voidDust:false,voidNebula:false,voidRays:false})
   var bare=capture()
   space.settings=Object.assign({},settings,{voidStars:false,voidDust:false})
   var clouds=capture(),coverage=changed(bare,clouds,.04)
   verify(coverage>500,"Colored atmosphere must be visible on the light background")
   if(data.design==="meridian")verify(coverage<9000,"Orbit haze must remain localized")
   space.settings=Object.assign({},settings,{voidDust:false})
   verify(changed(clouds,capture(),.015)>15,"Dark stars must remain visible against the light void")
  }finally{Tor.ThemeColors.palette=previous}
 }

}
