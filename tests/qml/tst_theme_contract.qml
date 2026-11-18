import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/BuiltinThemes.js" as Builtins
import "../../ui/theme/EffectSettings.js" as Effects
import "../../ui/dashboard/ActionCatalog.js" as Actions

TestCase {
 id:test;name:"ThemeContract";when:windowShown;visible:true;width:460;height:688
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;active:true;torRunning:true;state:"ready"
  showPowerControls:true;showLaunchControls:true;installationReady:true
  availableThemes:Builtins.entries
 }
 SignalSpy {id:browserLaunch;target:panel;signalName:"launchBrowser"}
 SignalSpy {id:renew;target:panel;signalName:"newCircuit"}
 function clone(value){return JSON.parse(JSON.stringify(value))}
 function third(){
  var preset=clone(Builtins.entries[0]);preset.id="additional-theme";preset.name="Additional theme"
  preset.interface.design=preset.id
  // Deliberately combine the arc layout with Classic's globe, circuit and palette.
  preset.interface.style.actionLayout="arc"
  preset.interface.style.padding=18;preset.interface.style.radiusBoost=3
  return preset
 }
 function apply(preset){
  var value=Effects.snapshot(preset)
  panel.appearance=value.appearance;panel.interfaceSettings=Object.assign({},value.interface,{reducedMotion:true})
  panel.effectSettings=Tor.ThemeColors.resolveData(value.settings)
 }
 function init(){
  failOnWarning(/.*/);Tor.RenderCapabilities.nativeReady=true
  panel.torRunning=true;panel.serviceAvailable=true;panel.hostState={state:"idle"};panel.chatState={state:"idle"}
  panel.shareState={api:2,shares:[],readyCount:0};browserLaunch.clear();renew.clear()
 }
 function cleanup(){panel.closePresentation();Tor.ThemeDesign.fontScale=1;Tor.ThemeDesign.fontSizes={};Tor.ThemeDesign.apply({})}
 function button(kind){return findChild(panel,(panel.orbitLayout?"orbit-":"launch-tor-")+kind)}
 function test_new_identity_combines_renderers_without_feature_code(){
  var preset=third();apply(preset);wait(20)
  verify(panel.orbitLayout);compare(Tor.ThemeDesign.design,"additional-theme")
  compare(Tor.ThemeColors.orbitMix,1);compare(Tor.ThemeColors.circuitMix,0)
  compare(Tor.ThemeDesign.definition.spaceStyle,0);compare(Tor.ThemeDesign.padding,18)
  mouseClick(button("browser"));compare(browserLaunch.count,1);compare(renew.count,0)
  // Ten more identities use exactly the same rendering and feature path.
  var endpoint=JSON.stringify(Tor.ThemeColors.endpointAppearance)
  for(var i=0;i<10;i++){
   preset.id="extra-"+i;preset.interface.design=preset.id;apply(preset)
   compare(JSON.stringify(Tor.ThemeColors.endpointAppearance),endpoint)
   compare(button("share").descriptor.title,"Share a file")
  }
 }
 function test_content_and_cycling_geometry_are_shared(){
  var baseline=null
  for(var preset of [Builtins.entries[0],Builtins.entries[1],third()]){
   apply(preset);wait(20)
   var note=findChild(panel,"rotating-tor-note"),copy=findChild(note,"cycling-tor-copy"),action=findChild(note,"cycling-tor-action"),glyph=findChild(note,"cycling-action-glyph")
   var value={phrases:JSON.stringify(note.allPhrases),width:note.width,x:note.x,y:note.y,font:copy.font.family,size:copy.font.pixelSize,
    actionSize:action.width,treatment:note.treatment,interval:note.cycleInterval,initial:note.initialDelay,duration:note.displayDuration,
    glyphWidth:glyph.drawingWidth,actions:JSON.stringify(panel.dashboardActions)}
   if(baseline)compare(value,baseline);else baseline=value
  }
 }
 function test_shared_actions_and_status_data(){return [{tag:"flow",preset:Builtins.entries[0]},{tag:"arc",preset:Builtins.entries[1]},{tag:"additional",preset:third()}]}
 function test_shared_actions_and_status(data){
  apply(data.preset);wait(20)
  for(var kind of Actions.networkKinds){verify(button(kind).enabled);compare(button(kind).descriptor,panel.dashboardActions[kind])}
  var share=button("share");share.forceActiveFocus()
  panel.shareState={api:2,shares:[{id:"one",state:"ready"}],readyCount:1}
  compare(button("share"),share);verify(share.activeFocus);verify(share.serviceActive)
  verify(findChild(share,share.activityObjectName).visible)
  compare(share.descriptor.detail,"File sharing is active. Manage links or stop sharing.")
  panel.hostState={state:"ready",source:{mode:"app"}}
  verify(!button("website").enabled);compare(button("website").descriptor.detail,"Stop app publishing first.")
  verify(button("app").enabled)
  panel.torRunning=false
  for(var kind of Actions.networkKinds)verify(!button(kind).enabled)
  verify(findChild(panel,"tor-card-options").enabled);verify(findChild(panel,"tor-card-themes").enabled)
  panel.torRunning=true;panel.serviceAvailable=false
  for(var kind of Actions.networkKinds)verify(!button(kind).enabled)
  compare(browserLaunch.count,0);compare(renew.count,0)
 }
 function test_invalid_presentation_is_rejected(){
  for(var style of [null,[],{actionLayout:"unknown"},{enabled:true},{title:"New wording"},{fontFamily:"fixed"},{build:-1},{outline:0.5},{padding:true},{cameraBlend:Infinity}]){
   var rejected=false;try{Effects.interfaceConfig({design:"extra",style:style})}catch(e){rejected=true}verify(rejected,JSON.stringify(style))
  }
 }
}
