import ".."
import QtQuick

EmberTransition {
 id:root
 property var verifiedRoute:[]
 property string circuitId:""
 property string acceptedKey:""
 property bool initialized:false
 property bool animateInitialRoute:false
 property var acceptedRoute:[]
 property bool retiring:false
 function clearRoute(){
  retiring=false;acceptedKey="";acceptedRoute=[];oldRoute=[];newRoute=[]
  initialized=false;transitioning=false;clock=0
 }
 function synchronize(){
  if(verifiedRoute.length<2){
   if(retiring)return
   if(animateInitialRoute&&acceptedRoute.length>1&&animating&&visible){
    oldWasRevealed=transitioning
    oldEpoch=transitioning?Math.max(0,clock-birthStart):clock
    oldRoute=acceptedRoute;newRoute=[];acceptedRoute=[];acceptedKey=""
    clock=0;transitioning=true;retiring=true
   }else clearRoute()
   return
  }
  retiring=false
  var key=circuitId+":"+JSON.stringify(verifiedRoute.map(function(h){return [h.fingerprint||h.ip||"",h.longitude,h.latitude]}))
  if(key===acceptedKey)return
  var next=JSON.parse(JSON.stringify(verifiedRoute))
  if((initialized||animateInitialRoute)&&animating&&visible){
   oldWasRevealed=transitioning
   oldRoute=acceptedRoute;newRoute=next
   oldEpoch=transitioning?Math.max(0,clock-birthStart):clock
   clock=0;transitioning=true
  }else{
   oldWasRevealed=false
   oldRoute=next;newRoute=[];clock=0;oldEpoch=0;transitioning=false
  }
  acceptedRoute=next;acceptedKey=key;initialized=true
 }
 onVerifiedRouteChanged:Qt.callLater(synchronize)
 onCircuitIdChanged:Qt.callLater(synchronize)
 Component.onCompleted:Qt.callLater(synchronize)
 function advance(dt){
  if(animating&&visible){
   clock+=dt
   if(retiring&&clock>=retirementLifetime)clearRoute()
  }
 }
 onAnimatingChanged:if(!animating&&retiring)clearRoute()
}
