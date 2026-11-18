import ".."
import QtQuick
import QtQuick.Controls

Item {
 id:root
 property int variant:0
 property bool orbitLayout:false
 property real orbitBottom:0
 property bool reducedMotion:false
 property bool active:false
 property real uiScale:1
 property color cardDetail:ThemeColors.color("accent")
 property bool cyclingEnabled:true
 property bool illuminating:false
 property bool illuminationRunning:false
 property var network:({})
 signal illuminate()
 signal explanationRequested(string topic)
 property var antipodeOrigin:({})
 property var antipodeResult:null
 property var onionEstimate:null
 property var builtCount:null
 property bool circuitsShown:false
 property bool sharingActive:false
 property bool explanationOpened:false
 function restoreNoteFocus(){note.restoreActionFocus()}
 function nextPhrase(){note.next()}
 readonly property int treatment:variant<9?variant:({9:1,10:2,11:7,12:1,13:4,14:7})[variant]||1
 // Cycling copy has one responsive layout, independent of scene scale and theme.
 readonly property var noteLayout:({x:Math.min(60,Math.max(16,(width-280)/3)),y:height-75,w:width-2*Math.min(60,Math.max(16,(width-280)/3)),align:Text.AlignHCenter})
 readonly property real noteTop:note.y
 property var route:[]
 property string state:"offline"
 property bool torRunning:false
 property bool busy:false
 property bool canChange:false
 property int cooldown:0
 property var countries:[]
 property string country:""
 property bool pickerEnabled:true
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property color surface:ThemeColors.color("dark_background")
 signal renew()
 signal countryChosen(string code)
 signal countryPinned(string code)
 property bool exitHovered:false
 readonly property var hops:route.length>1?route.slice(1):[]
 readonly property bool vertical:treatment===3||treatment===7
 readonly property bool orbital:treatment===4||treatment===6
 readonly property bool fetching:busy||state==="starting"||state==="busy"
 readonly property bool actionable:canChange&&!fetching&&cooldown===0
 visible:variant>0
 RotatingTorNote {id:note;visible:root.torRunning;enabled:root.torRunning;antipodeOrigin:root.antipodeOrigin;antipodeResult:root.antipodeResult;styleVariant:2;reducedMotion:root.reducedMotion;onionEstimate:root.onionEstimate;sharingActive:root.sharingActive;builtCount:root.builtCount;circuitsShown:root.circuitsShown;cyclingEnabled:root.cyclingEnabled;paused:root.explanationOpened;exitCount:root.network.count||0;countryCount:root.network.countries||0;actionEnabled:root.torRunning;actionBusy:root.illuminating;actionRunning:root.illuminationRunning;onActionTriggered:action=>{if(action==="illuminate")root.illuminate();else root.explanationRequested(action)};x:root.noteLayout.x;y:Math.max(0,Math.min(root.noteLayout.y,root.height-height-8));width:root.noteLayout.w;height:Math.max(70,implicitHeight);alignment:root.noteLayout.align;cardDetail:root.cardDetail;textSize:11.5;actionScale:1.15;interval:60000;active:root.active&&root.torRunning;ink:root.ink}
 Item {
  HoverHandler {id:railHover}
  CircuitToolTip {route:root.route;hovered:rail.visible&&((railHover.hovered&&!action.hovered)||root.exitHovered);exitAction:root.exitHovered;ink:root.ink;accent:root.accent}
  id:rail;objectName:"circuit-rail";visible:root.torRunning
  scale:root.uiScale;transformOrigin:Item.TopLeft
  width:root.variant===12?210:root.vertical?52:root.treatment===5?root.width:root.treatment===8?174:root.orbital?234:210
  height:root.vertical?184:root.treatment===5?80:root.orbital?100:64
  x:root.variant===12?0:root.treatment===7?root.width-width*root.uiScale:root.vertical?0:(root.width-width*root.uiScale)/2
  y:root.orbitLayout?root.orbitBottom+16:root.variant===9?root.height-height*root.uiScale-82:root.variant===10?126:root.variant===12?root.height-height*root.uiScale-24:root.variant===13?root.height-height*root.uiScale-84:root.treatment===2?42:root.treatment===6?126:root.vertical?(root.height-height*root.uiScale)/2:root.height-height*root.uiScale
  Repeater {
   model:root.hops
   delegate:Item {
    id:hop
    required property int index
    required property var modelData
    width:52;height:30
    x:root.vertical?0:root.treatment===5?(rail.width-52)*index/Math.max(1,root.hops.length-1):root.orbital?13+index*78:(rail.width-root.hops.length*60+8)/2+index*60
    y:root.vertical?index*44:root.orbital?(index===1?0:18):root.treatment===8?Math.abs(index-1)*9:0
    opacity:0
    Component.onCompleted:fade.start()
    SequentialAnimation {id:fade;PauseAnimation {duration:hop.index*150}NumberAnimation {target:hop;property:"opacity";to:1;duration:500}}
    Text {visible:hop.index!==root.hops.length-1;anchors.centerIn:parent;text:hop.modelData.country||"??";font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(root.variant===3?12:10);font.letterSpacing:1;color:root.ink}
   }
  }
  Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
   id:action;objectName:"lab-circuit-action"
   width:32;height:28
   x:(rail.width-width)/2
   y:root.vertical?138:root.orbital?66:root.treatment===5?44:36
   enabled:root.actionable;hoverEnabled:true
   Accessible.name:"Request a new Tor circuit"
   onClicked:root.renew()
   background:Item {}
   contentItem:Item {
    id:renewGlyph;objectName:"circuit-renew-glyph"
    readonly property bool fetching:root.fetching
    readonly property bool spinning:root.active&&root.visible&&fetching&&!root.reducedMotion
    onSpinningChanged:if(!spinning)rotation=0
    NumberAnimation on rotation {
     running:renewGlyph.spinning
     from:0;to:360;duration:1100;loops:Animation.Infinite
    }
    ActionGlyph {objectName:"circuit-renew-icon";anchors.centerIn:parent;width:20;height:20;kind:"refresh";ink:root.ink;accent:root.accent}
    scale:action.down?.94:1
    Behavior on scale {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
    opacity:action.enabled?(action.hovered||action.activeFocus?1:.85):.35
   }
   TorToolTip {visible:action.hovered;text:"New circuit";detail:root.fetching?"Request in progress":root.cooldown?"New circuit temporarily unavailable":"Request a different route through Tor";ink:root.ink;accent:root.accent}
  }
 }

 // Country restrictions must remain editable without a usable circuit.
 ExitCountryPicker {
  objectName:"interface-exit-country-selector"
  sharedTooltip:true;onHoveredChanged:root.exitHovered=hovered
  z:20;transformOrigin:Item.TopLeft;scale:root.uiScale
  readonly property int hopCount:root.hops.length||3
  readonly property int exitIndex:hopCount-1
  readonly property var exitHop:root.hops.length?root.hops[exitIndex]:({})
  x:rail.x+(root.vertical?0:root.treatment===5?rail.width-52:root.orbital?13+exitIndex*78:(rail.width-hopCount*60+8)/2+exitIndex*60)*root.uiScale
  y:rail.y+(root.vertical?exitIndex*44:root.orbital?(exitIndex===1?0:18):root.treatment===8?Math.abs(exitIndex-1)*9:0)*root.uiScale
  width:52;height:30
  labelSize:root.variant===3?12:10;sidePicker:root.vertical;openToLeft:root.treatment===7;visible:rail.visible
  enabled:root.pickerEnabled;countries:root.countries;country:root.country
  observedCountry:exitHop.country||"";closedLabel:root.country||exitHop.country||"AUTO";ink:root.ink;accent:root.accent
  onChosen:code=>root.countryChosen(code)
  onPinRequested:code=>root.countryPinned(code)
 }

}
