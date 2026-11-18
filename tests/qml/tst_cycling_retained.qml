import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 id:test;name:"RetainedCycling";when:windowShown;visible:true;width:460;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;interfaceSettings:({layout:3,reducedMotion:true});localOrigin:({country:"TH",countryName:"Thailand",latitude:15,longitude:100});exitNetwork:({count:20,countries:3,points:[]});localCircuits:({available:true,observedAt:Date.now()/1000,count:1,circuits:[{id:"sample",route:[{country:"DE",latitude:51,longitude:10},{country:"CH",latitude:47,longitude:8},{country:"NL",latitude:52,longitude:5}]}]});onionEstimate:({text:"Tor Metrics estimates 657,000 .onion addresses for 22 Sep 2026."})}
 function test_retained_data(){var rows=[];for(var narrow of [false,true])for(var light of [false,true])for(var reduced of [false,true])rows.push({tag:(narrow?"narrow":"normal")+(light?"-light":"-dark")+(reduced?"-still":"-motion"),w:narrow?280:460,h:narrow?440:700,light:light,reduced:reduced});return rows}
 function test_retained(data){
  failOnWarning(/.*/);width=data.w;height=data.h;panel.interfaceSettings={layout:3,sentenceSize:12,sentenceInterval:45000,reducedMotion:data.reduced}
  panel.ink=data.light?"#17212b":"#eeeeee";panel.background=data.light?"#faf9f5":"#101816";panel.accent=data.light?"#16634e":"#78d9ac"
  panel.localCircuits=Object.assign({},panel.localCircuits,{observedAt:Date.now()/1000})
  var note=findChild(panel,"rotating-tor-note");note.showNote(false);tryCompare(findChild(note,"cycling-note-presence"),"opacity",1)
  for(var number of [1,4,9,13]){
   note.phraseIndex=note.phrases.findIndex(p=>p.number===number);verify(note.phraseIndex>=0)
   verify(findChild(note,"cycling-tor-copy").text.indexOf("#"+number+" · ")===0)
   wait(60);grabImage(test).save("/tmp/tor-retained-"+number+"-"+data.tag+".png")
  }
  panel.openAntipode();var control=panel.antipodeController
  control.receive({countries:[{country:"NL",countryName:"Netherlands",latitude:52,longitude:5,exitCount:15},{country:"US",countryName:"United States",latitude:38,longitude:-97,exitCount:42}]},control.revision)
  verify(control.result.distanceKm>0);tryCompare(control,"stage",2,5500)
  var box=findChild(panel,"antipode-controls");verify(box.width<=344);verify(box.width<=width-24);verify(box.y>=0)
  wait(80);grabImage(test).save("/tmp/tor-retained-15-"+data.tag+".png")
  mouseClick(findChild(panel,"antipode-close"));verify(!control.showing)
 }
}
