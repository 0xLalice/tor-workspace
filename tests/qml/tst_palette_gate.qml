import QtQuick
import QtTest
import "../../ui/theme" as Theme

TestCase {
 name:"PaletteGate";when:windowShown
 Theme.PaletteGate {id:gate;onPaletteReady:value=>test.received.push(value)}
 id:test
 property var received:[]
 property var old:({themeId:"old",background:"#111111",foreground:"#eeeeee",accent:"#aabbcc"})
 property var next:({themeId:"next",background:"#eeeeee",foreground:"#111111",accent:"#112233"})
 function init(){gate.initialized=false;gate.pending=null;gate.appliedShell=null;received=[]}
 function start(){gate.shellApplied(old);gate.receive(old);tryCompare(gate,"initialized",true);compare(received.length,1)}
 function test_staged_files_wait_for_shell(){
  start();gate.receive(next);wait(30)
  compare(received.length,1);compare(gate.pending,next)
  gate.shellApplied(next);tryVerify(()=>received.length===2)
  compare(received[1],next);compare(gate.pending,null)
 }
 function test_shell_before_files(){
  start();gate.shellApplied(next);wait(20);compare(received.length,1)
  gate.receive(next);tryVerify(()=>received.length===2);compare(received[1],next)
 }
 function test_rapid_switch_never_releases_superseded_palette(){
  start();var third={themeId:"third",background:"#222222",foreground:"#ffffff",accent:"#334455"}
  gate.receive(next);gate.receive(third);gate.shellApplied(next);wait(30)
  compare(received.length,1)
  gate.shellApplied(third);tryVerify(()=>received.length===2);compare(received[1],third)
 }
 function test_startup_without_shell_notification(){
  gate.receive(old);tryCompare(gate,"initialized",true);compare(received[0],old)
 }
}
