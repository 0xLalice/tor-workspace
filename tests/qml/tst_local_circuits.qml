import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"LocalCircuits";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;interfaceSettings:({layout:3,sentenceSize:12,sentenceInterval:3000,uiScale:1,cardStyle:1})}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 SignalSpy {id:illuminate;target:panel;signalName:"illuminateExitNodes"}
 function snapshot(rows){return {available:true,count:rows.length,circuits:rows,observedAt:Date.now()/1000}}
 function test_view(){
  var note=findChild(panel,"rotating-tor-note"),action=findChild(panel,"cycling-tor-action"),copy=findChild(panel,"cycling-tor-copy"),overlay=findChild(panel,"local-circuits-overlay")
  note.showNote(false)
  compare(note.phrases.findIndex(p=>p.action==="local-circuits"),-1)
  panel.localCircuits=snapshot([]);wait(50);compare(note.phrases.findIndex(p=>p.action==="local-circuits"),-1)
  var a={fingerprint:"a",longitude:10,latitude:50},b={fingerprint:"b",longitude:-75,latitude:40},c={fingerprint:"c",longitude:105,latitude:15}
  panel.localOrigin={country:"TH",longitude:101,latitude:15}
  var one={id:"1",route:[a,b,c]},two={id:"2",route:[a,c,b]}
  panel.localCircuits=snapshot([one]);wait(50);note.phraseIndex=note.phrases.findIndex(p=>p.action==="local-circuits");verify(copy.text.indexOf("1 built circuit.")>=0);verify(action.visible)
  mouseClick(action);verify(panel.circuitsShown);verify(note.paused);wait(1100)
  compare(overlay.entries.length,1);compare(panel.globe.normalRouteOpacity,0)
  compare(overlay.displayRoute(overlay.entries[0]).length,4)
  compare(overlay.displayRoute(overlay.entries[0])[0].country,"TH")
  verify(overlay.displayRoute(overlay.entries[0])[0].localDevice)
  compare(overlay.entries[0].route.length,3) // Observed Tor path remains unchanged.
  panel.localOrigin={};compare(overlay.displayRoute(overlay.entries[0]).length,3)
  panel.localOrigin={country:"CA",longitude:-100,latitude:55}
  compare(overlay.displayRoute(overlay.entries[0])[0].country,"CA")
  var privateEntry={route:[{},a,b]};compare(overlay.displayRoute(privateEntry).length,4)
  compare(Object.keys(overlay.displayRoute(privateEntry)[1]).length,0)
  panel.localOrigin={country:"TH",longitude:101,latitude:15}
  var started=overlay.entries[0].start
  panel.localCircuits=snapshot([one]);wait(50);compare(overlay.entries[0].start,started)
  panel.localCircuits=snapshot([one,two]);wait(600);compare(overlay.entries.length,2);verify(overlay.circuitColor(overlay.entries[0].slot)!==overlay.circuitColor(overlay.entries[1].slot))
  grabImage(this).save("/tmp/tor-local-circuits.png")
  panel.localCircuits=snapshot([two]);wait(400);compare(overlay.entries.length,1)
  panel.localCircuits={available:true,count:1,circuits:[two],observedAt:Date.now()/1000-20};wait(400);compare(overlay.entries.length,0);verify(!action.visible)
  keyClick(Qt.Key_Escape);verify(!panel.circuitsShown);tryCompare(panel.globe,"normalRouteOpacity",1);verify(!note.paused)
  panel.interfaceSettings=({layout:3,sentenceSize:12,sentenceInterval:3000,uiScale:1,reducedMotion:true})
  panel.localCircuits=snapshot([one]);wait(50);note.phraseIndex=note.phrases.findIndex(p=>p.action==="local-circuits");wait(50);mouseClick(action);wait(50);compare(overlay.amount(overlay.entries[0]),1)
  keyClick(Qt.Key_Escape);verify(!panel.circuitsShown)
  compare(renew.count,0);compare(illuminate.count,0)
 }
}
