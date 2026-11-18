import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"Typography";when:windowShown;visible:true;width:460;height:640
 Tor.ChatDialog {id:chat;torRunning:true;reducedMotion:true}
 Tor.HostDialog {id:host;torRunning:true;reducedMotion:true;mode:"app"}
 Tor.RotatingTorNote {id:note;width:300;height:100}
 property string originalFont:Tor.ThemeDesign.fontFamily
 function cleanup(){chat.close();host.close();Tor.ThemeDesign.design="original";Tor.ThemeDesign.fontFamily=originalFont;Tor.ThemeDesign.fontSizes={}}
 Canvas {id:canvas;width:120;height:30}
 function test_canvas_resolves_font_aliases_data(){return [
  {tag:"generic",family:"Sans Serif"},{tag:"missing",family:"Tor Workspace nonexistent font"},
  {tag:"serif",family:"serif"},{tag:"monospace",family:"monospace"}
 ]}
 function test_canvas_resolves_font_aliases(data){
  failOnWarning(/.*/)
  Tor.ThemeDesign.fontFamily=data.family
  tryCompare(canvas,"available",true)
  var context=canvas.getContext("2d")
  context.font=Tor.ThemeDesign.canvasFont(12)
  verify(context.measureText("Tor Workspace").width>0)
 }
 function test_live_font_data(){return [{tag:"theme-1",design:"original"},{tag:"theme-2",design:"meridian"}]}
 function test_live_font(data){
  failOnWarning(/.*/);Tor.ThemeDesign.design=data.design
  chat.open();tryCompare(chat,"opened",true)
  for(var family of ["serif","monospace"]){
   Tor.ThemeDesign.fontFamily=family;Tor.ThemeDesign.fontSizes={12:15}
   compare(findChild(chat,"chat-status").font.family,family)
   compare(findChild(chat,"chat-status").font.pixelSize,15)
   compare(findChild(note,"cycling-tor-copy").font.family,family)
   host.open();tryCompare(host,"opened",true)
   compare(findChild(host,"host-port").font.family,family)
   compare(findChild(host,"host-port").font.pixelSize,15)
   host.close();tryCompare(host,"visible",false)
  }
 }
}
