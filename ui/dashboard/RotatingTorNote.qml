import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
 id:root;objectName:"rotating-tor-note"
 property bool reducedMotion:false
 property bool active:false
 property bool paused:false
 property bool interactive:true
 property bool cyclingEnabled:true
 property int initialDelay:8000
 property int displayDuration:12000
 property bool showing:false
 property bool firstAppearance:true
 property bool shownOnce:false
 // Legacy style IDs 4–7 resolve to the four floating treatments.
 property int styleVariant:0
 readonly property int treatment:styleVariant%4
 readonly property real restingOpacity:treatment===3?.78:1
 readonly property int cycleInterval:interval<30000?45000:interval
 readonly property bool automaticReady:active&&visible&&interactive&&(showing||cyclingEnabled)&&!paused&&!viewing&&!actionBusy&&!actionRunning&&(!showing||(!hover.hovered&&!action.activeFocus))&&!crossfade.running&&!updateFade.running
 property real drift:0
 property real lightPhase:0
 readonly property bool lightAnimating:showing&&active&&visible&&!reducedMotion&&!paused&&(treatment===0||treatment===2)
 readonly property real lightLevel:reducedMotion?.65:lightPhase
 SequentialAnimation on lightPhase {
  running:root.lightAnimating;paused:running&&(hover.hovered||action.activeFocus);loops:Animation.Infinite
  NumberAnimation {from:0;to:1;duration:root.treatment===2?5000:3500;easing.type:Easing.InOutSine}
  NumberAnimation {from:1;to:0;duration:root.treatment===2?5000:3500;easing.type:Easing.InOutSine}
 }
 readonly property bool drifting:showing&&active&&visible&&!reducedMotion&&!paused&&treatment===1
 onStyleVariantChanged:if(!crossfade.running&&!updateFade.running)copy.opacity=restingOpacity
 SequentialAnimation on drift {
  running:root.drifting;paused:running&&(hover.hovered||action.activeFocus);loops:Animation.Infinite
  NumberAnimation {from:0;to:-10;duration:5000;easing.type:Easing.InOutSine}
  NumberAnimation {from:-10;to:0;duration:5000;easing.type:Easing.InOutSine}
 }
 // One timer alternates the reading window and quiet interval.
 Timer {
  id:cycle;objectName:"cycling-note-timer";interval:root.showing?root.displayDuration:root.firstAppearance?root.initialDelay:root.cycleInterval;repeat:true
  running:root.automaticReady
  onTriggered:{if(root.showing)root.hideNote();else root.showNote(root.shownOnce)}
 }
 onPhraseIndexChanged:if(automaticReady)cycle.restart()
 function restoreActionFocus(){if(showing)action.forceActiveFocus()}
 onPausedChanged:if(paused){crossfade.stop();updateFade.stop();applyPending();copy.opacity=restingOpacity}
 property bool actionEnabled:false
 property bool actionBusy:false
 property bool actionRunning:false
 property var builtCount:null
 property bool circuitsShown:false
 property bool sharingActive:false
 readonly property bool viewing:circuitsShown
 property var antipodeOrigin:({})
 property var antipodeResult:null
 property var onionEstimate:null
 onAllPhrasesChanged:if(phrasesReady)refreshPhrases()
 property bool phrasesReady:false
 onExitCountChanged:if(phrasesReady)refreshPhrases()
 onBuiltCountChanged:if(phrasesReady)refreshPhrases()
 onCircuitsShownChanged:if(phrasesReady)refreshPhrases()
 onSharingActiveChanged:if(phrasesReady)refreshPhrases()
 property int exitCount:0
 property int countryCount:0
 readonly property var allPhrases:[
  {number:1,metric:true,action:"illuminate",label:"Illuminate exit nodes"},
  {number:2,text:"An onion address contains the service’s public key.",action:"onion-address",label:"Look inside"},
  {number:3,text:"Onion connections meet inside Tor, without an exit relay.",action:"onion-meeting",label:"Show me"},
  {number:4,circuits:true,action:"local-circuits",label:"Show circuits"},
  {number:5,text:"Your file reaches its recipient through a meeting point inside Tor.",action:"file-transfer",label:"Show how"},
  {number:6,text:"Each relay removes one layer of Tor’s encryption.",action:"peel-layers",label:"Peel the layers"},
  {number:9,estimate:true,text:root.onionEstimate?root.onionEstimate.text:""},
  {number:10,text:"Tor Browser helps prevent tracking.",action:"browser-protections",label:"Details"},
  {number:11,text:"How fast is your connection through Tor?",action:"compare-speed",label:"Compare speed"},
  {number:12,text:"Snowflake volunteers help people reach Tor when access is blocked.",action:"snowflake",label:"Discover Snowflake"},
  {number:13,text:"At the end of 2003, Tor had roughly a dozen volunteer nodes.",sources:[{title:"Tor Project | History",url:"https://www.torproject.org/about/index"}]},
  {number:14,text:"Sites like Proton can tell Tor Browser about their .onion alternative.",action:"onion-location",label:"How?",sources:[{title:"Tor Project | Onion-Location",url:"https://community.torproject.org/onion-services/advanced/onion-location/"}]},
  {number:15,text:root.antipodeResult?"The farthest exit country from "+(root.antipodeOrigin.countryName||root.antipodeOrigin.country||"your country")+" is "+root.antipodeResult.winner.countryName+".":"Which country with running Tor exits is farthest from "+(root.antipodeOrigin.countryName||root.antipodeOrigin.country||"your country")+"?",action:"antipode",label:"Show search"}
 ]
 property var phrases:allPhrases.slice(1,4)
 property var pendingPhrases:null
 function applyPending(){
  if(!pendingPhrases)return
  var previous=phrase.number
  phrases=pendingPhrases;pendingPhrases=null
  var index=phrases.findIndex(function(p){return p.number===previous})
  phraseIndex=index>=0?index:Math.min(phraseIndex,phrases.length-1)
  if(!phrase.action)action.focus=false
 }
 function refreshPhrases(){
  var next=allPhrases.filter(function(p){return (!p.estimate||!!root.onionEstimate)&&(!p.metric||root.exitCount>0)&&(!p.circuits||root.builtCount>0||root.circuitsShown)})
  if(JSON.stringify(next)===JSON.stringify(phrases))return
  pendingPhrases=next
  if(phrase.estimate&&showing&&active&&!paused){if(!crossfade.running)updateFade.restart()}
  else applyPending()
 }
 Component.onCompleted:{phrases=allPhrases.filter(function(p){return (!p.estimate||!!root.onionEstimate)&&(!p.metric||root.exitCount>0)&&(!p.circuits||root.builtCount>0||root.circuitsShown)});phraseIndex=0;phrasesReady=true}
 property int phraseIndex:0
 readonly property var phrase:phrases[phraseIndex%phrases.length]
 property int alignment:Text.AlignHCenter
 property real textSize:12
 property int interval:45000
 property real actionScale:1
 property color cardDetail:ThemeColors.color("accent")
 property color ink:ThemeColors.color("uiMuted")
 signal actionTriggered(string action)
 implicitHeight:copyColumn.implicitHeight+22
 function advance(){if(active&&!paused&&!crossfade.running&&!updateFade.running)crossfade.start()}
 function showNote(advancePhrase){
  if(!active||!visible||paused)return
  applyPending()
  if(advancePhrase)phraseIndex=(phraseIndex+1)%phrases.length
  firstAppearance=false;shownOnce=true;showing=true
  cycle.restart()
 }
 function hideNote(){showing=false;action.focus=false}
 function next(){if(!showing)showNote(shownOnce);else advance()}
 function resetPresentation(){
  crossfade.stop();updateFade.stop();applyPending();copy.opacity=restingOpacity
  hideNote();firstAppearance=true
 }
 onActiveChanged:if(!active)resetPresentation()
 onVisibleChanged:if(!visible)resetPresentation()
 // Keep the reserved space stable while notes fade in and out.
 Item {
  id:presence;objectName:"cycling-note-presence";anchors.fill:parent
  opacity:root.showing?1:0;visible:opacity>0;enabled:root.showing
  Behavior on opacity {NumberAnimation {duration:root.reducedMotion||!root.active||!root.visible?0:700;easing.type:Easing.InOutSine}}
  HoverHandler {id:hover}
  Item {
   id:copy;anchors.fill:parent;opacity:root.restingOpacity
   MultiEffect {
    // Keep the real text visible even when effects are unavailable (software rendering).
    source:sentenceCopy;x:copyColumn.x;y:copyColumn.y;width:sentenceCopy.width;height:sentenceCopy.height
    objectName:"cycling-note-glow"
    visible:root.treatment!==3
    opacity:root.treatment===2?.75+.25*root.lightLevel:root.treatment===0?.3+.6*root.lightLevel:.35
    blurEnabled:true;blur:root.treatment===2?.5+.3*root.lightLevel:.16;blurMax:32
    brightness:root.treatment===2?.35:.15
    shadowEnabled:root.treatment===2;shadowColor:root.cardDetail;shadowOpacity:.9
    shadowBlur:.7;shadowHorizontalOffset:0;shadowVerticalOffset:0
    colorization:1;colorizationColor:root.cardDetail
   }
   MultiEffect {
    // A close glow preserves the shape of the letters inside Halo's broader light.
    source:sentenceCopy;x:copyColumn.x;y:copyColumn.y;width:sentenceCopy.width;height:sentenceCopy.height
    visible:root.treatment===2;opacity:.6+.3*root.lightLevel
    blurEnabled:true;blur:.12;blurMax:24;colorization:1;colorizationColor:root.cardDetail
   }
   Column {
    id:copyColumn;anchors.centerIn:parent
    anchors.verticalCenterOffset:root.drifting?root.drift+5:0
    anchors.horizontalCenterOffset:root.drifting?root.drift*.4+2:0
    width:Math.max(48,parent.width-24);spacing:10
    Text {
     id:sentenceCopy;objectName:"cycling-tor-copy";width:parent.width
     readonly property string sentence:root.phrase.circuits?(root.builtCount===null?"Local Tor circuit data is unavailable.":"Your Tor instance currently has "+root.builtCount+" built circuit"+(root.builtCount===1?".":"s.")):root.phrase.metric?(root.exitCount>0?root.exitCount.toLocaleString(Qt.locale(),"f",0)+" exit nodes across "+root.countryCount+" countries.":"Exit relay data is unavailable."):(root.phrase.text||"")
     // Temporary review numbers use stable IDs, even when some notes are hidden.
     text:"#"+root.phrase.number+" · "+sentence;Accessible.name:text
     color:root.ink;opacity:root.treatment===0?.65+.35*root.lightLevel:root.treatment===2?.75+.25*root.lightLevel:1
     font.pixelSize:ThemeDesign.px(root.textSize);font.family:ThemeDesign.fontFamily
     lineHeight:1.25
     horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap

    }
    Button {
     id:action;objectName:"cycling-tor-action";visible:!root.circuitsShown&&!!root.phrase.action&&(!root.phrase.circuits||root.builtCount>=1||root.circuitsShown)
     x:(parent.width-width)/2;width:34*root.actionScale;height:34*root.actionScale;padding:0
     hoverEnabled:root.interactive;focusPolicy:root.interactive?Qt.StrongFocus:Qt.NoFocus
     enabled:!root.paused&&(root.phrase.action!=="illuminate"||(root.actionEnabled&&!root.actionBusy))
     readonly property bool animating:root.showing&&!root.reducedMotion&&root.active&&!root.paused&&root.interactive&&enabled&&visible
     property real breath:0
     Accessible.name:root.phrase.label||""
     onClicked:if(root.interactive)root.actionTriggered(root.phrase.action)
     background:Item {}
     contentItem:Item {
      NoteActionGlyph {
       objectName:"cycling-action-glyph";anchors.centerIn:parent;width:22;height:22
       action:root.phrase.action||""
       ink:root.ink;accent:ThemeColors.color("uiAccent")
       glow:action.enabled&&(action.hovered||action.activeFocus)?1:0
       opacity:action.enabled?(action.hovered||action.activeFocus?1:root.reducedMotion?.85:.60+.25*action.breath):.35
       scale:root.actionScale*(action.down?.94:action.hovered||action.activeFocus?1.12:1)
       Behavior on scale {NumberAnimation {duration:root.reducedMotion?0:220;easing.type:Easing.OutCubic}}
      }
     }
     TorToolTip {cornerRadius:2;visible:action.hovered||action.visualFocus;below:true;text:root.phrase.label||"";ink:root.ink;accent:ThemeColors.color("uiAccent")}
     SequentialAnimation on breath {
      running:action.animating;loops:Animation.Infinite
      NumberAnimation {from:0;to:1;duration:1200;easing.type:Easing.InOutSine}
      NumberAnimation {from:1;to:0;duration:1200;easing.type:Easing.InOutSine}
     }
    }
   }
  }
 }
 SequentialAnimation {
  id:crossfade
  NumberAnimation {target:copy;property:"opacity";to:0;duration:root.reducedMotion?0:450;easing.type:Easing.InOutSine}
  ScriptAction {script:{action.focus=false;root.applyPending();root.phraseIndex=(root.phraseIndex+1)%root.phrases.length}}
  NumberAnimation {target:copy;property:"opacity";to:root.restingOpacity;duration:root.reducedMotion?0:650;easing.type:Easing.InOutSine}
 }
 SequentialAnimation {
  id:updateFade
  NumberAnimation {target:copy;property:"opacity";to:0;duration:root.reducedMotion?0:450}
  ScriptAction {script:root.applyPending()}
  NumberAnimation {target:copy;property:"opacity";to:root.restingOpacity;duration:root.reducedMotion?0:650}
 }
}
