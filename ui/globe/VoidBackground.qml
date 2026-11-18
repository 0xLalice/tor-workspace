import ".."
import QtQuick
import "../theme/EffectSettings.js" as Effects
Rectangle {
 id: root
 objectName:"space-background"
 property bool active:true
 property real animationTime:0
 property real motionTime:0
 property var settings: ({})
 property real globeRadius:0
 property vector2d globeCenter:Qt.vector2d(width/2,height/2)
 // Incoming and outgoing fields travel in the same direction at different
 // depths. The displacement is bounded and reverses continuously on retarget.
 readonly property real travelDistance:90*Math.min(1.2,width/460)
 function travel(mode){return travelDistance*(mode<2?-ThemeColors.circuitMix:1-ThemeColors.circuitMix)}
 readonly property int spaceStyle:ThemeDesign.definition.spaceStyle
 readonly property url shader:Qt.resolvedUrl(ThemeColors.voidMix>=.5?"../../assets/shaders/space-effects.frag.qsb":"../../assets/shaders/void-effects.frag.qsb")
 readonly property int effectLayerCount:ThemeColors.voidWeights.filter(weight=>weight>0).length
 readonly property bool animating:active&&visible&&!!settings&&!!settings.voidAnimate&&!!(settings.voidStars||settings.voidDust||settings.voidNebula||settings.voidRays)
 function advance(seconds){
  if(!animating)return
  // Integrate velocity instead of re-scaling the entire elapsed lifetime when
  // a theme changes speed. Drop long stalled/hidden frames instead of catching up.
  var dt=Math.max(0,Math.min(seconds,.05))
  animationTime+=dt
  motionTime+=dt*(settings.voidSpeed===undefined?.5:settings.voidSpeed)
 }
 readonly property var colors: Effects.surfacePalette(settings)
 radius:ThemeDesign.radius(18)
 gradient: Gradient {
  orientation: colors.mode===2 ? Gradient.Horizontal : Gradient.Vertical
  GradientStop { position:0; color:colors.panel }
  GradientStop { position:0.52; color:colors.mode===0 ? colors.panel : colors.fade }
  GradientStop { position:1; color:colors.panel }
 }
 // Only this effect layer crossfades shader modes; the globe and routes
 // keep their existing objects, camera and geometry.
 Repeater {
  model:4
  Loader {
   required property int index
   property int effectMode:index
   anchors.fill:parent
   active:ThemeColors.voidWeights[index]>0
   opacity:ThemeColors.voidWeights[index]
   sourceComponent:effect
  }
 }
 FrameAnimation {running:root.animating;onTriggered:root.advance(frameTime)}
 Component {
  id:effect
  ShaderEffect {

  readonly property int effectMode:parent.effectMode
  readonly property bool coverageMode:effectMode!==0
  anchors.fill:parent
  visible:!!(root.settings && (root.settings.voidStars||root.settings.voidDust||root.settings.voidNebula||root.settings.voidRays))
  readonly property var options:root.settings||{}
  property vector2d resolution:Qt.vector2d(width,height)
  property vector4d materialDetail:Qt.vector4d(0,1,options.clayStars||0,options.paperGrain||0)
  property color secondTint:options.spaceSecondaryColor||lightColor
  property vector4d celestial:Qt.vector4d(options.roseVoid||0,options.roseAtmosphere||0,options.roseStars||0,0)
  property vector4d occluder:Qt.vector4d(root.globeCenter.x,root.globeCenter.y,root.globeRadius,0)
  property real time:root.animationTime
  property real driftTime:root.motionTime
  property vector4d themeTravel:Qt.vector4d(root.travel(effectMode),root.travel(effectMode)*.24,root.travel(effectMode)/Math.max(1,root.height)*.8,root.travel(effectMode)/Math.max(1,root.height)*.18)
  property color starColor:options.voidStarColor||ThemeColors.color("bright_blue")
  property color lightColor:options.voidLightColor||ThemeColors.color("accent")
  property vector4d enabledLayers:Qt.vector4d(options.voidStars?1:0,options.voidDust?1:0,options.voidNebula?1:0,options.voidRays?1:0)
  property vector4d stars:Qt.vector4d(options.voidDensity===undefined?0.4:options.voidDensity,options.voidStarSize===undefined?0.8:options.voidStarSize,options.voidStarBrightness===undefined?0.45:options.voidStarBrightness,options.voidStarGlow===undefined?0.35:options.voidStarGlow)
  property vector4d motion:Qt.vector4d(options.voidSpeed===undefined?0.5:options.voidSpeed,options.voidLightStrength===undefined?0.6:options.voidLightStrength,options.voidTwinkle?1:0,Math.max(0,effectMode-1))
  fragmentShader:Qt.resolvedUrl(coverageMode?"../../assets/shaders/space-effects.frag.qsb":"../../assets/shaders/void-effects.frag.qsb")
 }
 }
}
