import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"DisplayedCircuit";when:windowShown;visible:true;width:460;height:640
 Tor.DisplayedCircuit {id:model;onReplacementReady:renewal.finish()}
 Tor.CircuitRenewal {
  id:renewal;connection:model.connection;automaticObservation:false
  onPendingChanged:if(!pending&&model.replacementPending)model.failReplacement()
 }
 Tor.TorDashboard {id:panel;anchors.fill:parent;active:true;showPowerControls:true;route:model.route;circuitId:model.circuitId}
 property var origin:({country:"TH",ip:"198.51.100.1",longitude:101,latitude:15})
 property var relays:[{country:"DE",fingerprint:"guard",longitude:10,latitude:51},{country:"FR",fingerprint:"middle",longitude:2,latitude:46},{country:"US",fingerprint:"exit",longitude:-100,latitude:40}]
 function connection(id,point){return {running:true,state:"ready",circuitId:id,route:relays,origin:point}}
 function init(){failOnWarning(/.*/);renewal.finish();renewal.timeoutMs=60000;model.reset();model.connection={running:false}}
 function test_atomic_start_and_origin_refresh(){
  var renderer=findChild(panel,"ember-transition")
  model.connection=connection("a",{});wait(30)
  compare(model.route.length,0);verify(!renderer.initialized)
  model.connection=connection("a",origin);tryCompare(renderer,"initialized",true)
  compare(model.route.length,4);compare(renderer.newRoute.length,4)
  compare(model.route.map(h=>h.role).join(","),"You,Guard,Middle,Exit")
  compare(model.route[0].country,"TH")
  var snapshot=model.snapshot,clock=renderer.clock
  model.connection=connection("a",{});wait(30)
  compare(model.snapshot,snapshot);verify(renderer.clock>=clock)
  model.connection=connection("a",Object.assign({},origin,{ip:"198.51.100.2"}));wait(30)
  compare(model.snapshot,snapshot);verify(renderer.clock>=clock)
  model.connection=connection("b",{});compare(model.snapshot,snapshot)
  model.connection=connection("b",origin);wait(30)
  compare(model.snapshot,snapshot);compare(model.circuitId,"a");verify(renderer.clock>=clock)
  model.connection={running:false,state:"stopping",route:[]};compare(model.route.length,0)
 }
 function test_idle_and_background_replacement_keep_the_same_drawing(){
  model.connection=connection("a",origin);wait(30)
  var snapshot=model.snapshot,renderer=findChild(panel,"ember-transition"),clock=renderer.clock
  for(var state of ["starting","error","unavailable","busy"]){
   model.connection={running:true,state:state,route:[],localCircuits:{available:true,count:0}}
   compare(model.snapshot,snapshot)
  }
  model.connection=connection("b",origin);wait(30)
  compare(model.snapshot,snapshot);compare(renderer.circuitId,"a");verify(renderer.clock>=clock)
 }
 function test_click_retires_immediately_and_rejects_old_responses(){
  model.connection=connection("a",origin);wait(30)
  model.connection=connection("b",origin) // The backend has moved on independently.
  model.beginReplacement();renewal.begin();compare(model.route.length,0)
  var renderer=findChild(panel,"ember-transition");tryCompare(renderer,"retiring",true)
  model.connection=connection("c",origin) // Status already in flight at click time.
  compare(model.route.length,0);verify(renewal.pending)
  model.excludeCurrent() // Current backend route when the queued command launches.
  model.acknowledgeReplacement();compare(model.route.length,0)
  for(var id of ["a","b","c"]){model.connection=connection(id,origin);compare(model.route.length,0)}
  model.connection=connection("d",{});compare(model.route.length,0);verify(renewal.pending)
  model.connection=connection("d",origin);compare(model.circuitId,"d");verify(!renewal.pending)
  tryCompare(renderer,"retiring",false);compare(renderer.newRoute.length,4)
 }
 function test_failed_or_timed_out_request_recovers_from_late_observation(){
  model.connection=connection("a",origin)
  model.beginReplacement();renewal.begin();model.acknowledgeReplacement()
  renewal.fail();verify(model.failed);compare(model.route.length,0)
  model.connection=connection("a",origin);compare(model.route.length,0)
  model.connection=connection("b",origin);compare(model.circuitId,"b");verify(!model.failed)
  model.beginReplacement("FR");renewal.timeoutMs=30;renewal.begin();model.acknowledgeReplacement()
  tryCompare(renewal,"pending",false);verify(model.failed)
  model.connection=Object.assign(connection("c",origin),{exitCountry:"US"});compare(model.route.length,0)
  model.connection=Object.assign(connection("c",{}),{exitCountry:"FR"});compare(model.route.length,0)
  model.connection=Object.assign(connection("c",origin),{exitCountry:"FR"});compare(model.circuitId,"c");verify(!model.failed)
 }
 function test_country_and_gateway_changes(){
  var a=Object.assign(connection("a",origin),{exitCountry:"US",gatewayGeneration:"one"})
  model.connection=a
  model.beginReplacement("FR");renewal.begin()
  model.connection=Object.assign(connection("b",origin),{exitCountry:"US",gatewayGeneration:"one"})
  model.acknowledgeReplacement();compare(model.route.length,0)
  model.connection=Object.assign(connection("c",origin),{exitCountry:"FR",gatewayGeneration:"one"})
  compare(model.circuitId,"c");verify(!renewal.pending)
  model.connection={running:true,state:"starting",gatewayGeneration:"two",route:[]};compare(model.route.length,0)
  model.connection=Object.assign(connection("a",origin),{exitCountry:"FR",gatewayGeneration:"two"});compare(model.circuitId,"a")
  model.connection={running:false,state:"offline"};compare(model.route.length,0)
 }
 function test_unlock_keeps_snapshot_until_explicit_replacement(){
  model.connection=Object.assign(connection("locked",origin),{exitCountry:"US"})
  var before=model.snapshot
  model.connection={running:true,state:"starting",exitCountry:"",route:[]}
  compare(model.snapshot,before)
  model.connection=Object.assign(connection("unlocked",origin),{exitCountry:""})
  compare(model.snapshot,before);verify(!model.replacementPending)
  model.connection=Object.assign(connection("background",origin),{exitCountry:""})
  compare(model.snapshot,before)
  model.beginReplacement();renewal.begin();model.acknowledgeReplacement()
  compare(model.route.length,0)
  model.connection=Object.assign(connection("requested",origin),{exitCountry:""})
  compare(model.circuitId,"requested");verify(!renewal.pending)
 }
 function test_reject_incomplete_or_extra_nodes(){
  for(var count of [0,1,2,4]){
   var c=connection("invalid",origin);c.route=relays.concat(relays).slice(0,count)
   model.connection=c;compare(model.route.length,0)
  }
  model.connection=connection("invalid",Object.assign({},origin,{longitude:undefined}));compare(model.route.length,0)
  var c=connection("invalid",origin);c.route=JSON.parse(JSON.stringify(relays));delete c.route[1].latitude
  model.connection=c;compare(model.route.length,0)
  model.connection=connection("valid",origin);compare(model.route.length,4)
  model.connection={state:"busy"};compare(model.route.length,4)
 }
}
