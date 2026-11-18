import ".."
import QtQuick

// NEWNYM acknowledges immediately. Completion is a newly observed circuit.
QtObject {
 id:root
 property var connection:({})
 property bool automaticObservation:true
 property bool pending:false
 property string previousId:""
 property string generation:""
 property string message:""
 property int timeoutMs:60000
 function begin(){
  if(pending)return
  previousId=String(connection.circuitId||"")
  generation=String(connection.gatewayGeneration||"")
  message="";pending=true;deadline.restart()
 }
 function finish(){pending=false;deadline.stop()}
 function fail(){finish();message="Could not confirm a new circuit. Try again."}
 function observe(){
  if(!pending)return
  var c=connection
  if(c.running===false||["offline","stopping","error","unavailable"].indexOf(c.state)>=0){finish();return}
  if(generation&&c.gatewayGeneration&&generation!==String(c.gatewayGeneration)){finish();return}
  if(c.state==="ready"&&c.circuitId&&String(c.circuitId)!==previousId)finish()
 }
 onConnectionChanged:if(automaticObservation)observe()
 property Timer deadline:Timer {interval:root.timeoutMs;onTriggered:{root.finish();root.message="Tor has not reported a different circuit yet. Try again."}}
}
