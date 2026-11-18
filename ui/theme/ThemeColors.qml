import ".."
pragma Singleton
import QtQuick
import "ColorRoles.js" as Roles
import "ColorProfiles.js" as Profiles
import "AppearanceBlend.js" as Blend
QtObject {
 id:root
 property var palette:Roles.jade
 readonly property var effectivePalette:Object.assign({},Roles.jade,palette)
 property var overrides:({})
 readonly property string themeId:palette.themeId||"custom"
 readonly property string themeName:palette.themeName||themeId
 readonly property var treatment:(Profiles.designs[themeId]||{})[ThemeDesign.definition.paletteProfile]||({})
 readonly property var chrome:Profiles.chrome[themeId]||Profiles.chrome.default
 readonly property bool jade:Object.keys(Roles.jade).every(function(key){return String(effectivePalette[key]).toLowerCase()===String(Roles.jade[key]).toLowerCase()})
 readonly property var roleNames:Object.keys(Roles.jade).filter(k=>k!=="mode").concat(Object.keys(Roles.extensions),Object.keys(Roles.derived),["uiText","uiMuted","uiHeading","uiAccent","uiBorder","uiSelectionText"])
 // Only the visible runtime enables motion; startup uses exact endpoints.
 property bool animationEnabled:false
 property bool paletteInitialized:false
 property bool immediatePalette:false
 property var settingsSource:({})
 property var auxiliarySource:({})
 property var blendState:null
 readonly property var fromAppearance:blendState?blendState.from:null
 readonly property var toAppearance:blendState?blendState.to:null
 property real transitionProgress:1
 readonly property bool transitioning:transition.running
 readonly property var endpointAppearance:resolveAppearance()
 readonly property var displayedAppearance:blendState?guardAppearance(Blend.blend(blendState.from,blendState.to,transitionProgress,"$")):(lastAppearance||endpointAppearance)
 readonly property var displayedSettings:displayedAppearance.settings
 readonly property var displayedAuxiliary:displayedAppearance.auxiliary
 readonly property var visualTreatment:displayedAppearance.treatment
 readonly property real voidMix:displayedAppearance.voidMix
 readonly property var voidWeights:displayedAppearance.voidWeights
 readonly property real circuitMix:displayedAppearance.circuitMix
 readonly property real orbitMix:displayedAppearance.orbitMix
 property NumberAnimation transition:NumberAnimation {
  target:root;property:"transitionProgress";from:0;to:1;duration:3000;easing.type:Easing.InOutCubic
  onFinished:{if(root.blendState)root.lastAppearance=root.blendState.to;root.blendState=null}
 }
 onEndpointAppearanceChanged:{if(animationEnabled&&!immediatePalette)Qt.callLater(retarget);else settle()}
 onAnimationEnabledChanged:if(!animationEnabled)settle()
 function settle(){transition.stop();lastAppearance=endpointAppearance;blendState=null;transitionProgress=1}
 function receivePalette(value){
  if(paletteInitialized){palette=value;return}
  paletteInitialized=true;immediatePalette=true;palette=value;settle()
  Qt.callLater(function(){root.immediatePalette=false})
 }
 function retarget(){
  if(!animationEnabled){settle();return}
  var previous=displayedAppearance,next=endpointAppearance
  // Keep one committed appearance across the queued start, stop and finish.
  // Exposing endpointAppearance here flashes the target before interpolation.
  transition.stop();lastAppearance=previous;blendState=null;transitionProgress=0
  blendState={from:previous,to:next};transition.start()
 }
 property var lastAppearance:null
 function resolveAppearance(){
  var roles={},names=roleNames.concat(Object.keys(treatment.roles||{}),Object.keys(chrome),Object.keys(Roles.roles).map(key=>Roles.roles[key]),["diagramInk","diagramAccent","globeLand","globeOcean","globeBorder","globeHighlight","globeSoft","spaceRose","spaceGold","spaceVoid","spaceFade","spaceEffect","spaceStar","roseInk","logoIdle","trayIdle"])
  names.forEach(function(role){roles[role]=String(endpointColor(role))})
  // Match the live controls' optional-role fallbacks at both endpoints.
  roles.logoLight=String(endpointTreatmentColor("logoLight")||Qt.lighter(endpointColor("uiAccent"),1.35))
  roles.logoIdle=String(endpointTreatmentColor("logoIdle")||endpointColor("muted"))
  roles.trayIdle=String(endpointTreatmentColor("trayIdle")||endpointColor("uiText"))
  roles.actionInk=String(endpointTreatmentColor("actionInk")||endpointColor("uiText"))
  roles.actionAccent=String(endpointTreatmentColor("actionAccent")||endpointColor("uiAccent"))
  var visual={circuitInkGain:treatment.circuitInkGain||1,circuitStrokeScale:treatment.circuitStrokeScale||1,
   circuitUnderlay:treatment.circuitUnderlay?treatmentValue(treatment.circuitUnderlay):"#00000000",
   logoActiveStrokeScale:treatment.logoActiveStrokeScale||1,actionStrokeScale:treatment.actionStrokeScale||1,
   actionGlowScale:treatment.actionGlowScale===undefined?1:treatment.actionGlowScale}
  var settings=resolveData(settingsSource)
  settings.spaceSecondaryColor=settings.spaceSecondaryColor||settings.voidLightColor||roles.accent
  settings.circuitPrimary=settings.circuitPrimary||roles.diagramAccent
  settings.circuitSecondary=settings.circuitSecondary||roles.diagramInk
  settings.circuitHighlight=settings.circuitHighlight||roles.spaceStar
  var mode=ThemeDesign.definition.voidMode===0&&treatment.coverageVoid?1:ThemeDesign.definition.voidMode
  return {roles:roles,settings:settings,auxiliary:resolveData(auxiliarySource),treatment:visual,
   orbitMix:ThemeDesign.definition.actionLayout==="arc"?1:0,circuitMix:ThemeDesign.definition.circuitRenderer==="ember"?0:1,voidMix:mode===0?0:1,voidWeights:[0,1,2,3].map(i=>i===mode?1:0)}
 }
 function guardAppearance(value){
  if(transitionProgress<=0||transitionProgress>=1)return value
  var roles=value.roles,bg=roles.background
  for(var role of ["uiText","uiMuted","uiHeading","foreground","diagramInk","encryptionKey1","encryptionKey2","encryptionKey3"])
   roles[role]=legibleSurfaces(roles[role],[bg,roles.popupSurface,roles.tooltipSurface],4.5)
  for(var role of ["uiAccent","uiBorder","accent","diagramAccent","actionInk","actionAccent"])
   if(roles[role])roles[role]=legible(roles[role],bg,3)
  roles.uiSelectionText=legible(roles.uiSelectionText,roles.accent,4.5)
  return value
 }
 function color(role,depth){return displayedAppearance.roles[role]!==undefined?displayedAppearance.roles[role]:endpointColor(role,depth)}
 function treatmentColor(role){
  if((blendState||lastAppearance!==endpointAppearance)&&["logoLight","logoIdle","trayIdle"].indexOf(role)>=0)return color(role)
  var value=endpointTreatmentColor(role)
  return value===null?null:color(role)
 }
 function luminance(value){
  var c=Qt.color(value),v=[c.r,c.g,c.b].map(x=>x<=.04045?x/12.92:Math.pow((x+.055)/1.055,2.4))
  return .2126*v[0]+.7152*v[1]+.0722*v[2]
 }
 function contrast(a,b){var x=luminance(a),y=luminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)}
 function legibleSurfaces(value,surfaces,minimum){
  var score=function(c){return Math.min.apply(null,surfaces.map(bg=>contrast(c,bg)))}
  if(score(value)>=minimum)return value
  var target=score("#ffffff")>score("#000000")?"#ffffff":"#000000"
  for(var i=1;i<=24;i++){var result=Blend.mix(value,target,i/24);if(score(result)>=minimum)return result}
  return target
 }
 function legible(value,background,minimum){
  if(contrast(value,background)>=minimum)return value
  var c=Qt.color(value),target=luminance(background)>.179?0:1
  for(var i=1;i<=20;i++){var t=i/20,result=Qt.rgba(c.r+(target-c.r)*t,c.g+(target-c.g)*t,c.b+(target-c.b)*t,1);if(contrast(result,background)>=minimum)return String(result)}
  return target?"#ffffff":"#000000"
 }
 function overrideValue(key){
  var local=overrides[themeId]||{},all=overrides["*"]||{}
  return local[key]!==undefined?local[key]:all[key]
 }
 function mixColor(a,b,t){var x=Qt.color(a),y=Qt.color(b);return String(Qt.rgba(x.r+(y.r-x.r)*t,x.g+(y.g-x.g)*t,x.b+(y.b-x.b)*t,1))}
 function treatmentValue(spec){
  if(typeof spec==="number"||typeof spec==="boolean")return spec
  if(typeof spec==="string")return effectivePalette[spec.slice(1)]||effectivePalette.foreground
  return mixColor(effectivePalette[spec.base]||effectivePalette.foreground,effectivePalette[spec.blend]||effectivePalette.foreground,spec.amount)
 }
 function endpointTreatmentColor(role){
  var roles=treatment.roles||{}
  // A curated design's logo/accent also identifies it in the desktop bar.
  // Keep desktop defaults for designs without a treatment (including Osaka).
  var tray=roles.logoLight!==undefined?roles.logoLight:roles.uiAccent
  var spec=role==="trayLight"&&tray!==undefined?tray:chrome[role]!==undefined?chrome[role]:roles[role]
  if(spec===undefined)return null
  var value=treatmentValue(spec),surface=designSurface()
  if(role==="uiSelectionText")return legible(value,endpointColor("accent"),4.5)
  if(["uiText","uiMuted","uiHeading","foreground","diagramInk"].indexOf(role)>=0)return legible(value,surface,5.5)
  if(["uiAccent","accent","uiBorder","diagramAccent","globeBorder","actionInk","actionAccent"].indexOf(role)>=0)return legible(value,surface,3)
  return value
 }
 function actionColor(ink,accent,active){
  var role=active?"actionAccent":"actionInk"
  if(blendState||lastAppearance!==endpointAppearance)return color(role)
  return (treatment.roles||{})[role]!==undefined?color(role):(active?accent:ink)
 }
 function actionStroke(width,active){return width*(active?visualTreatment.actionStrokeScale:1)}
 function actionShadow(glow){return 5*glow*visualTreatment.actionGlowScale}
 function derivedColor(spec,depth){
  var base=Qt.color(endpointColor(spec.base,depth+1)),gain=spec.gain
  var value=String(Qt.rgba(Math.min(1,base.r*gain[0]),Math.min(1,base.g*gain[1]),Math.min(1,base.b*gain[2]),spec.alpha===undefined?1:spec.alpha))
  return spec.contrast?legible(value,designSurface(),spec.contrast):value
 }
 function designSurface(){
  if((treatment.roles||{}).background!==undefined)return treatmentValue(treatment.roles.background)
  var bg=effectivePalette.background||Roles.jade.background
  if(!(ThemeDesign.definition.colorModel==="paper"))return bg
  var paper=mixColor(bg,"#ffffff",luminance(bg)>.3?.08:.86)
  return mixColor(paper,effectivePalette.magenta||bg,.065)
 }
 function designColor(role){
  var surface=designSurface(),fg=effectivePalette.foreground||Roles.jade.foreground,accent=effectivePalette.accent||Roles.jade.accent
  // Keep Orbit and legacy illustrations unchanged; Classic uses calibrated roles.
  if(role==="encryptionKey1")return endpointColor("diagramAccent")
  if(role==="encryptionKey2")return legible(endpointColor("magenta"),surface,4.5)
  if(role==="encryptionKey3")return legible(endpointColor("yellow"),surface,4.5)
  if(role==="modalScrim")return Qt.alpha(endpointColor("darker_background"),.65)
  var textInk=(ThemeDesign.definition.colorModel==="spectral")?mixColor(effectivePalette.green||accent,effectivePalette.bright_green||fg,.6):fg
  var surfaces={background:surface,popupSurface:surface,tooltipSurface:surface,dark_background:mixColor(surface,fg,.025),darker_background:surface,lighter_background:mixColor(surface,fg,.045),selection:mixColor(surface,accent,.12)}
  if(surfaces[role])return surfaces[role]
  if((ThemeDesign.definition.colorModel==="paper")){
   var warm=effectivePalette.orange||accent,gold=effectivePalette.bright_yellow||accent,rose=effectivePalette.magenta||accent
   if(role==="roseInk")return legible(mixColor(rose,warm,.25),surface,4.5)
   if(role==="globeLand")return mixColor(surface,warm,.28)
   if(role==="globeOcean")return mixColor(surface,"#ffffff",.55)
   if(role==="globeHighlight")return mixColor(surface,"#ffffff",.80)
   if(role==="globeSoft")return mixColor(surface,warm,.08)
   if(role==="diagramInk"||role==="globeBorder")return legible(warm,surface,4.5)
   if(role==="diagramAccent")return legible(gold,surface,3)
   if(["uiAccent","accent","enteringRoute","exitLight"].indexOf(role)>=0)return legible(gold,surface,4.5)
   if(role==="spaceRose")return legible(rose,surface,2.1)
   if(role==="spaceGold")return legible(gold,surface,2.1)
  }
  if(role==="spaceVoid")return mixColor(surface,accent,(ThemeDesign.definition.colorModel==="paper")?.018:.025)
  if(role==="spaceFade"){
   var fade=mixColor(surface,accent,(ThemeDesign.definition.colorModel==="paper")?.014:.035)
   var a=Qt.color(fade),b=Qt.color(designColor("spaceVoid"))
   var distance=Math.max(Math.abs(a.r-b.r),Math.abs(a.g-b.g),Math.abs(a.b-b.b))
   return (ThemeDesign.definition.colorModel==="paper")&&distance<1/255?mixColor(designColor("spaceVoid"),"#000000",.012):fade
  }
  if(role==="spaceEffect")return legible(accent,surface,3)
  if(role==="spaceStar")return legible(fg,surface,5.5)
  if(["foreground","dark_foreground","light_foreground","bright_foreground","uiText","uiMuted","uiHeading","uiSelectionText"].indexOf(role)>=0)return legible(textInk,role==="uiSelectionText"?designColor("accent"):surface,5.5)
  if(["uiAccent","accent","diagramAccent","enteringRoute","exitLight"].indexOf(role)>=0)return legible(accent,surface,4.5)
  if(["uiBorder","muted","diagramInk","retiringRoute","retiringCountry"].indexOf(role)>=0)return legible(fg,surface,4.5)
  if(role==="globeLand")return (ThemeDesign.definition.colorModel==="paper")?mixColor(surface,accent,.09):legible(accent,surface,3)
  if(role==="globeOcean")return (ThemeDesign.definition.colorModel==="paper")?surface:mixColor(surface,accent,.04)
  if(role==="globeBorder")return legible(accent,(ThemeDesign.definition.colorModel==="paper")?mixColor(surface,accent,.09):surface,4.5)
  if(role==="globeHighlight")return mixColor(surface,"#ffffff",.8)
  return null
 }
 function endpointColor(role,depth){
  depth=depth||0;if(depth>8)return effectivePalette.foreground||Roles.jade.foreground
  if(chrome[role]!==undefined||(treatment.roles||{})[role]!==undefined){
   var custom=overrideValue(role)
   return custom!==undefined?(custom.charAt(0)==="@"?endpointColor(custom.slice(1),depth+1):custom):endpointTreatmentColor(role)
  }
  if(ThemeDesign.definition.colorModel!=="calibrated"){var resolved=designColor(role);if(resolved!==null)return resolved}
  var override=overrideValue(role)
  if(override!==undefined)return override.charAt(0)==="@"?endpointColor(override.slice(1),depth+1):override
  if(Roles.derived[role])return derivedColor(Roles.derived[role],depth)
  var surface=effectivePalette.background||Roles.jade.background
  var ui={uiText:"foreground",uiMuted:"dark_foreground",uiHeading:"light_foreground",uiAccent:"accent",uiBorder:"muted"}
  if(role==="uiSelectionText")return legible(effectivePalette.foreground||Roles.jade.foreground,endpointColor("accent"),4.5)
  if(ui[role]){
   var value=endpointColor(ui[role],depth+1)
   return jade?value:legible(value,surface,role==="uiBorder"?1.6:role==="uiAccent"?3:4.5)
  }
  var profile=jade?{}:Profiles.profiles[themeId]||{}
  if(profile[role])return endpointColor(profile[role].slice(1),depth+1)
  var extension=Roles.extensions[role]
  if(extension)return jade?(Array.isArray(extension[0])?Qt.rgba(extension[0][0],extension[0][1],extension[0][2],1):extension[0]):(effectivePalette[extension[1]]||Roles.jade[extension[1]])
  return effectivePalette[role]||Roles.jade[role]||effectivePalette.foreground
 }
 function resolveData(value,path){
  path=path||"$"
  var override=overrideValue(path)
  if(override!==undefined)return override.charAt(0)==="@"?endpointColor(override.slice(1)):override
  var presentation=(treatment.settings||{})[path]
  if(presentation!==undefined)return treatmentValue(presentation)
  if(typeof value==="string") {
   if(value.charAt(0)==="@")return endpointColor(value.slice(1))
   var role=Roles.roles[value.toLowerCase()]
   return role?endpointColor(role):value
  }
  if(Array.isArray(value))return value.map((v,i)=>resolveData(v,path+"."+i))
  if(value&&typeof value==="object"){
   var result={},keys=Object.keys(value),prefix=path+"."
   // Treatments can supply optional settings omitted by an older publication.
   Object.keys(treatment.settings||{}).forEach(function(setting){
    if(setting.indexOf(prefix)!==0)return
    var key=setting.slice(prefix.length)
    if(key.indexOf(".")<0&&keys.indexOf(key)<0)keys.push(key)
   })
   keys.forEach(key=>result[key]=resolveData(value[key],path+"."+key));return result
  }
  return value
 }
 function reference(value){return value.charAt(0)==="@"?value:(Roles.roles[value.toLowerCase()]?"@"+Roles.roles[value.toLowerCase()]:value)}
}
