import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"CircuitRenewal";when:windowShown;visible:true;width:460;height:640
 Tor.CircuitRenewal {id:request}
 Tor.CircuitInterface {id:view;anchors.fill:parent;variant:3;active:true;torRunning:true;canChange:true;busy:request.pending;state:request.connection.state||"ready"}
 function snapshot(id,state){return {running:true,state:state||"ready",circuitId:id,gatewayGeneration:"one"}}
 function init(){request.finish();request.message="";request.timeoutMs=60000;request.connection=snapshot("10");view.active=true;view.reducedMotion=false}
 function test_acknowledgement_keeps_spinning(){
  var glyph=findChild(view,"circuit-renew-glyph"),button=findChild(view,"lab-circuit-action")
  request.begin();request.connection=snapshot("10");verify(request.pending);verify(!button.enabled)
  wait(120);var angle=glyph.rotation;wait(180);verify(Math.abs(glyph.rotation-angle)>10,"Glyph must visibly rotate while waiting after acknowledgement")
  compare(glyph.opacity,.35,"Spinning remains dim while unavailable")
  request.connection=snapshot("10","starting");verify(request.pending)
  request.connection=snapshot("11");verify(!request.pending);tryCompare(glyph,"rotation",0);verify(glyph.opacity>=.85,"Available again is bright")
 }
 function test_pending_is_not_cooldown(){request.begin();request.connection=snapshot("11");view.cooldown=10;verify(!request.pending);verify(!findChild(view,"circuit-renew-glyph").fetching);view.cooldown=0}
 function test_errors_restart_and_timeout(){
  for(var state of ["error","offline","unavailable","stopping"]){request.connection=snapshot("10");request.begin();request.connection=snapshot("10",state);verify(!request.pending)}
  request.connection=snapshot("10");request.begin();request.connection={running:true,state:"ready",circuitId:"10",gatewayGeneration:"two"};verify(!request.pending)
  request.timeoutMs=30;request.begin();tryCompare(request,"pending",false);verify(request.message.length>0)
 }
 function test_waiting_failure_enables_retry_and_new_attempt(){
  request.connection=snapshot("","starting")
  var button=findChild(view,"lab-circuit-action"),glyph=findChild(view,"circuit-renew-glyph")
  verify(!button.enabled);verify(glyph.fetching)
  request.connection=snapshot("","error");verify(button.enabled);verify(!glyph.fetching)
  request.begin();request.connection=snapshot("","starting");verify(!button.enabled);verify(glyph.fetching)
  request.connection=snapshot("42");verify(!request.pending);verify(button.enabled)
 }
 function test_hidden_and_motion_changes_stop_spinner(){
  request.begin();var glyph=findChild(view,"circuit-renew-glyph")
  tryVerify(()=>glyph.rotation>0)
  view.active=false;tryCompare(glyph,"rotation",0);verify(!glyph.spinning)
  view.active=true;tryVerify(()=>glyph.rotation>0)
  view.reducedMotion=true;tryCompare(glyph,"rotation",0);verify(!glyph.spinning)
  var icon=findChild(view,"circuit-renew-icon");compare(icon.width,icon.height)
 }
 function test_reduced_motion(){view.reducedMotion=true;request.begin();wait(150);compare(findChild(view,"circuit-renew-glyph").rotation,0);compare(findChild(view,"circuit-renew-glyph").opacity,.35)}
}
