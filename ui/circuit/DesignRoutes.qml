import ".."
import QtQuick
import "TransitionGeometry.js" as Mesh
Item {
 id:root
 property var route:[]
 property string circuitId:""
 property real longitude:0
 property real latitude:0
 property real globeSize:400
 property bool active:false
 property bool reducedMotion:false
 property var settings:({})
 property int retainedMaterialKind:1
 readonly property int materialKind:ThemeDesign.definition.circuitRenderer==="material"?(settings.circuitMaterial||ThemeDesign.definition.circuitMaterial):retainedMaterialKind
 readonly property color primary:settings.circuitPrimary||ThemeColors.color("diagramAccent")
 readonly property color secondary:settings.circuitSecondary||ThemeColors.color("diagramInk")
 readonly property color highlight:settings.circuitHighlight||ThemeColors.color("spaceStar")
 property var accepted:[]
 property var outgoing:[]
 property string acceptedKey:""
 property real clock:0
 property real elapsed:0
 property real outgoingEpoch:0
 property real outgoingFront:0
 property bool building:false
 property bool retiring:false
 property int paintCount:0
 property int completedPaintCount:0
 readonly property bool nativeReady:painter.status===Loader.Ready
 readonly property bool established:!building&&accepted.length>1
 readonly property var angles:[]
 // A palette swap changes lighting, not the geometry of an accepted route.
 property real acceptedHeight:.18
 readonly property real routeHeight:accepted.length?acceptedHeight:(ThemeColors.treatment.circuitLift===undefined?.18:Math.max(0,Math.min(1,ThemeColors.treatment.circuitLift)))
 readonly property var mesh:Mesh.prepare(Mesh.build(accepted,routeHeight,1,materialKind===1?.55:.8),angles)
 readonly property var oldMesh:Mesh.prepare(Mesh.build(outgoing,routeHeight,1,materialKind===1?.55:.8),angles)
 readonly property real buildDuration:ThemeDesign.definition.build
 readonly property real retireDuration:ThemeDesign.definition.retire
 property bool dirty:true
 function descriptor(){if(nativeReady)painter.item.setDesign(materialKind,secondary,primary,highlight);dirty=true}
 onMaterialKindChanged:{if(ThemeDesign.definition.circuitRenderer==="material")retainedMaterialKind=materialKind;descriptor()}
 onPrimaryChanged:descriptor()
 onSecondaryChanged:descriptor()
 onHighlightChanged:descriptor()
 function geometry(){if(nativeReady){painter.item.setGeometry(0,oldMesh);painter.item.setGeometry(1,mesh)}dirty=true}
 function synchronize(){
  var key=circuitId+":"+JSON.stringify(route.map(function(h){return [h.fingerprint||h.ip||"",h.longitude,h.latitude]}))
  if(key===acceptedKey)return
  acceptedHeight=ThemeColors.treatment.circuitLift===undefined?.18:Math.max(0,Math.min(1,ThemeColors.treatment.circuitLift))
  outgoingEpoch=clock;outgoingFront=building?elapsed/buildDuration*accepted.length:accepted.length
  outgoing=active&&visible&&!reducedMotion?accepted:[];retiring=outgoing.length>1
  accepted=route.length>1?JSON.parse(JSON.stringify(route)):[];acceptedKey=key
  elapsed=0;building=active&&visible&&!reducedMotion&&accepted.length>1;clock=0;dirty=true
 }
 function clear(){accepted=[];outgoing=[];acceptedKey="";building=false;retiring=false;elapsed=0;clock=0;outgoingEpoch=0;outgoingFront=0;if(nativeReady)painter.item.clearGeometry();dirty=true}
 onRouteChanged:Qt.callLater(synchronize)
 onCircuitIdChanged:Qt.callLater(synchronize)
 onMeshChanged:geometry()
 onOldMeshChanged:geometry()
 onLongitudeChanged:dirty=true
 onLatitudeChanged:dirty=true
 onGlobeSizeChanged:dirty=true
 onWidthChanged:dirty=true
 onHeightChanged:dirty=true
 onVisibleChanged:if(visible){synchronize();dirty=true}else{outgoing=[];retiring=false;building=false}
 onReducedMotionChanged:if(reducedMotion){outgoing=[];building=false;retiring=false;dirty=true}
 Connections {target:ThemeColors;function onPaletteChanged(){root.descriptor()}function onOverridesChanged(){root.descriptor()}}
 Connections {target:ThemeDesign;function onDesignChanged(){root.descriptor()}}
 NativeCircuitLoader {id:painter;anchors.fill:parent;active:root.visible&&RenderCapabilities.nativeReady;onLoaded:{item.antialiasing=true;root.descriptor();root.geometry();root.dirty=true}}
 Connections {target:painter.item;function onFramePainted(){root.completedPaintCount++}}
 function paint(){
  if(!nativeReady||!visible)return
  var p=painter.item;p.reset();p.translate((width-globeSize)/2,(height-globeSize)/2)
  p.beginFrame(longitude,latitude,globeSize,retiring,accepted.length>1)
  if(retiring)p.drawDesign(0,clock+outgoingEpoch,outgoingFront,elapsed/retireDuration,true)
  if(accepted.length>1)p.drawDesign(1,clock,building?elapsed/buildDuration*accepted.length:accepted.length,0,false)
  p.finishFrame();paintCount++;dirty=false
 }
 onDirtyChanged:if(dirty&&!active)Qt.callLater(paint)
 FrameAnimation {running:root.active&&root.visible&&(root.dirty||(!root.reducedMotion&&(root.accepted.length>1||root.retiring)))
  onTriggered:{if(!root.reducedMotion){root.clock+=Math.min(frameTime,.05);root.elapsed+=Math.min(frameTime,.05);if(root.elapsed>=root.buildDuration)root.building=false;if(root.retiring&&root.elapsed>=root.retireDuration){root.outgoing=[];root.retiring=false}root.dirty=true}if(root.dirty)root.paint()}}
 Component.onCompleted:Qt.callLater(synchronize)
}
