import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 id:test;name:"CyclingCleanup";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;interfaceSettings:({layout:3,reducedMotion:true});localOrigin:({country:"TH",latitude:15,longitude:100});localCircuits:({available:true,observedAt:Date.now()/1000,count:1,circuits:[]})}
 SignalSpy {id:renewals;target:panel;signalName:"newCircuit"}
 function popup(){return findChild(panel,"footer-explanation")}
 function init(){failOnWarning(/.*/);panel.active=true;panel.torRunning=true;renewals.clear()}
 function cleanup(){panel.active=false;tryCompare(popup(),"visible",false);panel.active=true;panel.torRunning=true;width=460;height=700;panel.interfaceSettings={layout:3,reducedMotion:true}}
 function test_layouts_data(){var rows=[];for(var narrow of [false,true])for(var light of [false,true])for(var reduced of [false,true])rows.push({tag:(narrow?"narrow":"normal")+(light?"-light":"-dark")+(reduced?"-still":"-motion"),w:narrow?280:460,h:narrow?360:700,light:light,reduced:reduced});return rows}
 function test_layouts(data){
  width=data.w;height=data.h;panel.interfaceSettings={layout:3,reducedMotion:data.reduced}
  var dialog=popup(),note=findChild(panel,"rotating-tor-note"),action=findChild(note,"cycling-tor-action")
  dialog.ink=data.light?"#17212b":"#eeeeee";dialog.surface=data.light?"#faf9f5":"#101816";dialog.accent=data.light?"#16634e":"#78d9ac"
  compare(note.allPhrases.map(p=>p.number).join(","),"1,2,3,4,5,6,9,10,11,12,13,14,15")
  for(var topic of ["onion-address","onion-meeting","file-transfer","peel-layers","browser-protections","snowflake","onion-location"]){
   dialog.topic=topic;dialog.open();tryCompare(dialog,"opened",true)
   verify(note.paused);verify(!action.animating);verify(dialog.width<=344);verify(dialog.width<=width-24);verify(dialog.height<=height-24)
   wait(80);grabImage(test).save("/tmp/tor-cleanup-"+topic+"-"+data.tag+".png")
   dialog.close();tryCompare(dialog,"visible",false)
  }
  var speed=findChild(panel,"speed-comparison");speed.open();tryCompare(speed,"opened",true)
  speed.accepting=true;speed.receive({running:false,direct:{status:"complete",mbps:25,ttfb:30},tor:{status:"complete",mbps:4,ttfb:340,circuitIds:["12"],paths:[{countries:["TH","DE","CH","NL","US"],roundTripKm:12300}]}})
  wait(80);grabImage(test).save("/tmp/tor-cleanup-speed-"+data.tag+".png");verify(speed.width<=344);verify(speed.height<=height-24);speed.close();tryCompare(speed,"visible",false)
 }
 function test_circuit_lifetime(){
  mouseMove(test,0,0);panel.circuitsShown=true
  tryVerify(()=>panel.circuitRemaining<9800,1000)
  var before=panel.circuitRemaining
  panel.localCircuits={available:true,observedAt:Date.now()/1000,count:2,circuits:[]}
  verify(panel.circuitRemaining<=before)
  mouseMove(test,width/2,height/2);tryCompare(panel,"circuitHover",true)
  var paused=panel.circuitRemaining;wait(300);compare(panel.circuitRemaining,paused)
  mouseMove(test,0,0);tryCompare(panel,"circuitHover",false);tryCompare(panel,"circuitsShown",false,11000)
  compare(renewals.count,0);verify(findChild(panel,"rotating-tor-note").automaticReady)
  panel.circuitsShown=true;panel.forceActiveFocus();keyClick(Qt.Key_Escape);compare(panel.circuitsShown,false)
  panel.circuitsShown=true;panel.active=false;compare(panel.circuitsShown,false);panel.active=true
  panel.circuitsShown=true;panel.torRunning=false;compare(panel.circuitsShown,false);compare(renewals.count,0)
 }
 function test_animation_lifecycle(){
  panel.interfaceSettings={layout:3,reducedMotion:false}
  var dialog=popup();dialog.topic="onion-meeting";dialog.open();tryCompare(dialog,"opened",true);tryCompare(dialog,"progress",1,4000)
  var packets=findChild(dialog,"rendezvous-packets");verify(packets.running);var phase=dialog.packetPhase;wait(200);verify(dialog.packetPhase!==phase)
  dialog.close();tryCompare(dialog,"visible",false);verify(!packets.running)
  dialog.topic="peel-layers";dialog.open();tryCompare(dialog,"opened",true)
  var peel=findChild(dialog,"peel-layers-illustration"),timeline=findChild(peel,"encryption-timeline");verify(timeline.running)
  for(var i=0;i<10;i++){timeline.pause();peel.clock=i+.1;compare(peel.layers,[3,2,1,0,0,0,1,2,3,0][i]);compare(peel.response,i>=5)}
  timeline.resume();dialog.close();tryCompare(dialog,"visible",false);verify(!timeline.running);var held=peel.clock;wait(100);compare(peel.clock,held)
  panel.interfaceSettings={layout:3,reducedMotion:true};dialog.topic="onion-meeting";dialog.open();tryCompare(dialog,"opened",true);compare(dialog.progress,1);verify(!packets.running)
 }
 function test_file_modal_keeps_globe(){
  var globe=panel.globe,dialog=popup()
  // The file animation owns no globe state or camera.
  dialog.topic="file-transfer";dialog.open();tryCompare(dialog,"opened",true);verify(dialog.modal);verify(panel.fileShown);compare(globe.normalRouteOpacity,1)
  var transfer=findChild(dialog,"file-transfer-illustration");verify(transfer.showing)
  panel.active=false;tryCompare(dialog,"visible",false);verify(!transfer.showing)
 }
 function test_speed_attribution(){
  var speed=findChild(panel,"speed-comparison");speed.open();tryCompare(speed,"opened",true)
  compare(speed.circuitText({countries:["TH","DE","CH","NL","US"],roundTripKm:12300}),"Circuit: TH → DE → CH → NL → US · ~"+Number(12300).toLocaleString(Qt.locale(),"f",0)+" km return")
  compare(speed.circuitText({}),"")
  compare(speed.circuitText({countries:["TH","?","CH","NL","US"]}),"")
  compare(speed.circuitText({countries:["?","DE","CH","NL","US"]}),"Circuit: DE → CH → NL → US")
  speed.accepting=true;speed.receive({running:false,tor:{status:"complete",circuitIds:["1","2"],paths:[{countries:["TH","DE","CH","NL","US"],roundTripKm:12300},{countries:["TH","FR","GB","NL","US"],roundTripKm:13000}]}})
  tryVerify(()=>findChild(speed.contentItem,"speed-circuit-0")!==null);tryVerify(()=>findChild(speed.contentItem,"speed-circuit-1")!==null)
  speed.start();verify(speed.running);speed.cancel();verify(!speed.running);verify(!speed.accepting)
  speed.receive({running:true,tor:{paths:[{}]}});verify(!speed.running)
  speed.start();panel.torRunning=false;verify(!speed.running);verify(!speed.accepting);verify(speed.measurement.error.indexOf("disconnected")>=0)
  speed.close();tryCompare(speed,"visible",false)
 }
 function test_conflux_layouts_data(){return test_layouts_data()}
 function test_conflux_layouts(data){
  width=data.w;height=data.w<460?620:700;panel.interfaceSettings={layout:3,reducedMotion:data.reduced}
  var speed=findChild(panel,"speed-comparison");speed.ink=data.light?"#17212b":"#eeeeee";speed.surface=data.light?"#faf9f5":"#101816";speed.accent=data.light?"#16634e":"#78d9ac"
  speed.open();tryCompare(speed,"opened",true)
  var first={countries:["TH","LU","HU","NL","US"],roundTripKm:22500},second={countries:["TH","DE","US","NL","US"],roundTripKm:47800}
  function result(paths,multipath){speed.accepting=true;speed.receive({running:false,direct:{status:"complete",mbps:75.67,ttfb:350},tor:{status:"complete",mbps:12.34,ttfb:820,multipath:multipath,sharedExitConfirmed:multipath,paths:paths}})}
  result([first,second],true);verify(speed.conflux)
  tryVerify(()=>findChild(speed.contentItem,"speed-guard-1")!==null)
  verify(speed.joinedPair)
  var diagram=findChild(speed.contentItem,"speed-joined-routes")
  verify(diagram.visible);verify(diagram.width<=208);compare(diagram.height,58)
  compare(findChild(diagram,"speed-shared-client").text,"TH")
  compare(findChild(diagram,"speed-shared-exit").text,"NL")
  compare(findChild(diagram,"speed-guard-0").text,"LU");compare(findChild(diagram,"speed-middle-0").text,"HU")
  compare(findChild(diagram,"speed-guard-1").text,"DE");compare(findChild(diagram,"speed-middle-1").text,"US")
  compare(findChild(speed.contentItem,"speed-branch-distance-0").text,speed.distanceText(first))
  compare(findChild(speed.contentItem,"speed-branch-distance-1").text,speed.distanceText(second))
  compare(findChild(speed.contentItem,"speed-distance-label-0").text,"Circuit 1 total")
  compare(findChild(speed.contentItem,"speed-distance-label-1").text,"Circuit 2 total")
  verify(findChild(speed.contentItem,"speed-conflux-explanation").visible)
  wait(80);grabImage(test).save("/tmp/tor-speed-conflux-"+data.tag+".png")
  verify(speed.width<=344);verify(speed.width<=width-24)
  height=360;verify(speed.height<=height-24);height=data.w<460?620:700
  result([first,{countries:second.countries}],true)
  tryVerify(()=>findChild(speed.contentItem,"speed-distance-row-1")!==null)
  verify(findChild(speed.contentItem,"speed-distance-row-0").visible)
  verify(!findChild(speed.contentItem,"speed-distance-row-1").visible)
  compare(findChild(speed.contentItem,"speed-branch-distance-1").text,"")
  result([{countries:["TH","DE","DE","NL","US"],roundTripKm:22500},second],true)
  compare(findChild(diagram,"speed-shared-client").text,"TH")
  compare(findChild(diagram,"speed-guard-0").text,"DE");compare(findChild(diagram,"speed-middle-0").text,"DE")
  compare(findChild(speed.contentItem,"speed-distance-label-0").text,"Circuit 1 total")
  compare(findChild(speed.contentItem,"speed-branch-distance-0").text,speed.distanceText(first))
  result([{countries:["?","DE","DE","NL","US"]},second],true);verify(!diagram.visible)
  result([first],false);verify(!diagram.visible);verify(!findChild(speed.contentItem,"speed-conflux-explanation").visible)
  tryVerify(()=>findChild(speed.contentItem,"speed-circuit-0")!==null)
  verify(findChild(speed.contentItem,"speed-circuit-0").text.indexOf("LU → HU → NL")>=0)
  result([first,second],false);verify(!speed.conflux);verify(!diagram.visible)
  result([first,{countries:["TH","DE","?","NL","US"]}],true);verify(speed.conflux);verify(!diagram.visible)
  tryVerify(()=>findChild(speed.contentItem,"speed-circuit-1")!==null)
  compare(findChild(speed.contentItem,"speed-circuit-1").text,"");verify(!findChild(speed.contentItem,"speed-circuit-1").visible)
  result([first,{countries:["TH","DE","US","FR","US"]}],false);verify(!speed.conflux)
  result([],false);verify(!speed.conflux);verify(!findChild(speed.contentItem,"speed-routes").visible)
  speed.close();tryCompare(speed,"visible",false)
 }
 function test_icon_pulse(){
  panel.interfaceSettings={layout:3,reducedMotion:false};var note=findChild(panel,"rotating-tor-note"),action=findChild(note,"cycling-tor-action")
  note.showNote(false);note.phraseIndex=note.phrases.findIndex(p=>p.number===2);tryCompare(action,"animating",true);var breath=action.breath;wait(100);verify(action.breath!==breath)
  panel.openOptions();tryCompare(panel,"optionsOpened",true);verify(!action.animating)
  panel.active=false;verify(!action.animating)
 }
}
