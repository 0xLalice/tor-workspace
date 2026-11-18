import ".."
import QtQuick
import "RouteGeometry.js" as Geometry

// A representative observed route has a presentation lifetime of its own.
QtObject {
 id:root
 property var connection:({})
 property var snapshot:({route:[],circuitId:"",key:""})
 readonly property var route:snapshot.route
 readonly property string circuitId:snapshot.circuitId
 property bool replacementPending:false
 property bool accepting:true
 property bool failed:false
 property var excludedIds:[]
 property var requestedCountry:null
 property string generation:""
 signal replacementReady()
 function clear(){snapshot={route:[],circuitId:"",key:""}}
 function reset(){
  replacementPending=false;accepting=true;failed=false;excludedIds=[];requestedCountry=null;generation="";clear()
 }
 function excludeCurrent(){
  var id=String(connection.circuitId||"")
  if(id&&excludedIds.indexOf(id)<0)excludedIds=excludedIds.concat([id])
 }
 function beginReplacement(country){
  excludedIds=circuitId?[circuitId]:[];excludeCurrent()
  requestedCountry=country===undefined?null:country
  accepting=false;failed=false;replacementPending=true;clear()
 }
 function acknowledgeReplacement(){
  if(!replacementPending)return
  accepting=true;synchronize()
 }
 function failReplacement(){replacementPending=false;accepting=true;failed=true;clear()}
 function synchronize(){
  var c=connection
  if(c.state==="busy")return
  if(c.state==="offline"||c.state==="stopping"||c.running===false&&c.state!=="error"){reset();return}
  var nextGeneration=String(c.gatewayGeneration||"")
  if(generation&&nextGeneration&&generation!==nextGeneration)reset()
  if(nextGeneration)generation=nextGeneration
  if(!accepting||c.running!==true||c.state!=="ready"||!c.circuitId||!c.route||c.route.length!==3)return
  if((replacementPending||failed)&&(excludedIds.indexOf(String(c.circuitId))>=0||(requestedCountry!==null&&requestedCountry!==String(c.exitCountry||""))))return
  // Routine expiry, replacement, and origin updates never animate a new route.
  // Unlocking allows any exit; the retained route still satisfies that policy.
  if(route.length&&!replacementPending&&(!c.exitCountry||snapshot.country===String(c.exitCountry)))return
  // Origin refreshes cannot independently rebuild an already drawn circuit.
  var key=String(c.gatewayGeneration||"")+":"+String(c.circuitId||"")+":"+JSON.stringify(c.route.map(function(h){return [h.fingerprint||h.ip||"",h.longitude,h.latitude]}))
  if(snapshot.key===key)return
  var origin=c.origin
  if(!origin||!origin.country||!Geometry.vector(origin)||!c.route.every(function(h){return !!h.country&&Geometry.vector(h)!==null}))return
  var next=JSON.parse(JSON.stringify([origin].concat(c.route)))
  var roles=["You","Guard","Middle","Exit"]
  next.forEach(function(h,i){h.role=roles[i]})
  var replaced=replacementPending
  snapshot={route:next,circuitId:String(c.circuitId||""),key:key,country:String(c.exitCountry||"")}
  replacementPending=false;failed=false
  if(replaced)replacementReady()
 }
 onConnectionChanged:synchronize()
 Component.onCompleted:synchronize()
}
