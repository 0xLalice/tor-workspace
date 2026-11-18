import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/BuiltinThemes.js" as Builtins

TestCase {
 name:"PaletteTransition";when:windowShown;visible:true;width:500;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;effectSettings:Tor.ThemeColors.displayedSettings}
 Tor.TransitionRoutes {id:routes;visible:false;settings:Tor.ThemeColors.displayedSettings;oldRoute:[{longitude:0,latitude:0},{longitude:25,latitude:40}];newRoute:[{longitude:0,latitude:0},{longitude:60,latitude:10}]}
 function palette(id,bg,fg){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../../tests/fixtures/"+id+".json"),false);xhr.send()
  if(xhr.status===200)return JSON.parse(xhr.responseText)
  return Object.assign({},Roles.jade,{themeId:id,background:bg,foreground:fg})
 }
 function init(){
  Tor.ThemeColors.animationEnabled=false;Tor.ThemeDesign.design="original"
  Tor.ThemeColors.settingsSource=Builtins.entries[0].settings
  Tor.ThemeColors.palette=palette("osaka-jade","#111c18","#c1c497")
 }
 function cleanup(){Tor.ThemeColors.animationEnabled=false;Tor.ThemeColors.palette=Roles.jade}
 function test_shared_clock_retarget_hidden_and_contrast(){
  var camera=JSON.stringify(panel.globe.cameraState),route=JSON.stringify(panel.route)
  var mesh=routes.newMesh,oldMesh=routes.oldMesh,angles=routes.angles
  var start=String(Tor.ThemeColors.color("background"))
  Tor.ThemeColors.animationEnabled=true
  Tor.ThemeColors.palette=palette("nord","#2e3440","#d8dee9")
  tryCompare(Tor.ThemeColors,"transitioning",true)
  wait(950)
  // Freeze the sampled frame: the deferred retarget can otherwise observe the
  // next animation tick, correctly differing from the earlier sampled color.
  Tor.ThemeColors.transition.pause()
  var shown=String(Tor.ThemeColors.color("background"))
  verify(routes.newMesh===mesh);verify(routes.oldMesh===oldMesh);verify(routes.angles===angles)
  verify(shown!==start);verify(shown!=="#2e3440")
  Tor.ThemeColors.palette=palette("flexoki-light","#fffcf0","#100f0f")
  wait(1)
  verify(Tor.ThemeColors.fromAppearance!==null)
  compare(String(Tor.ThemeColors.fromAppearance.roles.background),shown)
  Tor.ThemeColors.transition.pause()
  for(var t of [.1,.25,.5,.75,.9]){
   Tor.ThemeColors.transitionProgress=t
   var bg=Tor.ThemeColors.color("background")
   for(var role of ["uiText","uiMuted","uiHeading"])
    verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color(role),bg)>=4.5,role+" "+t)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiAccent"),bg)>=3)
  }
  Tor.ThemeColors.transition.resume()
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  compare(Tor.ThemeColors.fromAppearance,null);compare(Tor.ThemeColors.toAppearance,null)
  compare(String(Tor.ThemeColors.color("background")).toLowerCase(),"#fffcf0")
  compare(JSON.stringify(panel.globe.cameraState),camera);compare(JSON.stringify(panel.route),route)
  verify(routes.newMesh===mesh);verify(routes.oldMesh===oldMesh);verify(routes.angles===angles)
  Tor.ThemeColors.palette=palette("nord","#2e3440","#d8dee9")
  tryCompare(Tor.ThemeColors,"transitioning",true)
  Tor.ThemeColors.animationEnabled=false
  compare(Tor.ThemeColors.transitioning,false);compare(String(Tor.ThemeColors.color("background")).toLowerCase(),"#2e3440")
  Tor.ThemeColors.palette=palette("osaka-jade","#111c18","#c1c497")
  compare(Tor.ThemeColors.transitioning,false);compare(String(Tor.ThemeColors.color("background")),"#111c18")
 }
 function test_overlay_and_shader_lifecycle(){
  panel.installationReady=false;panel.openInstallation();tryCompare(panel,"installationOpened",true)
  Tor.ThemeColors.animationEnabled=true
  Tor.ThemeColors.palette=palette("nord","#2e3440","#d8dee9")
  tryCompare(Tor.ThemeColors,"transitioning",true);wait(200)
  verify(panel.installationOpened)
  var space=findChild(panel,"space-background")
  verify(space.effectLayerCount<=2)
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  compare(space.effectLayerCount,1)
  verify(panel.installationOpened)
  panel.installationReady=true
 }
 function test_all_palette_transitions(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../../build/palette-fixtures.json"),false);xhr.send()
  var palettes=xhr.status===200?JSON.parse(xhr.responseText):[Roles.jade]
  for(var design of ["original","meridian"])for(var target of palettes){
   Tor.ThemeColors.animationEnabled=false;Tor.ThemeDesign.design=design
   Tor.ThemeColors.palette=Object.assign({},Roles.jade,{themeId:"transition-start",background:"#171d26"})
   Tor.ThemeColors.animationEnabled=true;Tor.ThemeColors.palette=target
   tryCompare(Tor.ThemeColors,"transitioning",true);Tor.ThemeColors.transition.pause()
   for(var t of [.1,.3,.5,.7,.9]){
    Tor.ThemeColors.transitionProgress=t
    for(var surface of ["background","popupSurface","tooltipSurface"])for(var role of ["uiText","uiMuted","uiHeading"])
     verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color(role),Tor.ThemeColors.color(surface))>=4.5,target.themeId+" "+design+" "+role+"/"+surface+" "+t)
   }
   Tor.ThemeColors.animationEnabled=false
   compare(Tor.ThemeColors.transitioning,false)
  }
 }
 function test_no_target_flash_before_animation(){
  var before=String(Tor.ThemeColors.color("background"))
  var settings=JSON.stringify(Tor.ThemeColors.displayedSettings)
  Tor.ThemeColors.animationEnabled=true
  Tor.ThemeColors.palette=palette("flexoki-light","#fffcf0","#100f0f")
  // Force binding evaluation before Qt.callLater starts the animation.
  compare(String(Tor.ThemeColors.color("background")),before)
  compare(JSON.stringify(Tor.ThemeColors.displayedSettings),settings)
  tryCompare(Tor.ThemeColors,"transitioning",true)
  wait(50);verify(String(Tor.ThemeColors.color("background"))!=="#fffcf0")
  tryCompare(Tor.ThemeColors,"transitioning",false,4000)
  compare(String(Tor.ThemeColors.color("background")).toLowerCase(),"#fffcf0")
  compare(Tor.ThemeColors.blendState,null)
 }
 function test_startup_palette_applies_immediately(){
  Tor.ThemeColors.paletteInitialized=false;Tor.ThemeColors.animationEnabled=true
  var next=palette("nord","#2e3440","#d8dee9")
  Tor.ThemeColors.receivePalette(next)
  compare(Tor.ThemeColors.transitioning,false)
  compare(String(Tor.ThemeColors.color("background")).toLowerCase(),"#2e3440")
  wait(20);compare(Tor.ThemeColors.transitioning,false)
 }
}
