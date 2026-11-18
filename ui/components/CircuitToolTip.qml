import ".."
import QtQuick

TorToolTip {
 id:root
 property bool hovered:false
 property bool exitAction:false
 property bool held:false
 onHoveredChanged:{if(hovered){dismiss.stop();held=true}else dismiss.restart()}
 Timer {id:dismiss;interval:120;onTriggered:root.held=false}
 visible:held&&relays.length>0
 property var route:[]
 readonly property var relays:route.filter(h=>h.role!=="You"&&h.role!=="Origin").slice(-3)
 text:"Last observed route · "+relays.map(h=>h.country||"??").join(" → ")
 detail:relays.map((h,i)=>(h.country||"??")+" · "+(i===0?"Guard: knows your IP":i===relays.length-1?"Exit: connects to the website":"Middle: separates guard and exit")).join("\n")+(exitAction?"\nChoose country · lock exit":"")
}
