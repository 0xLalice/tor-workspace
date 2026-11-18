import ".."
import QtQuick
import "Antipode.js" as Search

Item {
 id:root;objectName:"antipode-controller"
 property var globe:null
 property var origin:({})
 readonly property string originKey:JSON.stringify([origin.country,origin.countryName,origin.latitude,origin.longitude])
 property bool active:false
 property bool reducedMotion:false
 property bool showing:false
 property bool loading:false
 property var result:null
 property var snapshot:null
 property var frozenOrigin:null
 property int revision:0
 property real elapsed:0
 property string error:""
 readonly property int stage:elapsed<1?0:elapsed<4?1:2
 readonly property string caption:["Your country","Comparing countries with running exits","Farthest country with running exits"][stage]
 signal requested(bool refresh,int revision)
 signal closed()
 onOriginKeyChanged:{close();result=null;snapshot=null;revision++}
 onActiveChanged:if(!active)close()
 onReducedMotionChanged:if(showing&&result&&reducedMotion){elapsed=4;globe.restoreAntipodePose()}
 function open(refresh) {
  if(!active||loading)return
  if(!showing){showing=true;globe.beginAntipode();forceActiveFocus()}
  if(!Search.valid(origin)){error="Country location unavailable.";return}
  frozenOrigin=JSON.parse(JSON.stringify(origin));error=""
  loading=true;revision++;requested(!!refresh,revision)
 }
 function receive(value,token) {
  if(token!==revision||!showing)return
  loading=false
  if(!value||!value.countries){
   error=(value&&value.error)||"Exit countries unavailable."
   if(snapshot){snapshot=Object.assign({},snapshot,{stale:true,error:error});play()}
   return
  }
  snapshot=JSON.parse(JSON.stringify(value));play()
 }
 function play() {
  var next=Search.calculate(frozenOrigin,snapshot)
  if(!next){error="No countries with running exits available.";return}
  result=next;error="";elapsed=reducedMotion?4:0
  updateCamera()
 }
 function replay(){if(result&&!loading){elapsed=reducedMotion?4:0;updateCamera()}}
 function close() {
  revision++;loading=false
  if(!showing)return
  globe.endAntipode();showing=false;closed()
 }
 function advance(dt){if(!result||loading||error||elapsed>=4)return;elapsed=Math.min(4,elapsed+dt);updateCamera()}
 function updateCamera() {
  if(!globe||!result||reducedMotion)return
  var o=result.origin,w=result.winner,u=Math.max(0,Math.min(1,(elapsed-1)/3));u=u*u*(3-2*u)
  var delta=((o.longitude-w.longitude+540)%360)-180
  globe.longitude=-o.longitude+delta*u
  globe.latitude=o.latitude+(w.latitude-o.latitude)*u
  globe.viewRoll=-globe.axialTilt;globe.temporaryZoom=.88
 }
 FrameAnimation {running:root.showing&&root.active&&!root.loading&&!!root.result&&!root.error&&root.elapsed<4;onTriggered:root.advance(Math.min(frameTime,.1))}
}
