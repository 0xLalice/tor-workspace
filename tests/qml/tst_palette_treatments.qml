import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/ThemeNames.js" as Names
import "../../ui/dashboard/ActionCatalog.js" as Actions

TestCase {
 id:test
 name:"PaletteTreatments";when:windowShown;visible:true;width:460;height:360
 property var cat:({})
 property var tokyo:({})
 property var latte:({})
 property var matte:({})
 property var flexoki:({})
 property var vanta:({})
 property var white:({})
 property var nord:({})
 property var gruv:({})
 property var forest:({})
 property var ristretto:({})
 property var rosePine:({})
 Tor.ActionGlyph {id:icon;kind:"host";ink:Tor.ThemeColors.color("uiText");accent:Tor.ThemeColors.color("uiAccent")}
 Tor.NoteActionGlyph {id:noteIcon;action:"onion-address";ink:icon.ink;accent:icon.accent;glow:icon.glow}
 Tor.OrbitControls {
  id:hoverControls;width:360;height:300;panelActive:true
  property bool networkEnabled:true
  actions:Actions.networkKinds
  actionModel:{var model={};Actions.entries.forEach(entry=>model[entry.kind]=Actions.resolve(entry,{networkEnabled:networkEnabled,active:{},blocked:{}}));return model}
 }
 Tor.DesignRoutes {id:conduit;visible:false}
 Tor.OnionEmblem {id:logo;width:30;height:36;reducedMotion:true;appearance:10;accent:Tor.ThemeColors.color("uiAccent")}
 Tor.OnionEmblem {id:trayLogo;width:20;height:24;lightRole:"trayLight";reducedMotion:true;accent:Tor.ThemeColors.color("uiText")}
 function initTestCase(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../fixtures/catppuccin.json"),false);xhr.send()
  cat=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/tokyo-night.json"),false);xhr.send()
  tokyo=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/catppuccin-latte.json"),false);xhr.send()
  latte=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/matte-black.json"),false);xhr.send()
  matte=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/flexoki-light.json"),false);xhr.send()
  flexoki=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/vantablack.json"),false);xhr.send()
  vanta=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/white.json"),false);xhr.send()
  white=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/nord.json"),false);xhr.send()
  nord=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/gruvbox.json"),false);xhr.send()
  gruv=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/everforest.json"),false);xhr.send()
  forest=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/ristretto.json"),false);xhr.send()
  ristretto=JSON.parse(xhr.responseText)
  xhr.open("GET",Qt.resolvedUrl("../fixtures/rose-pine.json"),false);xhr.send()
  rosePine=JSON.parse(xhr.responseText)
 }
 function test_nord_is_icy_classic_and_lavender_orbit(){
  Tor.ThemeColors.palette=nord
  for(var i=0;i<2;i++){
   Tor.ThemeDesign.design=i===0?"original":"meridian"
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[i].settings)
   compare(settings.voidLightColor,i===0?nord.cyan:nord.magenta)
   compare(settings.spaceSecondaryColor,nord.blue)
   compare(String(Tor.ThemeColors.color("trayLight")),i===0?nord.cyan:nord.magenta)
   verify(Tor.ThemeColors.color("uiText")!==nord.green)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())>idle)
   if(i===0)compare(settings.layers.particles.color,nord.foreground)
   else verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeOcean"))>=4.5)
  }
  Tor.ThemeColors.palette=Object.assign({},nord,{magenta:nord.cyan})
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).voidLightColor,nord.cyan)
 }
 function test_gruvbox_separates_amber_and_aqua(){
  Tor.ThemeColors.palette=gruv
  for(var i=0;i<2;i++){
   Tor.ThemeDesign.design=i===0?"original":"meridian"
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[i].settings)
   compare(settings.voidLightColor,i===0?gruv.orange:gruv.blue)
   compare(settings.spaceSecondaryColor,i===0?gruv.orange:gruv.blue)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiText"),Tor.ThemeColors.designSurface())>=4.5)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())>idle)
   if(i===0)compare(settings.layers.particles.color,gruv.foreground)
   else verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeOcean"))>=4.5)
  }
 }
 function test_everforest_uses_forest_mist_and_warm_fog(){
  Tor.ThemeColors.palette=forest
  for(var i=0;i<2;i++){
   Tor.ThemeDesign.design=i===0?"original":"meridian"
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[i].settings)
   compare(settings.voidLightColor,forest.light_foreground)
   compare(settings.spaceSecondaryColor,forest.blue)
   verify(String(logo.tint)!==forest.green);verify(String(logo.tint)!==forest.magenta)
   compare(trayLogo.tint,logo.tint)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())>idle)
   if(i===0)compare(settings.layers.particles.color,forest.foreground)
   else verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeOcean"))>=4.5)
  }
 }
 function test_ristretto_follows_espresso_copper_and_caramel(){
  Tor.ThemeColors.palette=ristretto
  for(var i=0;i<2;i++){
   Tor.ThemeDesign.design=i===0?"original":"meridian"
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[i].settings)
   compare(settings.voidLightColor,i===0?ristretto.orange:ristretto.yellow)
   compare(settings.spaceSecondaryColor,ristretto.brown)
   compare(trayLogo.tint,logo.tint)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())>idle)
   if(i===0)compare(settings.layers.particles.color,ristretto.foreground)
   else verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeOcean"))>=4.5)
  }
 }
 function test_rose_pine_ink_hover_routes_and_raised_overlays(){
  Tor.ThemeColors.palette=rosePine
  for(var i=0;i<2;i++){
   Tor.ThemeDesign.design=i===0?"original":"meridian"
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[i].settings)
   var surface=Tor.ThemeColors.color("background"),popup=Tor.ThemeColors.color("popupSurface")
   verify(Tor.ThemeColors.luminance(surface)>.7)
   verify(surface!==popup);verify(Tor.ThemeColors.treatment.overlayOutline)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiText"),popup)>=4.5)
   verify(Tor.ThemeColors.contrast(settings.voidStarColor,surface)>=5)
   compare(trayLogo.tint,logo.tint)
   logo.circuitReady=false;var idleLogo=String(logo.outlineTint)
   logo.circuitReady=true;verify(String(logo.outlineTint)!==idleLogo,"Active logo color must differ from off state");verify(logo.lit)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,surface)
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,surface)>idle)
   if(i===0){
    verify(Tor.ThemeColors.treatment.coverageVoid)
    for(var entry of settings.layers.particles.colorMix)verify(Tor.ThemeColors.contrast(entry.color,surface)>=4.5)
    verify(Tor.ThemeColors.contrast(settings.layers.tunnel.color,surface)>=4.5)
   } else {
    verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeOcean"))>=4.5)
    verify(Tor.ThemeColors.treatment.circuitStrokeScale>1)
   }
  }
 }
 function init(){test.forceActiveFocus();mouseMove(test,450,350)}
 function focusByKeyboard(button){
  test.forceActiveFocus()
  for(var i=0;i<40&&!button.activeFocus;i++)keyClick(Qt.Key_Tab)
  verify(button.activeFocus);verify(button.visualFocus)
 }
 function cleanup(){test.forceActiveFocus();mouseMove(test,450,350);icon.glow=0;logo.circuitReady=false;trayLogo.circuitReady=false;hoverControls.networkEnabled=true;Tor.ThemeColors.palette=Roles.jade;Tor.ThemeColors.overrides={};Tor.ThemeDesign.design="original"}
 function test_shared_icon_hover_and_keyboard_light_without_disc_data(){
  return [
   {tag:"osaka",palette:Object.assign({},Roles.jade,{themeId:"osaka-jade"})},
   {tag:"catppuccin",palette:cat},
   {tag:"tokyo",palette:tokyo},
   {tag:"latte",palette:latte},
   {tag:"unreviewed",palette:matte},
   {tag:"light-ink",palette:flexoki},
   {tag:"custom",palette:Object.assign({},cat,{themeId:"custom"})}
  ]
 }
 function test_shared_icon_hover_and_keyboard_light_without_disc(data){
  Tor.ThemeColors.palette=data.palette
  for(var design of ["original","meridian"]){
   test.forceActiveFocus()
   Tor.ThemeDesign.design=design
   icon.glow=0;compare(icon.drawingInk,icon.ink);compare(icon.drawingAccent,icon.ink);compare(noteIcon.drawingInk,noteIcon.ink);compare(noteIcon.drawingAccent,noteIcon.ink)
   icon.glow=1;compare(icon.drawingInk,icon.accent);compare(icon.drawingAccent,icon.accent);compare(noteIcon.drawingInk,noteIcon.accent);compare(noteIcon.drawingAccent,noteIcon.accent)
   var button=findChild(hoverControls,"orbit-browser"),glyph=button.contentItem.children[0]
   mouseMove(button,button.width/2,button.height/2)
   tryCompare(button,"hovered",true)
   compare(glyph.drawingInk,hoverControls.accent);compare(button.background.children.length,0)
   mouseMove(hoverControls,350,290)
   focusByKeyboard(button)
   compare(glyph.drawingInk,hoverControls.accent)
   hoverControls.networkEnabled=false
   compare(glyph.glow,0);verify(button.opacity<.4)
   hoverControls.networkEnabled=true
  }
 }
 function test_exact_scope_and_reviewed_names(){
  for(var id of ["osaka-jade","custom"])
   for(var design of ["original","meridian","porcelain"]){
    Tor.ThemeColors.palette=Object.assign({},cat,{themeId:id});Tor.ThemeDesign.design=design
    compare(JSON.stringify(Tor.ThemeColors.treatment),"{}")
    compare(conduit.routeHeight,.18)
   }
  Tor.ThemeColors.palette=cat
  compare(Names.entries(Builtins.entries,"catppuccin").map(t=>t.name).join("|"),"Catppuccin Frost|Mocha Bloom")
 }
 function test_vantablack_actions_brighten_on_hover_and_focus(){
  Tor.ThemeColors.palette=vanta
  for(var design of ["original","meridian"]){
   test.forceActiveFocus()
   Tor.ThemeDesign.design=design
   var text=String(Tor.ThemeColors.color("uiText"))
   icon.glow=0
   compare(String(icon.drawingInk),vanta.accent);compare(noteIcon.drawingInk,icon.drawingInk)
   var idle=Tor.ThemeColors.luminance(icon.drawingInk)
   verify(Tor.ThemeColors.contrast(icon.drawingInk,Tor.ThemeColors.designSurface())>=3)
   icon.glow=1
   compare(String(icon.drawingInk),vanta.foreground);compare(noteIcon.drawingInk,icon.drawingInk)
   verify(Tor.ThemeColors.luminance(icon.drawingInk)>idle*2)
   compare(String(Tor.ThemeColors.color("uiText")),text)
   var button=findChild(hoverControls,"orbit-browser"),glyph=button.contentItem.children[0]
   mouseMove(button,button.width/2,button.height/2);tryCompare(button,"hovered",true)
   compare(String(glyph.drawingInk),vanta.foreground)
   mouseMove(hoverControls,350,290);focusByKeyboard(button)
   compare(String(glyph.drawingInk),vanta.foreground)
   hoverControls.networkEnabled=false
   compare(glyph.glow,0);verify(button.opacity<.4);compare(glyph.drawingInk,glyph.ink)
   hoverControls.networkEnabled=true
   // The mapping follows the desktop palette, rather than fixed greys.
   Tor.ThemeColors.palette=Object.assign({},vanta,{accent:vanta.cyan,foreground:vanta.light_foreground})
   icon.glow=0;compare(String(icon.drawingInk),vanta.cyan)
   icon.glow=1;compare(String(icon.drawingInk),vanta.light_foreground)
   Tor.ThemeColors.palette=vanta
  }
 }
 function test_white_preserves_globe_polarity_and_dark_visible_routes(){
  Tor.ThemeColors.palette=white
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   var settings=Tor.ThemeColors.resolveData(Builtins.entries[design==="original"?0:1].settings)
   compare(settings.voidColor,white.background)
   compare(settings.voidLightColor,white.accent)
   compare(settings.spaceSecondaryColor,white.blue)
   icon.glow=0;var idle=Tor.ThemeColors.contrast(icon.drawingInk,white.background)
   icon.glow=1;verify(Tor.ThemeColors.contrast(icon.drawingInk,white.background)>idle)
   if(design==="original"){
    var globe=settings.designColors["8"]
    verify(Tor.ThemeColors.luminance(globe.land)>Tor.ThemeColors.luminance(globe.ocean))
    verify(Tor.ThemeColors.luminance(globe.ocean)>Tor.ThemeColors.luminance(white.blue))
    verify(Tor.ThemeColors.luminance(globe.ocean)<Tor.ThemeColors.luminance(white.accent))
    for(var entry of settings.layers.particles.colorMix)
     verify(Tor.ThemeColors.contrast(entry.color,white.background)>=4.5)
    verify(Tor.ThemeColors.contrast(settings.layers.tunnel.color,white.background)>=7)
   }else{
    verify(Tor.ThemeColors.contrast(settings.circuitPrimary,white.background)>=7)
    verify(Tor.ThemeColors.luminance(Tor.ThemeColors.color("globeOcean"))>.15)
   }
  }
 }
 function test_white_hover_and_logo_states_have_clear_contrast(){
  Tor.ThemeColors.palette=white
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   icon.glow=0
   compare(String(icon.drawingInk),white.muted)
   var normalWidth=icon.drawingWidth
   icon.glow=1
   compare(String(icon.drawingInk),white.foreground)
   verify(icon.drawingWidth>normalWidth*1.4)
   verify(noteIcon.drawingWidth>1.15*1.4)
   var button=findChild(hoverControls,"orbit-browser"),glyph=button.contentItem.children[0]
   mouseMove(button,button.width/2,button.height/2);tryCompare(button,"hovered",true)
   compare(String(glyph.drawingInk),white.foreground);verify(glyph.drawingWidth>1.2*1.4)
   mouseMove(hoverControls,350,290);focusByKeyboard(button)
   compare(String(glyph.drawingInk),white.foreground)
   hoverControls.networkEnabled=false
   compare(glyph.glow,0);compare(glyph.drawingWidth,1.2)
   hoverControls.networkEnabled=true
   for(var emblem of [logo,trayLogo]){
    emblem.circuitReady=false
    compare(String(emblem.outlineTint),white.muted)
    var idleWidth=emblem.outlineWidth
    verify(!findChild(emblem,"onion-light").visible)
    emblem.circuitReady=true
    compare(String(emblem.outlineTint),white.foreground)
    verify(emblem.outlineWidth>idleWidth)
    compare(findChild(emblem,"onion-outline").opacity,1)
    emblem.circuitReady=false
   }
  }
 }
 function test_latte_orbit_uses_slate_ink_and_palette_relative_mauve(){
  Tor.ThemeColors.palette=latte;Tor.ThemeDesign.design="meridian"
  var accent=Tor.ThemeColors.mixColor(latte.magenta,latte.foreground,.60)
  for(var role of ["foreground","uiText","diagramInk"])
   compare(String(Tor.ThemeColors.color(role)),latte.foreground)
  compare(String(Tor.ThemeColors.color("uiAccent")),accent)
  verify(Tor.ThemeColors.contrast(accent,Tor.ThemeColors.designSurface())>=3)
  verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiSelectionText"),accent)>=4.5)
  Tor.ThemeColors.palette=Object.assign({},latte,{green:"#010203",bright_green:"#020304"})
  compare(String(Tor.ThemeColors.color("uiText")),latte.foreground)
  compare(String(Tor.ThemeColors.color("uiAccent")),accent)
  Tor.ThemeColors.palette=Object.assign({},latte,{magenta:latte.blue})
  compare(String(Tor.ThemeColors.color("uiAccent")),Tor.ThemeColors.mixColor(latte.blue,latte.foreground,.60))
  Tor.ThemeDesign.design="original"
  compare(JSON.stringify(Tor.ThemeColors.treatment),"{}")
 }
 function test_matte_orbit_separates_charcoal_globe_and_orange_route(){
  Tor.ThemeColors.palette=matte;Tor.ThemeDesign.design="meridian"
  var settings=Tor.ThemeColors.resolveData(Builtins.entries[1].settings)
  compare(String(Tor.ThemeColors.color("uiText")),matte.foreground)
  compare(String(Tor.ThemeColors.color("uiAccent")),matte.accent)
  var land=Qt.color(Tor.ThemeColors.color("globeLand"))
  compare(land.r,land.g);compare(land.g,land.b)
  compare(settings.circuitPrimary,matte.accent);compare(settings.circuitSecondary,matte.bright_cyan)
  compare(settings.designColors["10"].atmosphere,matte.light_foreground)
  verify(Tor.ThemeColors.contrast(settings.circuitPrimary,land)>=4.5)
  verify(Tor.ThemeColors.contrast(settings.circuitSecondary,Tor.ThemeColors.color("globeBorder"))>=3)
  Tor.ThemeColors.palette=Object.assign({},matte,{green:"#010203",bright_green:"#020304",yellow:"#030405",bright_yellow:"#040506"})
  compare(String(Tor.ThemeColors.color("uiText")),matte.foreground)
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).circuitPrimary,matte.accent)
  Tor.ThemeColors.palette=Object.assign({},matte,{accent:matte.red})
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).circuitPrimary,matte.red)
  compare(String(Tor.ThemeColors.color("globeLand")),String(land))
 }
 function test_matte_classic_uses_orange_and_neutral_effects(){
  Tor.ThemeColors.palette=matte;Tor.ThemeDesign.design="original"
  var settings=Tor.ThemeColors.resolveData(Builtins.entries[0].settings)
  compare(settings.voidLightColor,matte.accent)
  compare(settings.markerColor,matte.bright_cyan)
  compare(settings.designColors["8"].skyColor,matte.foreground)
  for(var layer of ["tunnel","particles","ripples"]){
   compare(settings.layers[layer].color,matte.accent)
   compare(settings.layers[layer].colorMix[0].color,matte.accent)
   compare(settings.layers[layer].colorMix[1].color,matte.bright_cyan)
  }
  compare(settings.layers.tunnel.highlightColor,matte.bright_cyan)
  Tor.ThemeColors.palette=Object.assign({},matte,{red:"#010203",bright_red:"#020304",yellow:"#030405",bright_yellow:"#040506",magenta:"#050607"})
  var updated=Tor.ThemeColors.resolveData(Builtins.entries[0].settings)
  compare(updated.voidLightColor,settings.voidLightColor)
  compare(updated.markerColor,settings.markerColor)
  compare(updated.designColors["8"].skyColor,settings.designColors["8"].skyColor)
  for(var layer of ["tunnel","particles","ripples"])
   compare(JSON.stringify(updated.layers[layer]),JSON.stringify(settings.layers[layer]))
 }
 function test_flexoki_uses_neutral_ink_and_readable_light_surface_routes(){
  Tor.ThemeColors.palette=flexoki
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   compare(String(Tor.ThemeColors.color("uiText")),flexoki.foreground)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiText"),Tor.ThemeColors.designSurface())>=4.5)
   var index=design==="original"?0:1,settings=Tor.ThemeColors.resolveData(Builtins.entries[index].settings)
   if(design==="original"){
    compare(settings.layers.tunnel.color,flexoki.blue)
    verify(settings.layers.tunnel.width>Builtins.entries[0].settings.layers.tunnel.width)
    verify(settings.layers.particles.width>Builtins.entries[0].settings.layers.particles.width)
    compare(settings.layers.particles.colorMix[0].color,flexoki.foreground)
    compare(settings.layers.particles.colorMix[1].color,flexoki.blue)
    for(var entry of settings.layers.particles.colorMix)
     verify(Tor.ThemeColors.contrast(entry.color,flexoki.background)>=4.5)
    compare(settings.designColors["8"].land,flexoki.blue)
   }else{
    compare(settings.circuitPrimary,flexoki.foreground)
    compare(settings.circuitSecondary,flexoki.blue)
    // The renderer's main rail uses 56% opacity: check its composited color.
    var rail=Tor.ThemeColors.mixColor(flexoki.background,settings.circuitPrimary,.56)
    verify(Tor.ThemeColors.contrast(rail,flexoki.background)>=3)
   }
   compare(settings.voidLightColor,flexoki.blue)
   compare(settings.spaceSecondaryColor,flexoki.magenta)
   Tor.ThemeColors.palette=Object.assign({},flexoki,{green:"#010203",bright_green:"#020304"})
   compare(String(Tor.ThemeColors.color("uiText")),flexoki.foreground)
   var updated=Tor.ThemeColors.resolveData(Builtins.entries[index].settings)
   compare(updated.mapColor,settings.mapColor)
   if(design==="original")compare(updated.layers.particles.color,settings.layers.particles.color)
   else compare(updated.circuitPrimary,settings.circuitPrimary)
   Tor.ThemeColors.palette=flexoki
  }
 }
 function test_tokyo_night_follows_blue_and_sunset_palette(){
  Tor.ThemeColors.palette=tokyo
  compare(Names.entries(Builtins.entries,"tokyo-night").map(t=>t.name).join("|"),"Tokyo Dusk|Night Ember")
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   compare(icon.drawingAccent,icon.ink)
   compare(String(Tor.ThemeColors.color("uiAccent")),design==="original"?tokyo.blue:tokyo.red)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiText"),Tor.ThemeColors.color("background"))>=4.5)
  }
  var resolved=Tor.ThemeColors.resolveData(Builtins.entries[1].settings)
  compare(resolved.circuitPrimary,Tor.ThemeColors.mixColor(tokyo.red,tokyo.bright_foreground,.85));compare(resolved.circuitSecondary,tokyo.orange)
  verify(Tor.ThemeColors.contrast(resolved.circuitPrimary,Tor.ThemeColors.color("globeLand"))>=4.5)
  verify(Tor.ThemeColors.contrast(resolved.circuitPrimary,Tor.ThemeColors.color("globeBorder"))>=3)
  var ink=String(Tor.ThemeColors.color("uiText"))
  Tor.ThemeColors.palette=Object.assign({},tokyo,{yellow:"#010203",green:"#020304",bright_green:"#030405"})
  compare(String(Tor.ThemeColors.color("uiText")),ink)
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).circuitPrimary,Tor.ThemeColors.mixColor(tokyo.red,tokyo.bright_foreground,.85))
  Tor.ThemeColors.palette=Object.assign({},tokyo,{red:tokyo.blue})
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).circuitPrimary,Tor.ThemeColors.mixColor(tokyo.blue,tokyo.bright_foreground,.85))
  Tor.ThemeDesign.design="porcelain"
  compare(JSON.stringify(Tor.ThemeColors.treatment),"{}")
 }
 function test_live_switch_restores_osaka_without_mutating_presets(){
  var saved=JSON.stringify(Builtins.entries)
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design;Tor.ThemeColors.palette=Object.assign({},Roles.jade,{themeId:"osaka-jade"})
   var before=JSON.stringify(Tor.ThemeColors.resolveData(Builtins.entries[design==="original"?0:1].settings))
   var ink=String(Tor.ThemeColors.color("uiText"))
   Tor.ThemeColors.palette=cat
   verify(String(Tor.ThemeColors.color("uiText"))!==ink)
   Tor.ThemeColors.palette=Object.assign({},Roles.jade,{themeId:"osaka-jade"})
   compare(String(Tor.ThemeColors.color("uiText")),ink)
   compare(JSON.stringify(Tor.ThemeColors.resolveData(Builtins.entries[design==="original"?0:1].settings)),before)
  }
  compare(JSON.stringify(Builtins.entries),saved)
 }
 function test_distinct_palette_relative_treatments(){
  Tor.ThemeColors.palette=cat;Tor.ThemeDesign.design="original"
  compare(String(Tor.ThemeColors.color("uiAccent")),cat.blue)
  Tor.ThemeDesign.design="meridian"
  compare(conduit.routeHeight,.32)
  compare(String(Tor.ThemeColors.color("uiAccent")),Tor.ThemeColors.mixColor(cat.magenta,cat.foreground,.30))
  compare(String(Tor.ThemeColors.color("uiText")),Tor.ThemeColors.mixColor(cat.foreground,cat.magenta,.10))
  var settings=Tor.ThemeColors.resolveData(Builtins.entries[1].settings)
  compare(settings.circuitPrimary,Tor.ThemeColors.mixColor(cat.magenta,cat.foreground,.30));compare(settings.circuitSecondary,cat.foreground)
  compare(settings.voidLightColor,settings.circuitPrimary)
  verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeLand"))>=4.5)
  verify(Tor.ThemeColors.contrast(settings.circuitPrimary,Tor.ThemeColors.color("globeBorder"))>=3)
  var ink=String(Tor.ThemeColors.color("uiText"))
  Tor.ThemeColors.palette=Object.assign({},cat,{green:"#010203",bright_green:"#020304"})
  compare(String(Tor.ThemeColors.color("uiText")),ink)
  Tor.ThemeColors.palette=Object.assign({},cat,{magenta:cat.yellow})
  compare(String(Tor.ThemeColors.color("uiAccent")),Tor.ThemeColors.mixColor(cat.yellow,cat.foreground,.30))
  compare(Tor.ThemeColors.resolveData(Builtins.entries[1].settings).circuitPrimary,Tor.ThemeColors.mixColor(cat.yellow,cat.foreground,.30))
 }
 function test_icons_are_monochrome_in_every_palette(){
  for(var id of ["osaka-jade","catppuccin","catppuccin-latte"])
   for(var design of ["original","meridian"]){
    Tor.ThemeColors.palette=Object.assign({},cat,{themeId:id});Tor.ThemeDesign.design=design
    compare(icon.drawingAccent,icon.ink)
   }
 }
 function test_pastel_lighting_keeps_off_state_dark(){
  Tor.ThemeColors.palette=cat;Tor.ThemeDesign.design="meridian"
  var settings=Tor.ThemeColors.resolveData(Builtins.entries[1].settings)
  compare(settings.designColors["10"].atmosphere,Tor.ThemeColors.mixColor(cat.magenta,cat.foreground,.30))
  compare(settings.designColors["10"].skyColor,cat.foreground)
  compare(String(logo.tint),Tor.ThemeColors.mixColor(cat.magenta,cat.foreground,.25))
  logo.circuitReady=true
  verify(logo.lit);verify(findChild(logo,"onion-light").visible)
  logo.circuitReady=false
  verify(!logo.lit);verify(!findChild(logo,"onion-light").visible)
  Tor.ThemeColors.palette=Object.assign({},cat,{themeId:"osaka-jade"})
  compare(logo.tint,Qt.lighter(logo.accent,1.35))
  Tor.ThemeColors.palette=cat;Tor.ThemeDesign.design="original"
  compare(String(logo.tint),Tor.ThemeColors.mixColor(cat.blue,cat.foreground,.35))
 }
 function test_tray_follows_catppuccin_design_and_preserves_osaka(){
  Tor.ThemeColors.palette=cat
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   compare(trayLogo.tint,logo.tint)
  }
  Tor.ThemeColors.palette=Object.assign({},Roles.jade,{themeId:"osaka-jade"})
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   compare(String(trayLogo.tint),Roles.jade.green)
   compare(String(Tor.ThemeColors.color("trayLight")),Roles.jade.green)
  }
 }
 function test_text_on_panel_and_raised_surfaces(){
  Tor.ThemeColors.palette=cat
  for(var design of ["original","meridian"]){
   Tor.ThemeDesign.design=design
   var bg=Tor.ThemeColors.color("background"),raised=Tor.ThemeColors.mixColor(bg,Tor.ThemeColors.color("uiAccent"),.12)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("uiSelectionText"),Tor.ThemeColors.color("accent"))>=4.5)
   for(var role of ["uiText","uiMuted","uiHeading"]){
    verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color(role),bg)>=4.5)
    verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color(role),raised)>=4.5)
   }
  }
 }
}
