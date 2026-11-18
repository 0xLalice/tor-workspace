import ".."
import QtQuick
import QtQuick.Controls
import "../theme/EffectSettings.js" as Effects
Item {
 id:root
 property int appearance:0
 property var route:[]
 property color ink:ThemeColors.color("foreground")
 property color accent:ThemeColors.color("accent")
 property bool canChange:false
 property bool busy:false
 property int cooldown:0
 property string statusDetail:""
 property string state:"starting"
 property bool pickerEnabled:false
 property var exitCountries:[]
 property string exitCountry:""
 property alias countryPicker:countrySelector
 property Item pickerLayer:null
 signal exitCountryChosen(string code)
 signal exitCountryPinned(string code)
 signal newCircuit()
 property var hops:[]
 property bool revealed:false
 function syncRoute(){
  var next=route.length>1?route.slice(1):[]
  if(JSON.stringify(next)===JSON.stringify(hops)&&revealed)return
  clearHops.stop()
  if(next.length){
   revealed=false;hops=next
   Qt.callLater(function(){if(root.route.length>1)root.revealed=true})
  }else{revealed=false;clearHops.restart()}
 }
 onRouteChanged:syncRoute()
 Component.onCompleted:syncRoute()
 Timer {id:clearHops;interval:650+Math.max(0,root.hops.length-1)*250;onTriggered:if(!root.route.length)root.hops=[]}
 // Ten compact treatments: hairline, indexed, pills, brackets, nodes,
 // capsule, lights, ribbons, itinerary, atlas ticks.
 readonly property var treatment:[
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:true,code:false,number:false,separator:"·",button:"text"},
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:true,code:false,number:true,separator:"/",button:"outline"},
  {radius:ThemeDesign.radius(12),fill:0.10,border:0,line:false,code:false,number:false,separator:"",button:"pill"},
  {radius:ThemeDesign.radius(2),fill:0.05,border:0.35,line:false,code:true,number:true,separator:"›",button:"bracket"},
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:true,code:false,number:true,separator:"·",button:"outline"},
  {radius:ThemeDesign.radius(10),fill:0.04,border:0.20,line:false,code:false,number:false,separator:"›",button:"pill"},
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:false,code:false,number:false,separator:"·",button:"text"},
  {radius:ThemeDesign.radius(3),fill:0.07,border:0,line:true,code:false,number:false,separator:"",button:"text"},
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:false,code:true,number:false,separator:"→",button:"pill"},
  {radius:ThemeDesign.radius(0),fill:0,border:0,line:true,code:false,number:true,separator:"|",button:"outline"}
 ][Math.max(0,Math.min(9,appearance))]
 height:24
 Row {
  id:chain
  HoverHandler {id:chainHover}
  CircuitToolTip {route:root.route;hovered:chainHover.hovered||countrySelector.hovered;exitAction:countrySelector.hovered;ink:root.ink;accent:root.accent}
  width:parent.width;height:25;spacing:8
  Repeater {
   model:root.hops
   delegate:Rectangle {
    id:hop
    required property var modelData
    required property int index
    width:(chain.width-Math.max(0,root.hops.length-1)*chain.spacing)/Math.max(1,root.hops.length)
    height:24;radius:root.treatment.radius
    opacity:root.revealed?1:0
    Behavior on opacity {SequentialAnimation {PauseAnimation {duration:hop.index*250} NumberAnimation {duration:600;easing.type:Easing.InOutQuad}}}
    color:"transparent"
    border.width:root.treatment.border>0?1:0
    border.color:Qt.rgba(root.accent.r,root.accent.g,root.accent.b,root.treatment.border)
    readonly property string country:modelData.countryName||modelData.country||"Unknown"
    readonly property string role:index===0?"Entry":index===root.hops.length-1?"Exit":"Relay"
    Accessible.role:Accessible.StaticText
    Accessible.name:role+": "+country
    Text {
     visible:!root.pickerEnabled||hop.index!==root.hops.length-1
     anchors.centerIn:parent;width:parent.width-12
     text:(root.treatment.number?"0"+(hop.index+1)+"  ":root.appearance===6?"·  ":"")+(root.treatment.code?(hop.modelData.country||"??"):hop.country)
     horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
     color:root.ink;opacity:0.8
     font.family:ThemeDesign.fontFamily
     font.pixelSize:ThemeDesign.px(root.treatment.code?10:9)
     font.letterSpacing:root.treatment.code?1:0
    }
    Rectangle {
     visible:root.treatment.line;anchors.bottom:parent.bottom
     x:root.appearance===9?8:0;width:parent.width-2*x;height:1
     color:root.accent;opacity:root.appearance===7?0.35:0.16
    }
    Text { visible:hop.index<root.hops.length-1;x:parent.width;y:5;width:8;text:root.treatment.separator;color:root.accent;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);horizontalAlignment:Text.AlignHCenter }

   }
  }
 }
 ExitCountryPicker {
  id:countrySelector;sharedTooltip:true;objectName:"exit-country-selector";z:20
  parent:root.pickerLayer||root
  visible:root.pickerEnabled
  readonly property int hopCount:root.hops.length||3
  width:(chain.width-(hopCount-1)*chain.spacing)/hopCount
  x:(root.pickerLayer?root.x:0)+root.width-width
  y:root.pickerLayer?root.y:0;height:24
  countries:root.exitCountries;country:root.exitCountry
  readonly property var exitHop:root.route.length>1?root.route[root.route.length-1]:({})
  observedCountry:exitHop.country||""
  closedLabel:(root.treatment.number?"0"+hopCount+"  ":root.appearance===6?"·  ":"")+(root.exitCountry|| (root.treatment.code?(exitHop.country||"AUTO"):(exitHop.countryName||exitHop.country||"Automatic")))
  labelSize:root.treatment.code?10:9;labelSpacing:root.treatment.code?1:0
  ink:root.ink;accent:root.accent
  onChosen:function(code){root.exitCountryChosen(code)}
  onPinRequested:code=>root.exitCountryPinned(code)
 }
}
