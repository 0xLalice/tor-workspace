import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ColorRoles.js" as Roles
import "../../ui/theme/ServiceStatus.js" as ServiceStatus
TestCase {
 name:"DesignPalettes";when:windowShown
 Tor.OnionEmblem {id:header;appearance:8;accent:Tor.ThemeColors.color("uiAccent");reducedMotion:true}
 Tor.OnionEmblem {id:tray;lightRole:"trayLight";reducedMotion:true}
 Tor.OverlayIconButton {id:stop;kind:"stop";ink:ServiceStatus.color(Qt.color(Tor.ThemeColors.color("background")),"error")}

 function cleanup(){Tor.ThemeDesign.design="original";Tor.ThemeColors.palette=Roles.jade;Tor.ThemeColors.overrides={}}
 function test_palettes(){
  var xhr=new XMLHttpRequest();xhr.open("GET",Qt.resolvedUrl("../../build/palette-fixtures.json"),false);xhr.send()
  var palettes=xhr.status===200?JSON.parse(xhr.responseText):[Roles.jade]
  for(var palette of palettes)for(var design of ["original","meridian"]){
   Tor.ThemeColors.palette=palette;Tor.ThemeDesign.design=design
   var surface=Tor.ThemeColors.color("background")
   compare(String(stop.contentItem.drawingInk),String(stop.ink),palette.themeId+" destructive icon must retain semantic color")
   for(var state of ["ready","paused","error"]){
    var color=ServiceStatus.color(Qt.color(surface),state)
    verify(Tor.ThemeColors.contrast(color,surface)>=4.5,palette.themeId+" "+design+" "+state+" service status contrast")
   }
   var roles=Tor.ThemeColors.treatment.roles||{}
   var expected=roles.logoLight!==undefined?header.tint:roles.uiAccent!==undefined?Tor.ThemeColors.treatmentValue(roles.uiAccent):Tor.ThemeColors.treatmentValue(Tor.ThemeColors.chrome.trayLight)
   compare(String(tray.tint),String(Qt.color(expected)),palette.themeId+" "+design+" tray follows design lighting")
   compare(String(Qt.color(Tor.ThemeColors.color("trayLight"))),String(tray.tint),"Workspace underline matches tray")
   tray.circuitReady=true;verify(tray.lit)
   tray.circuitReady=false;verify(!tray.lit);verify(!findChild(tray,"onion-light").visible)
  }
  for(var palette of palettes){
   Tor.ThemeColors.palette=palette;Tor.ThemeDesign.design="original"
   var keys=["encryptionKey1","encryptionKey2","encryptionKey3"].map(role=>String(Tor.ThemeColors.color(role)))
   for(var key of keys)verify(Tor.ThemeColors.contrast(key,Tor.ThemeColors.color("background"))>=4.5,palette.themeId+" encryption contrast")
   verify(keys[0]!==keys[1]&&keys[0]!==keys[2]&&keys[1]!==keys[2],palette.themeId+" distinguishable encryption colors")
   fuzzyCompare(Qt.color(Tor.ThemeColors.color("modalScrim")).a,136/255,.0001)
  }
  for(var palette of palettes)for(var design of ["meridian","porcelain"]){
   Tor.ThemeColors.palette=palette;Tor.ThemeDesign.design=design
   var bg=Tor.ThemeColors.color("background"),accent=Tor.ThemeColors.color("accent"),raised=Tor.ThemeColors.mixColor(bg,accent,.12)
   for(var role of ["uiText","uiMuted","uiHeading"]){
    var ink=Tor.ThemeColors.color(role)
    verify(Tor.ThemeColors.contrast(ink,bg)>=4.5,palette.themeId+" "+design+" "+role)
    verify(Tor.ThemeColors.contrast(ink,raised)>=4.5,palette.themeId+" "+design+" raised "+role)
   }
   for(var role of ["uiBorder","uiAccent","diagramInk","diagramAccent"])
    verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color(role),bg)>=3,palette.themeId+" "+design+" "+role)
   if(design==="porcelain"){
    verify(Tor.ThemeColors.luminance(bg)>.45,"Tinted Paper Clay must remain a light surface")
    verify(Tor.ThemeColors.luminance(Tor.ThemeColors.color("globeOcean"))>.7,"The paper ocean must remain pale")
   }
   var voidColor=Tor.ThemeColors.color("spaceVoid"),fade=Tor.ThemeColors.color("spaceFade")
   verify(voidColor!==fade,palette.themeId+" "+design+" distinct space colors "+voidColor+" / "+fade)
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("spaceStar"),voidColor)>=5,palette.themeId+" "+design+" stars")
   verify(Tor.ThemeColors.contrast(Tor.ThemeColors.color("spaceEffect"),voidColor)>=2.8,palette.themeId+" "+design+" nebula")
  }
 }
 function test_original_jade(){Tor.ThemeColors.palette=Roles.jade;for(var role of Object.keys(Roles.jade)){if(role!=="mode")compare(String(Tor.ThemeColors.color(role)).toLowerCase(),String(Roles.jade[role]).toLowerCase())}}
}
