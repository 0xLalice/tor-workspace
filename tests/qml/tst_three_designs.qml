import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/EffectSettings.js" as Effects
TestCase {
 id:test;name:"BuiltinDesigns";when:windowShown;visible:true;width:460;height:700
 property var route:[{country:"TH",longitude:101,latitude:15},{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:47},{country:"US",fingerprint:"exit",longitude:-77,latitude:39}]
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready";route:test.route;showPowerControls:true;showLaunchControls:true;availableThemes:Builtins.entries;installationReady:true}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 SignalSpy {id:lock;target:panel;signalName:"exitCountryRequested"}
 function apply(index,reduced){var p=Effects.snapshot(Builtins.entries[index]);panel.appearance=p.appearance;panel.interfaceSettings=Object.assign({},p.interface,{reducedMotion:reduced});panel.effectSettings=Tor.ThemeColors.resolveData(p.settings)}
 function capture(path){wait(180);grabImage(test).save(path)}
 function init(){failOnWarning(/.*/);panel.route=test.route;panel.installationReady=true;Tor.RenderCapabilities.nativeReady=true;panel.active=true;renew.clear();lock.clear()}
 function cleanup(){panel.closePresentation();panel.active=false;Tor.ThemeDesign.design="original";width=460;height=700}
 function test_design_contract(){
  compare(Effects.interfaceConfig({}).design,"original")
  for(var i=0;i<Builtins.entries.length;i++)compare(Effects.snapshot(Builtins.entries[i]).id,["original","meridian"][i])
  for(var value of [null,false,"../other",""]){var rejected=false;try{Effects.interfaceConfig({design:value})}catch(e){rejected=true}verify(rejected)}
 }
 function test_screens_data(){var data=[];for(var design=0;design<Builtins.entries.length;design++)for(var narrow of [false,true])for(var reduced of [false,true])data.push({tag:Builtins.entries[design].id+(narrow?"-narrow":"-normal")+(reduced?"-still":"-motion"),design:design,narrow:narrow,reduced:reduced});return data}
 function test_screens(data){
  width=data.narrow?280:460;height=data.narrow?420:700;apply(data.design,data.reduced)
  wait(data.reduced?100:2600);waitForRendering(panel);verify(panel.globe.renderStatus!==2);capture("/tmp/tor-design-dashboard-"+data.tag+".png")
  var explanation=findChild(panel,"footer-explanation")
  for(var topic of ["onion-address","onion-meeting","file-transfer","peel-layers","browser-protections","snowflake","onion-location"]){
   explanation.topic=topic;explanation.open();tryCompare(explanation,"opened",true)
   verify(explanation.width<=width-24);verify(explanation.height<=height-24)
   wait(60);capture("/tmp/tor-design-"+topic+"-"+data.tag+".png")
   explanation.close();tryCompare(explanation,"visible",false)
  }
  for(var item of [{open:"openShare",name:"file-share-dialog"},{open:"openChat",name:"chat-dialog"},{open:"openHost",name:"host-dialog"},{open:"openDarknet",name:"darknet-dialog"},{open:"openOptions",name:"tor-options"},{open:"openInstallation",name:"installation-dialog"},{open:"openUpdate",name:"update-dialog"}]){
   if(item.open==="openInstallation")panel.installationReady=false;panel[item.open]();var dialog=findChild(panel,item.name);verify(dialog!==null,item.name);tryCompare(dialog,"opened",true)
   verify(dialog.width<=width-24);verify(dialog.height<=height-24,item.name+" clipped")
   wait(60);capture("/tmp/tor-design-"+item.name+"-"+data.tag+".png")
   dialog.close();tryCompare(dialog,"visible",false);panel.installationReady=true
  }
  for(var state of ["empty","loading","populated","failed","cancelled"]){
   var phase=state==="loading"?"starting":state==="populated"?"ready":state==="failed"?"error":"stopped",error=state==="failed"?"Request failed. Please retry.":state==="cancelled"?"Request cancelled.":""
   panel.chatState={state:phase,url:phase==="ready"?"http://example.onion":"",error:error}
   panel.hostState={state:phase,url:phase==="ready"?"http://example.onion":"",source:{mode:"folder",folder:"/example/site",port:3000},error:error}
   panel.shareState={api:2,shares:state==="empty"||state==="cancelled"?[]:[{id:"fixture",name:"A long document filename for responsive layout.pdf",state:state==="loading"?"preparing":state==="failed"?"error":"ready",url:"http://example.onion",size:123456,message:error}],error:error}
   for(var dialogName of ["file-share-dialog","chat-dialog","host-dialog"]){
    var dialog=findChild(panel,dialogName);dialog.open();tryCompare(dialog,"opened",true);wait(50)
    verify(dialog.height<=height-24,dialogName+" "+state+" exceeds viewport")
    capture("/tmp/tor-design-"+dialogName+"-"+state+"-"+data.tag+".png");dialog.close();tryCompare(dialog,"visible",false)
   }
  }
  var chooser=findChild(panel,"published-theme-chooser");chooser.open();tryCompare(chooser,"opened",true);compare(chooser.themes.length,2);wait(50);capture("/tmp/tor-design-themes-"+data.tag+".png");chooser.close()
  var speed=findChild(panel,"speed-comparison");speed.open();tryCompare(speed,"opened",true)
  for(var state of ["empty","loading","populated","failed","cancelled"]){
   speed.measurement=state==="loading"?{running:true}:state==="populated"?{tor:{status:"complete",mbps:4,ttfb:280,paths:[{countries:["TH","DE","FR","US","CA"],roundTripKm:24000}]},direct:{status:"complete",mbps:40,ttfb:70}}:state==="failed"?{error:"Test request failed."}:state==="cancelled"?{error:"Comparison cancelled."}:{}
   wait(40);capture("/tmp/tor-design-speed-"+state+"-"+data.tag+".png");verify(speed.height<=height-24)
  }
  speed.close();tryCompare(speed,"visible",false)
  panel.selectedHop=test.route[1];wait(50);capture("/tmp/tor-design-relay-"+data.tag+".png");panel.closeRelay()
  panel.localCircuits={available:true,count:1,observedAt:Date.now()/1000,circuits:[{id:"sample",route:test.route.slice(1)}]};panel.circuitsShown=true;wait(100);capture("/tmp/tor-design-built-"+data.tag+".png");panel.closeCircuits(false)
  compare(renew.count,0);compare(lock.count,0)
  compare(findChild(panel,"rotating-tor-note").allPhrases.map(p=>p.number).join(","),"1,2,3,4,5,6,9,10,11,12,13,14,15")
 }
 function test_native_build_retire_and_hidden(){
  apply(1,false);var renderer=findChild(panel.globe,"design-route");tryCompare(renderer,"nativeReady",true);tryCompare(renderer,"building",false,3000)
  tryVerify(()=>renderer.paintCount>0);panel.route=test.route.slice(0,3);tryCompare(renderer,"retiring",true)
  tryCompare(renderer,"retiring",false,3000);compare(renderer.outgoing.length,0)
  panel.active=false;wait(80);var paints=renderer.paintCount,clock=renderer.clock;wait(200);compare(renderer.paintCount,paints);compare(renderer.clock,clock)
  panel.active=true;apply(1,true);wait(100);verify(!renderer.building);verify(!renderer.retiring)
  paints=renderer.paintCount;wait(100);compare(renderer.paintCount,paints)
  compare(renew.count,0);compare(lock.count,0);panel.route=test.route
 }
 function test_theme_switch_closes_overlays(){
  apply(1,true);panel.openChat();tryCompare(findChild(panel,"chat-dialog"),"opened",true)
  apply(0,true);tryCompare(findChild(panel,"chat-dialog"),"visible",false)
  for(var i=0;i<30;i++)apply(i%2,true)
  compare(renew.count,0);compare(lock.count,0);compare(panel.route,test.route)
 }
 function test_exit_country_is_not_exit_identity(){
  apply(1,true);var speed=findChild(panel,"speed-comparison")
  speed.measurement={tor:{multipath:true,paths:[{countries:["TH","DE","FR","NL","US"]},{countries:["TH","FI","GB","NL","US"]}]}}
  verify(!speed.joinedPair)
 }
}
