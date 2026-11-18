.pragma library
// Desktop fallbacks; active tray lighting inherits the current design in ThemeColors.
var chrome = {
 default:{trayLight:"@accent"},
 white:{trayLight:"@foreground",trayIdle:"@muted"},
 "osaka-jade":{trayLight:"@green"},
 "jade-horse":{trayLight:"@green"}
};
// Palette/design treatments are deliberately separate from the review/name
// registry. Adding a visual draft here never marks a palette as approved.
// Strings name raw desktop palette roles; mixes also use raw palette roles.
// Settings are exact paths in the resolved presentation, never saved presets.
var designs = {
 "solitude": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@accent",uiBorder:"@accent",uiSelectionText:"@darker_background",
    actionInk:"@accent",actionAccent:"@foreground",logoLight:"@foreground",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@accent",
    exitLight:"@foreground",originRoute:"@accent",transitionLight:"@foreground",
    enteringRoute:"@accent",retiringRoute:"@bright_yellow",retiringCountry:"@bright_yellow"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@bright_yellow","$.voidLightStrength":.8,
    "$.voidStarColor":"@foreground","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@accent","$.mapFillColor":"@accent","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@foreground","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@accent",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@accent",
    "$.layers.ripples.color":"@accent",
    "$.designColors.8.land":{base:"background",blend:"accent",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@accent",
    "$.designColors.8.atmosphere":"@accent","$.designColors.8.skyColor":"@foreground",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@accent"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.6,circuitStrokeScale:1.2,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@foreground",dark_foreground:"@light_foreground",light_foreground:"@light_foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    accent:"@bright_yellow",uiAccent:"@bright_yellow",uiBorder:"@light_foreground",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_yellow",logoLight:"@bright_yellow",
    diagramInk:"@foreground",diagramAccent:"@bright_yellow",
    globeLand:{base:"background",blend:"accent",amount:.12},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"foreground",amount:.35},globeHighlight:"@accent",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@light_foreground",spaceStar:"@foreground",
    exitLight:"@bright_yellow",originRoute:"@accent",transitionLight:"@foreground",
    enteringRoute:"@bright_yellow",retiringRoute:"@accent",retiringCountry:"@light_foreground"
   },
   settings:{
    "$.voidLightColor":"@bright_yellow","$.spaceSecondaryColor":"@red","$.voidLightStrength":.3,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@bright_yellow","$.circuitSecondary":"@light_foreground","$.circuitHighlight":"@bright_yellow",
    "$.mapColor":"@light_foreground","$.mapFillColor":{base:"background",blend:"foreground",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@accent","$.designColors.10.skyColor":"@red",
    "$.designColors.10.atmosphereStrength":.24,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },



 "retro-82": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@foreground",uiMuted:"@cyan",uiHeading:"@foreground",
    uiAccent:"@orange",uiBorder:"@orange",uiSelectionText:"@darker_background",
    actionInk:"@orange",actionAccent:"@foreground",logoLight:"@orange",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@orange",
    exitLight:"@foreground",originRoute:"@blue",transitionLight:"@cyan",
    enteringRoute:"@orange",retiringRoute:"@blue",retiringCountry:"@blue"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@orange","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.95,
    "$.voidStarColor":"@foreground","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@orange","$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"orange",blend:"foreground",amount:.4},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@orange",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@orange",
    "$.layers.ripples.color":"@orange",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@cyan",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@orange"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.8,circuitStrokeScale:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@light_foreground",dark_foreground:"@blue",light_foreground:"@blue",bright_foreground:"@light_foreground",
    uiText:"@light_foreground",uiMuted:"@blue",uiHeading:"@light_foreground",
    accent:"@blue",uiAccent:"@blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@blue",actionAccent:"@light_foreground",logoLight:"@cyan",
    diagramInk:"@light_foreground",diagramAccent:"@blue",
    globeLand:{base:"background",blend:"blue",amount:.16},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"blue",amount:.5},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@blue",spaceStar:"@light_foreground",
    exitLight:"@blue",originRoute:"@blue",transitionLight:"@light_foreground",
    enteringRoute:"@blue",retiringRoute:"@blue",retiringCountry:"@blue"
   },
   settings:{
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@green","$.voidLightStrength":.3,
    "$.voidStarColor":"@light_foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@light_foreground","$.circuitSecondary":"@blue","$.circuitHighlight":"@cyan",
    "$.mapColor":"@blue","$.mapFillColor":{base:"background",blend:"blue",amount:.18},"$.markerColor":"@light_foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@blue",
    "$.designColors.10.atmosphereStrength":.3,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },


 "miasma": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@accent",uiBorder:"@accent",uiSelectionText:"@darker_background",
    actionInk:"@accent",actionAccent:"@foreground",logoLight:{base:"accent",blend:"foreground",amount:.4},
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@accent",
    exitLight:"@foreground",originRoute:"@accent",transitionLight:"@foreground",
    enteringRoute:"@accent",retiringRoute:"@orange",retiringCountry:"@orange"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@orange","$.voidLightStrength":.85,
    "$.voidStarColor":"@foreground","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@accent","$.mapFillColor":"@accent","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"accent",blend:"foreground",amount:.55},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@accent",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@accent",
    "$.layers.ripples.color":"@accent",
    "$.designColors.8.land":{base:"background",blend:"accent",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@accent",
    "$.designColors.8.atmosphere":"@accent","$.designColors.8.skyColor":"@foreground",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@accent"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@foreground",dark_foreground:"@light_foreground",light_foreground:"@light_foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    accent:"@foreground",uiAccent:"@foreground",uiBorder:"@light_foreground",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@foreground",logoLight:"@foreground",
    diagramInk:"@foreground",diagramAccent:"@foreground",
    globeLand:{base:"background",blend:"brown",amount:.12},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"foreground",amount:.35},globeHighlight:"@brown",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@light_foreground",spaceStar:"@foreground",
    exitLight:"@foreground",originRoute:"@brown",transitionLight:"@foreground",
    enteringRoute:"@foreground",retiringRoute:"@brown",retiringCountry:"@light_foreground"
   },
   settings:{
    "$.voidLightColor":"@light_foreground","$.spaceSecondaryColor":"@red","$.voidLightStrength":.3,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@foreground","$.circuitSecondary":"@light_foreground","$.circuitHighlight":"@foreground",
    "$.mapColor":"@light_foreground","$.mapFillColor":{base:"background",blend:"foreground",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@foreground","$.designColors.10.skyColor":"@red",
    "$.designColors.10.atmosphereStrength":.24,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },


 "lupine": {
  original: {
   coverageVoid:true,circuitInkGain:1.65,circuitUnderlay:"@background",
   actionStrokeScale:1.35,actionGlowScale:0,logoActiveStrokeScale:1.25,overlayOutline:true,
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@blue",uiBorder:"@blue",uiSelectionText:"@background",
    actionInk:"@blue",actionAccent:"@brown",
    logoLight:{base:"blue",blend:"foreground",amount:.25},logoIdle:"@muted",overlayBorder:"@blue",
    popupSurface:{base:"background",blend:"magenta",amount:.055},tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@blue",
    exitLight:"@blue",originRoute:"@foreground",transitionLight:"@magenta",
    enteringRoute:"@blue",retiringRoute:"@light_foreground",retiringCountry:"@magenta"
   },
   settings:{
    "$.voidColor":{base:"background",blend:"blue",amount:.035},"$.voidFade":"@dark_background",
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":1.5,
    "$.voidStarColor":"@foreground","$.voidStarSize":1.1,"$.voidDensity":.32,
    "$.mapColor":"@blue","$.mapFillColor":"@magenta","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"blue",blend:"foreground",amount:.35},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@foreground",
    "$.layers.tunnel.width":1.3,"$.layers.tunnel.intensity":1,
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@foreground",
    "$.layers.particles.width":.9,"$.layers.particles.intensity":1,
    "$.layers.ripples.color":"@blue","$.layers.ripples.width":1.2,"$.layers.ripples.intensity":.5,
    "$.designColors.8.land":"@background","$.designColors.8.ocean":{base:"blue",blend:"background",amount:.5},"$.designColors.8.borders":"@background","$.designColors.8.brightness":1,
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@blue",
    "$.designColors.8.atmosphereStrength":.8,"$.designColors.8.atmosphereWidth":.065,"$.designColors.8.haze":.11,
    "$.designColors.8.lamps":"@background","$.designColors.8.effect":"@blue"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.8,circuitStrokeScale:1.8,
   actionStrokeScale:1.35,actionGlowScale:0,logoActiveStrokeScale:1.25,overlayOutline:true,
   roles:{
    background:"@background",popupSurface:{base:"background",blend:"cyan",amount:.04},tooltipSurface:"@dark_background",
    foreground:"@foreground",dark_foreground:"@light_foreground",light_foreground:"@light_foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    accent:"@brown",uiAccent:"@brown",uiBorder:"@brown",uiSelectionText:"@background",
    actionInk:{base:"brown",blend:"background",amount:.3},actionAccent:"@brown",logoLight:"@brown",logoIdle:"@muted",overlayBorder:"@cyan",
    diagramInk:"@foreground",diagramAccent:"@brown",
    globeLand:{base:"background",blend:"cyan",amount:.16},globeOcean:{base:"background",blend:"cyan",amount:.08},globeBorder:{base:"cyan",blend:"brown",amount:.4},globeHighlight:"@background",
    spaceVoid:"@background",spaceFade:"@dark_background",spaceEffect:"@cyan",spaceStar:"@foreground",
    exitLight:"@brown",originRoute:"@foreground",transitionLight:"@cyan",
    enteringRoute:"@brown",retiringRoute:"@light_foreground",retiringCountry:"@cyan"
   },
   settings:{
    "$.voidLightColor":"@cyan","$.spaceSecondaryColor":"@brown","$.voidLightStrength":.4,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.85,"$.voidStarSize":.85,"$.voidDensity":.42,
    "$.circuitPrimary":"@brown","$.circuitSecondary":"@foreground","$.circuitHighlight":"@brown",
    "$.mapColor":"@brown","$.mapFillColor":{base:"background",blend:"cyan",amount:.15},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.1,"$.designColors.10.atmosphere":"@cyan","$.designColors.10.skyColor":"@cyan",
    "$.designColors.10.atmosphereStrength":.3,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.04
   }
  }
 },


 "lumon": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@bright_foreground",uiMuted:"@cyan",uiHeading:"@bright_foreground",
    uiAccent:"@bright_foreground",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@cyan",actionAccent:"@bright_foreground",logoLight:"@bright_foreground",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@bright_foreground",diagramAccent:"@bright_foreground",
    exitLight:"@bright_foreground",originRoute:"@blue",transitionLight:"@bright_cyan",
    enteringRoute:"@bright_foreground",retiringRoute:"@cyan",retiringCountry:"@cyan"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@cyan","$.voidLightStrength":.7,
    "$.voidStarColor":"@bright_foreground","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@bright_foreground","$.mapFillColor":"@blue","$.markerColor":"@bright_foreground",
    "$.layers.tunnel.color":"@bright_foreground","$.layers.tunnel.highlightColor":"@bright_foreground","$.layers.tunnel.guideColor":"@bright_foreground",
    "$.layers.particles.color":"@bright_foreground","$.layers.particles.colorMix.0.color":"@bright_foreground","$.layers.particles.colorMix.1.color":"@bright_foreground",
    "$.layers.ripples.color":"@bright_foreground",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.45},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@bright_foreground",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@bright_foreground","$.designColors.8.effect":"@bright_foreground"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@foreground",dark_foreground:"@blue",light_foreground:"@blue",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@blue",uiHeading:"@foreground",
    accent:"@blue",uiAccent:"@blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@blue",actionAccent:"@foreground",logoLight:"@blue",
    diagramInk:"@foreground",diagramAccent:"@blue",
    globeLand:{base:"background",blend:"blue",amount:.16},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"blue",amount:.5},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@blue",spaceStar:"@foreground",
    exitLight:"@blue",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@blue",retiringRoute:"@blue",retiringCountry:"@blue"
   },
   settings:{
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.24,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@bright_cyan","$.circuitSecondary":"@blue","$.circuitHighlight":"@bright_cyan",
    "$.mapColor":"@blue","$.mapFillColor":{base:"background",blend:"blue",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@blue",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },


 "last-horizon": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@accent",uiBorder:"@accent",uiSelectionText:"@darker_background",
    actionInk:"@accent",actionAccent:"@foreground",logoLight:"@accent",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@accent",
    exitLight:"@foreground",originRoute:"@accent",transitionLight:"@magenta",
    enteringRoute:"@accent",retiringRoute:"@cyan",retiringCountry:"@cyan"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@cyan","$.voidLightStrength":.8,
    "$.voidStarColor":"@foreground","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@accent","$.mapFillColor":"@accent","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@light_foreground","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@accent",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@accent",
    "$.layers.ripples.color":"@accent",
    "$.designColors.8.land":{base:"background",blend:"cyan",amount:.4},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@accent",
    "$.designColors.8.atmosphere":"@accent","$.designColors.8.skyColor":"@foreground",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@accent"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@magenta",dark_foreground:"@green",light_foreground:"@green",bright_foreground:"@magenta",
    uiText:"@magenta",uiMuted:"@green",uiHeading:"@magenta",
    accent:"@green",uiAccent:"@green",uiBorder:"@green",uiSelectionText:"@darker_background",
    actionInk:"@green",actionAccent:"@magenta",logoLight:"@green",
    diagramInk:"@magenta",diagramAccent:"@green",
    globeLand:{base:"background",blend:"cyan",amount:.16},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"cyan",amount:.5},globeHighlight:"@cyan",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@green",spaceStar:"@magenta",
    exitLight:"@green",originRoute:"@cyan",transitionLight:"@magenta",
    enteringRoute:"@green",retiringRoute:"@cyan",retiringCountry:"@green"
   },
   settings:{
    "$.voidLightColor":"@green","$.spaceSecondaryColor":"@cyan","$.voidLightStrength":.35,
    "$.voidStarColor":"@magenta","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@magenta","$.circuitSecondary":"@cyan","$.circuitHighlight":"@foreground",
    "$.mapColor":"@green","$.mapFillColor":{base:"background",blend:"green",amount:.18},"$.markerColor":"@magenta",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@cyan","$.designColors.10.skyColor":"@cyan",
    "$.designColors.10.atmosphereStrength":.3,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },


 "hackerman": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@bright_cyan",uiMuted:"@cyan",uiHeading:"@bright_cyan",
    uiAccent:"@cyan",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@cyan",actionAccent:"@bright_cyan",logoLight:"@cyan",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@bright_cyan",diagramAccent:"@bright_cyan",
    exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_blue",
    enteringRoute:"@bright_cyan",retiringRoute:"@blue",retiringCountry:"@blue"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@cyan","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.85,
    "$.voidStarColor":"@bright_cyan","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@bright_cyan","$.mapFillColor":"@blue","$.markerColor":"@bright_cyan",
    "$.layers.tunnel.color":"@bright_cyan","$.layers.tunnel.highlightColor":"@bright_cyan","$.layers.tunnel.guideColor":"@bright_cyan",
    "$.layers.particles.color":"@bright_cyan","$.layers.particles.colorMix.0.color":"@bright_cyan","$.layers.particles.colorMix.1.color":"@bright_cyan",
    "$.layers.ripples.color":"@bright_cyan",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@cyan","$.designColors.8.skyColor":"@bright_cyan",
    "$.designColors.8.atmosphereStrength":.5,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@bright_cyan","$.designColors.8.effect":"@bright_cyan"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@foreground",dark_foreground:"@accent",light_foreground:"@accent",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@accent",uiHeading:"@foreground",
    accent:"@accent",uiAccent:"@accent",uiBorder:"@accent",uiSelectionText:"@darker_background",
    actionInk:"@accent",actionAccent:"@foreground",logoLight:"@accent",
    diagramInk:"@foreground",diagramAccent:"@accent",
    globeLand:{base:"background",blend:"blue",amount:.16},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"blue",amount:.5},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@accent",spaceStar:"@foreground",
    exitLight:"@accent",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@accent",retiringRoute:"@blue",retiringCountry:"@accent"
   },
   settings:{
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.28,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@bright_green","$.circuitSecondary":"@blue","$.circuitHighlight":"@bright_cyan",
    "$.mapColor":"@accent","$.mapFillColor":{base:"background",blend:"accent",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@blue",
    "$.designColors.10.atmosphereStrength":.3,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },


 "ethereal": {
  original: {
   coverageVoid:true,circuitInkGain:1.45,
   roles:{
    uiText:"@bright_cyan",uiMuted:"@cyan",uiHeading:"@bright_cyan",
    uiAccent:"@bright_blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@blue",actionAccent:"@bright_cyan",logoLight:"@bright_blue",
    popupSurface:"@background",tooltipSurface:"@dark_background",
    diagramInk:"@bright_cyan",diagramAccent:"@bright_blue",
    exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_magenta",
    enteringRoute:"@bright_blue",retiringRoute:"@magenta",retiringCountry:"@magenta"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@background",
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":1.25,
    "$.voidStarColor":"@bright_cyan","$.voidDensity":.18,"$.voidStarSize":.8,
    "$.mapColor":"@bright_blue","$.mapFillColor":"@blue","$.markerColor":"@bright_cyan",
    "$.layers.tunnel.color":"@bright_blue","$.layers.tunnel.highlightColor":"@bright_cyan","$.layers.tunnel.guideColor":"@bright_blue",
    "$.layers.particles.color":"@bright_cyan","$.layers.particles.colorMix.0.color":"@bright_cyan","$.layers.particles.colorMix.1.color":"@bright_blue",
    "$.layers.ripples.color":"@bright_blue",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@bright_cyan",
    "$.designColors.8.atmosphereStrength":.7,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@bright_cyan","$.designColors.8.effect":"@bright_blue"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.35,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:"@foreground",dark_foreground:"@orange",light_foreground:"@orange",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@orange",uiHeading:"@foreground",
    accent:"@orange",uiAccent:"@orange",uiBorder:"@orange",uiSelectionText:"@darker_background",
    actionInk:"@orange",actionAccent:"@foreground",logoLight:"@orange",
    diagramInk:"@foreground",diagramAccent:"@orange",
    globeLand:{base:"background",blend:"blue",amount:.16},globeOcean:"@darker_background",globeBorder:{base:"background",blend:"blue",amount:.5},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@orange",spaceStar:"@foreground",
    exitLight:"@orange",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@orange",retiringRoute:"@blue",retiringCountry:"@orange"
   },
   settings:{
    "$.voidLightColor":"@orange","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.35,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.65,"$.voidStarSize":.45,
    "$.circuitPrimary":"@foreground","$.circuitSecondary":"@blue","$.circuitHighlight":"@bright_cyan",
    "$.mapColor":"@orange","$.mapFillColor":{base:"background",blend:"orange",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@blue",
    "$.designColors.10.atmosphereStrength":.4,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.05
   }
  }
 },

 "rose-pine": {
  original: {
   coverageVoid:true,circuitInkGain:1.65,circuitUnderlay:"@background",
   actionStrokeScale:1.35,actionGlowScale:0,logoActiveStrokeScale:1.25,overlayOutline:true,
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@red",uiBorder:"@magenta",uiSelectionText:"@background",
    actionInk:"@magenta",actionAccent:"@foreground",
    logoLight:{base:"red",blend:"foreground",amount:.25},logoIdle:"@muted",overlayBorder:"@magenta",
    popupSurface:{base:"background",blend:"magenta",amount:.055},tooltipSurface:"@dark_background",
    diagramInk:"@foreground",diagramAccent:"@red",
    exitLight:"@red",originRoute:"@foreground",transitionLight:"@magenta",
    enteringRoute:"@red",retiringRoute:"@light_foreground",retiringCountry:"@magenta"
   },
   settings:{
    "$.voidColor":{base:"background",blend:"magenta",amount:.045},"$.voidFade":"@dark_background",
    "$.voidLightColor":"@red","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":2,
    "$.voidStarColor":"@foreground","$.voidStarSize":1.1,"$.voidDensity":.32,
    "$.mapColor":"@red","$.mapFillColor":"@magenta","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"red",blend:"foreground",amount:.35},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@foreground",
    "$.layers.tunnel.width":1.3,"$.layers.tunnel.intensity":1,
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@foreground",
    "$.layers.particles.width":.9,"$.layers.particles.intensity":1,
    "$.layers.ripples.color":"@red","$.layers.ripples.width":1.2,"$.layers.ripples.intensity":.5,
    "$.designColors.8.land":"@background","$.designColors.8.ocean":{base:"magenta",blend:"background",amount:.25},"$.designColors.8.borders":"@background","$.designColors.8.brightness":1,
    "$.designColors.8.atmosphere":"@magenta","$.designColors.8.skyColor":"@red",
    "$.designColors.8.atmosphereStrength":1.05,"$.designColors.8.atmosphereWidth":.065,"$.designColors.8.haze":.11,
    "$.designColors.8.lamps":"@background","$.designColors.8.effect":"@red"
   }
  },
  meridian: {
   circuitLift:.32,circuitInkGain:1.8,circuitStrokeScale:1.8,
   actionStrokeScale:1.35,actionGlowScale:0,logoActiveStrokeScale:1.25,overlayOutline:true,
   roles:{
    background:"@background",popupSurface:{base:"background",blend:"blue",amount:.075},tooltipSurface:"@dark_background",
    foreground:"@foreground",dark_foreground:"@light_foreground",light_foreground:"@light_foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    accent:"@green",uiAccent:"@green",uiBorder:"@green",uiSelectionText:"@background",
    actionInk:"@blue",actionAccent:"@green",logoLight:"@green",logoIdle:"@muted",overlayBorder:"@blue",
    diagramInk:"@foreground",diagramAccent:"@green",
    globeLand:{base:"background",blend:"blue",amount:.25},globeOcean:{base:"background",blend:"blue",amount:.18},globeBorder:"@blue",globeHighlight:"@background",
    spaceVoid:"@background",spaceFade:"@dark_background",spaceEffect:"@blue",spaceStar:"@foreground",
    exitLight:"@green",originRoute:"@foreground",transitionLight:"@blue",
    enteringRoute:"@green",retiringRoute:"@light_foreground",retiringCountry:"@blue"
   },
   settings:{
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":.85,
    "$.voidStarColor":"@foreground","$.voidStarBrightness":.85,"$.voidStarSize":.85,"$.voidDensity":.42,
    "$.circuitPrimary":"@green","$.circuitSecondary":"@foreground","$.circuitHighlight":"@green",
    "$.mapColor":"@green","$.mapFillColor":{base:"background",blend:"blue",amount:.15},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.1,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@magenta",
    "$.designColors.10.atmosphereStrength":.8,"$.designColors.10.atmosphereWidth":.055,"$.designColors.10.haze":.08
   }
  }
 },

 "ristretto": {
  original: {
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@orange",uiBorder:"@yellow",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_foreground",
    diagramInk:"@foreground",diagramAccent:"@orange",logoLight:"@orange",
    exitLight:"@orange",originRoute:"@yellow",transitionLight:"@foreground",
    enteringRoute:"@orange",retiringRoute:"@yellow",retiringCountry:"@orange"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@orange","$.spaceSecondaryColor":"@brown","$.voidLightStrength":.65,
    "$.voidStarColor":"@foreground",
    "$.mapColor":"@orange","$.mapFillColor":"@yellow","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"orange",blend:"foreground",amount:.35},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@yellow",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@orange",
    "$.layers.ripples.color":"@orange",
    "$.designColors.8.land":{base:"background",blend:"brown",amount:.55},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@yellow",
    "$.designColors.8.atmosphere":"@orange","$.designColors.8.skyColor":"@yellow",
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@orange"
   }
  },
  meridian: {
   circuitLift:.32,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:{base:"foreground",blend:"yellow",amount:.16},dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"yellow",amount:.16},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@yellow",accent:"@yellow",uiBorder:"@yellow",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:{base:"yellow",blend:"foreground",amount:.65},
    diagramInk:"@foreground",diagramAccent:"@yellow",logoLight:{base:"yellow",blend:"foreground",amount:.35},
    globeLand:{base:"dark_background",blend:"brown",amount:.15},globeOcean:"@darker_background",
    globeBorder:{base:"background",blend:"brown",amount:.65},globeHighlight:"@brown",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@yellow",spaceStar:"@foreground",
    exitLight:"@yellow",originRoute:"@yellow",transitionLight:"@foreground",
    enteringRoute:"@yellow",retiringRoute:"@yellow",retiringCountry:"@yellow"
   },
   settings:{
    "$.voidLightColor":"@yellow","$.spaceSecondaryColor":"@brown","$.voidLightStrength":.2,"$.voidStarColor":"@foreground","$.voidStarBrightness":.5,
    "$.circuitPrimary":{base:"yellow",blend:"foreground",amount:.7},"$.circuitSecondary":"@orange","$.circuitHighlight":"@foreground",
    "$.mapColor":"@yellow","$.mapFillColor":{base:"background",blend:"yellow",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@orange","$.designColors.10.skyColor":"@yellow",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,"$.designColors.10.haze":.04
   }
  }
 },


 "everforest": {
  original: {
   roles:{
    uiText:{base:"light_foreground",blend:"foreground",amount:.2},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:{base:"blue",blend:"light_foreground",amount:.6},uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_foreground",
    diagramInk:"@foreground",diagramAccent:{base:"blue",blend:"light_foreground",amount:.6},logoLight:{base:"blue",blend:"light_foreground",amount:.6},
    exitLight:{base:"blue",blend:"light_foreground",amount:.6},originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:{base:"blue",blend:"light_foreground",amount:.6},retiringRoute:"@blue",retiringCountry:{base:"blue",blend:"light_foreground",amount:.6}
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@light_foreground","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.65,
    "$.voidStarColor":"@foreground",
    "$.mapColor":{base:"blue",blend:"light_foreground",amount:.6},"$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.layers.tunnel.color":{base:"blue",blend:"foreground",amount:.5},"$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@blue",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":{base:"blue",blend:"light_foreground",amount:.6},
    "$.layers.ripples.color":{base:"blue",blend:"light_foreground",amount:.6},
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.28},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":{base:"blue",blend:"light_foreground",amount:.6},"$.designColors.8.skyColor":"@blue",
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":{base:"blue",blend:"light_foreground",amount:.6}
   }
  },
  meridian: {
   circuitLift:.32,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:{base:"foreground",blend:"light_foreground",amount:.65},dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"light_foreground",amount:.65},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:{base:"light_foreground",blend:"foreground",amount:.6},accent:{base:"light_foreground",blend:"foreground",amount:.6},uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:{base:"light_foreground",blend:"foreground",amount:.7},
    diagramInk:"@foreground",diagramAccent:"@light_foreground",logoLight:{base:"light_foreground",blend:"foreground",amount:.6},
    globeLand:{base:"dark_background",blend:"blue",amount:.12},globeOcean:"@darker_background",
    globeBorder:{base:"background",blend:"light_foreground",amount:.45},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@light_foreground",spaceStar:"@foreground",
    exitLight:"@light_foreground",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@light_foreground",retiringRoute:"@blue",retiringCountry:"@light_foreground"
   },
   settings:{
    "$.voidLightColor":"@light_foreground","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.2,"$.voidStarColor":"@foreground","$.voidStarBrightness":.5,
    "$.circuitPrimary":"@foreground","$.circuitSecondary":"@light_foreground","$.circuitHighlight":"@foreground",
    "$.mapColor":"@light_foreground","$.mapFillColor":{base:"background",blend:"light_foreground",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@light_foreground","$.designColors.10.skyColor":"@light_foreground",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,"$.designColors.10.haze":.04
   }
  }
 },


 "gruvbox": {
  original: {
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@orange",uiBorder:"@yellow",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_foreground",
    diagramInk:"@foreground",diagramAccent:"@orange",logoLight:"@orange",
    exitLight:"@orange",originRoute:"@yellow",transitionLight:"@foreground",
    enteringRoute:"@orange",retiringRoute:"@yellow",retiringCountry:"@orange"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@orange","$.spaceSecondaryColor":"@orange","$.voidLightStrength":.75,
    "$.voidStarColor":"@foreground",
    "$.mapColor":"@orange","$.mapFillColor":"@yellow","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@orange","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@yellow",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@orange",
    "$.layers.ripples.color":"@orange",
    "$.designColors.8.land":{base:"background",blend:"orange",amount:.5},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@yellow",
    "$.designColors.8.atmosphere":"@orange","$.designColors.8.skyColor":"@yellow",
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@orange"
   }
  },
  meridian: {
   circuitLift:.32,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:{base:"foreground",blend:"blue",amount:.16},dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"blue",amount:.16},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@blue",accent:"@blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@blue",actionAccent:{base:"blue",blend:"foreground",amount:.65},
    diagramInk:"@foreground",diagramAccent:"@blue",logoLight:"@blue",
    globeLand:{base:"dark_background",blend:"blue",amount:.12},globeOcean:"@darker_background",
    globeBorder:{base:"background",blend:"blue",amount:.55},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@blue",spaceStar:"@foreground",
    exitLight:"@blue",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@blue",retiringRoute:"@blue",retiringCountry:"@blue"
   },
   settings:{
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.23,"$.voidStarColor":"@foreground","$.voidStarBrightness":.5,
    "$.circuitPrimary":{base:"blue",blend:"foreground",amount:.7},"$.circuitSecondary":"@blue","$.circuitHighlight":"@foreground",
    "$.mapColor":"@blue","$.mapFillColor":{base:"background",blend:"blue",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@blue",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,"$.designColors.10.haze":.04
   }
  }
 },

 "kanagawa": {
  original: {
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@bright_blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_foreground",
    diagramInk:"@foreground",diagramAccent:"@bright_blue",logoLight:"@bright_blue",
    exitLight:"@bright_blue",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@bright_blue",retiringRoute:"@blue",retiringCountry:"@bright_blue"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@bright_blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":.85,
    "$.voidStarColor":"@foreground",
    "$.mapColor":"@bright_blue","$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@bright_blue","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@blue",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@bright_blue",
    "$.layers.ripples.color":"@bright_blue",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.5},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@bright_blue","$.designColors.8.skyColor":"@blue",
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@bright_blue"
   }
  },
  meridian: {
   circuitLift:.32,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:{base:"foreground",blend:"yellow",amount:.16},dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"yellow",amount:.16},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@yellow",accent:"@yellow",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@foreground",
    diagramInk:"@foreground",diagramAccent:"@yellow",logoLight:"@yellow",
    globeLand:{base:"dark_background",blend:"blue",amount:.12},globeOcean:"@darker_background",
    globeBorder:{base:"background",blend:"blue",amount:.55},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@yellow",spaceStar:"@foreground",
    exitLight:"@yellow",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@yellow",retiringRoute:"@blue",retiringCountry:"@yellow"
   },
   settings:{
    "$.voidLightColor":"@yellow","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.23,"$.voidStarColor":"@foreground","$.voidStarBrightness":.5,
    "$.circuitPrimary":{base:"yellow",blend:"foreground",amount:.7},"$.circuitSecondary":"@yellow","$.circuitHighlight":"@foreground",
    "$.mapColor":"@yellow","$.mapFillColor":{base:"background",blend:"yellow",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@yellow",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,"$.designColors.10.haze":.04
   }
  }
 },

 "nord": {
  original: {
   roles:{
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@cyan",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@light_foreground",actionAccent:"@bright_foreground",
    diagramInk:"@foreground",diagramAccent:"@cyan",logoLight:"@cyan",
    exitLight:"@cyan",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@cyan",retiringRoute:"@blue",retiringCountry:"@cyan"
   },
   settings:{
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@cyan","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.85,
    "$.voidStarColor":"@foreground",
    "$.mapColor":"@cyan","$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@cyan","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@blue",
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@cyan",
    "$.layers.ripples.color":"@cyan",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.5},"$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@cyan","$.designColors.8.skyColor":"@blue",
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@cyan"
   }
  },
  meridian: {
   circuitLift:.32,
   roles:{
    background:"@dark_background",popupSurface:"@background",tooltipSurface:"@background",
    foreground:{base:"foreground",blend:"magenta",amount:.16},dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"magenta",amount:.16},uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@magenta",accent:"@magenta",uiBorder:"@blue",uiSelectionText:"@darker_background",
    actionInk:"@blue",actionAccent:{base:"magenta",blend:"foreground",amount:.7},
    diagramInk:"@foreground",diagramAccent:"@magenta",logoLight:"@magenta",
    globeLand:{base:"dark_background",blend:"blue",amount:.12},globeOcean:"@darker_background",
    globeBorder:{base:"background",blend:"blue",amount:.55},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@darker_background",spaceEffect:"@magenta",spaceStar:"@foreground",
    exitLight:"@magenta",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@magenta",retiringRoute:"@blue",retiringCountry:"@magenta"
   },
   settings:{
    "$.voidLightColor":"@magenta","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.3,"$.voidStarColor":"@foreground","$.voidStarBrightness":.5,
    "$.circuitPrimary":{base:"magenta",blend:"foreground",amount:.7},"$.circuitSecondary":"@magenta","$.circuitHighlight":"@foreground",
    "$.mapColor":"@magenta","$.mapFillColor":{base:"background",blend:"magenta",amount:.18},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.16,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@magenta",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,"$.designColors.10.haze":.04
   }
  }
 },

 "white": {
  original: {
   actionStrokeScale:1.45,actionGlowScale:0,logoActiveStrokeScale:1.3,
   coverageVoid:true,circuitInkGain:1.65,circuitUnderlay:"@background",
   roles:{
    actionInk:"@muted",actionAccent:"@foreground",logoLight:"@foreground",logoIdle:"@muted",
    uiText:"@foreground",uiMuted:"@accent",uiHeading:"@foreground",
    uiAccent:"@blue",uiSelectionText:"@background",
    exitLight:"@muted",originRoute:"@foreground",transitionLight:"@accent",
    enteringRoute:"@blue",retiringRoute:"@accent",retiringCountry:"@muted"
   },
   settings:{
    "$.voidColor":"@background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@blue","$.voidLightStrength":1.08,
    "$.voidStarColor":{base:"accent",blend:"foreground",amount:.15},"$.voidStarSize":.82,
    "$.mapColor":"@muted","$.mapFillColor":"@muted","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@foreground","$.layers.tunnel.highlightColor":"@blue","$.layers.tunnel.guideColor":"@foreground",
    "$.layers.tunnel.width":1.3,"$.layers.tunnel.intensity":1,
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@blue",
    "$.layers.particles.width":.9,"$.layers.particles.intensity":1,
    "$.layers.ripples.color":"@blue","$.layers.ripples.width":1.2,"$.layers.ripples.intensity":.5,
    "$.designColors.8.land":"@background","$.designColors.8.ocean":{base:"blue",blend:"accent",amount:.45},"$.designColors.8.borders":"@background",
    "$.designColors.8.brightness":1,
    "$.designColors.8.atmosphere":"@accent","$.designColors.8.skyColor":"@blue",
    "$.designColors.8.atmosphereStrength":.7,"$.designColors.8.atmosphereWidth":.045,"$.designColors.8.haze":.06,
    "$.designColors.8.lamps":"@background","$.designColors.8.effect":"@muted"
   }
  },
  meridian: {
   actionStrokeScale:1.45,actionGlowScale:0,logoActiveStrokeScale:1.3,overlayOutline:true,
   circuitLift:.32,circuitInkGain:1.8,circuitStrokeScale:1.8,
   roles:{
    actionInk:"@muted",actionAccent:"@foreground",overlayBorder:"@accent",logoIdle:"@muted",
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    foreground:"@foreground",dark_foreground:"@accent",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@accent",uiHeading:"@foreground",
    accent:"@blue",uiAccent:"@blue",uiBorder:"@accent",uiSelectionText:"@background",
    diagramInk:"@foreground",diagramAccent:"@blue",logoLight:"@foreground",
    globeLand:"@muted",globeOcean:"@muted",globeBorder:"@foreground",globeHighlight:"@background",
    spaceVoid:"@background",spaceFade:"@dark_background",spaceEffect:"@accent",spaceStar:"@accent",
    exitLight:"@muted",originRoute:"@foreground",transitionLight:"@accent",
    enteringRoute:"@blue",retiringRoute:"@accent",retiringCountry:"@muted"
   },
   settings:{
    "$.voidLightColor":"@accent","$.spaceSecondaryColor":"@blue","$.voidLightStrength":.52,
    "$.voidStarColor":{base:"accent",blend:"foreground",amount:.15},"$.voidStarBrightness":.68,"$.voidStarSize":.43,
    "$.circuitPrimary":"@foreground","$.circuitSecondary":"@accent","$.circuitHighlight":"@blue",
    "$.mapColor":"@accent","$.mapFillColor":"@muted","$.markerColor":"@foreground",
    "$.designColors.10.grid":.12,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@accent",
    "$.designColors.10.atmosphereStrength":.45,"$.designColors.10.atmosphereWidth":.035,"$.designColors.10.haze":.04
   }
  }
 },
 "vantablack": {
  original:{roles:{actionInk:"@accent",actionAccent:"@foreground"}},
  meridian:{roles:{actionInk:"@accent",actionAccent:"@foreground"}}
 },
 "flexoki-light": {
  original: {
   coverageVoid:true,
   circuitInkGain:1.65,
   circuitUnderlay:"@background",
   roles: {
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:"@blue",uiSelectionText:"@background",
    diagramInk:"@foreground",diagramAccent:"@blue",
    exitLight:"@blue",originRoute:"@foreground",transitionLight:"@blue",
    enteringRoute:"@blue",retiringRoute:"@light_foreground",retiringCountry:"@blue"
   },
   settings: {
    "$.voidColor":"@background","$.voidFade":"@dark_background",
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":1.3,"$.voidStarColor":"@light_foreground",
    "$.mapColor":"@blue","$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.layers.tunnel.color":"@blue","$.layers.tunnel.highlightColor":"@blue","$.layers.tunnel.guideColor":"@foreground",
    "$.layers.tunnel.width":1.3,"$.layers.tunnel.intensity":1,
    "$.layers.particles.color":"@foreground","$.layers.particles.colorMix.0.color":"@foreground","$.layers.particles.colorMix.1.color":"@blue",
    "$.layers.particles.width":.85,"$.layers.particles.intensity":1,
    "$.layers.ripples.color":"@blue","$.layers.ripples.width":1.2,"$.layers.ripples.intensity":.5,
    "$.designColors.8.land":"@blue","$.designColors.8.ocean":"@dark_background",
    "$.designColors.8.borders":"@light_foreground",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@magenta",
    "$.designColors.8.atmosphereStrength":.8,"$.designColors.8.atmosphereWidth":.055,"$.designColors.8.haze":.07,
    "$.designColors.8.lamps":"@blue","$.designColors.8.effect":"@blue"
   }
  },
  meridian: {
   circuitLift:.32,
   circuitInkGain:1.8,circuitStrokeScale:1.8,
   roles: {
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    foreground:"@foreground",dark_foreground:"@light_foreground",
    light_foreground:"@light_foreground",bright_foreground:"@foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@foreground",
    accent:"@blue",uiAccent:"@blue",uiBorder:"@light_foreground",uiSelectionText:"@background",
    diagramInk:"@foreground",diagramAccent:"@blue",logoLight:"@blue",
    globeLand:"@light_foreground",globeOcean:"@light_foreground",globeBorder:"@foreground",globeHighlight:"@background",
    spaceVoid:"@background",spaceFade:"@dark_background",spaceEffect:"@blue",spaceStar:"@light_foreground",
    exitLight:"@blue",originRoute:"@foreground",transitionLight:"@blue",
    enteringRoute:"@blue",retiringRoute:"@light_foreground",retiringCountry:"@blue"
   },
   settings: {
    "$.voidLightColor":"@blue","$.spaceSecondaryColor":"@magenta","$.voidLightStrength":.45,
    "$.voidStarColor":"@light_foreground","$.voidStarBrightness":.35,
    "$.circuitPrimary":"@foreground","$.circuitSecondary":"@blue","$.circuitHighlight":"@foreground",
    "$.mapColor":"@blue","$.mapFillColor":{base:"background",blend:"blue",amount:.10},"$.markerColor":"@foreground",
    "$.designColors.10.grid":.08,"$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@magenta",
    "$.designColors.10.atmosphereStrength":.65,"$.designColors.10.atmosphereWidth":.045,"$.designColors.10.haze":.05
   }
  }
 },
 "matte-black": {
  original: {
   roles: {
    transitionLight:"@bright_cyan",retiringCountry:"@accent",
    enteringRoute:"@accent",retiringRoute:"@light_foreground",
    encryptionKey1:"@accent",encryptionKey2:"@bright_cyan",encryptionKey3:"@foreground"
   },
   settings: {
    "$.voidLightColor":"@accent","$.markerColor":"@bright_cyan",
    "$.layers.tunnel.highlightColor":"@bright_cyan",
    "$.layers.tunnel.colorMix.0.color":"@accent","$.layers.tunnel.colorMix.1.color":"@bright_cyan",
    "$.layers.particles.color":"@accent","$.layers.particles.guideColor":"@foreground",
    "$.layers.particles.colorMix.0.color":"@accent","$.layers.particles.colorMix.1.color":"@bright_cyan",
    "$.layers.ripples.color":"@accent","$.layers.ripples.guideColor":"@foreground",
    "$.layers.ripples.colorMix.0.color":"@accent","$.layers.ripples.colorMix.1.color":"@bright_cyan",
    "$.designColors.8.skyColor":"@foreground"
   }
  },
  meridian: {
   circuitLift:.32,
   roles: {
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    foreground:"@foreground",dark_foreground:"@light_foreground",
    light_foreground:"@light_foreground",bright_foreground:"@bright_cyan",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@bright_cyan",
    accent:"@accent",uiAccent:"@accent",uiBorder:"@light_foreground",uiSelectionText:"@darker_background",
    diagramInk:"@foreground",diagramAccent:"@accent",logoLight:"@accent",
    globeLand:{base:"background",blend:"foreground",amount:.06},
    globeOcean:"@darker_background",globeBorder:{base:"background",blend:"foreground",amount:.30},
    globeHighlight:"@foreground",
    spaceVoid:"@darker_background",spaceFade:"@dark_background",spaceEffect:"@accent",spaceStar:"@foreground",
    exitLight:"@accent",originRoute:"@foreground",transitionLight:"@bright_cyan",
    enteringRoute:"@accent",retiringRoute:"@light_foreground",retiringCountry:"@accent"
   },
   settings: {
    "$.voidStarColor":"@foreground","$.voidLightColor":"@accent",
    "$.spaceSecondaryColor":"@foreground","$.voidLightStrength":.22,"$.voidStarBrightness":.35,
    "$.circuitPrimary":"@accent","$.circuitSecondary":"@bright_cyan",
    "$.mapColor":"@accent","$.mapFillColor":{base:"background",blend:"accent",amount:.18},
    "$.markerColor":"@bright_cyan",
    "$.designColors.10.grid":.12,
    "$.designColors.10.atmosphere":"@light_foreground","$.designColors.10.skyColor":"@foreground",
    "$.designColors.10.atmosphereStrength":.16,"$.designColors.10.atmosphereWidth":.018,
    "$.designColors.10.haze":.025
   }
  }
 },
 "catppuccin-latte": {
  meridian: {
   roles: {
    foreground:"@foreground",dark_foreground:"@light_foreground",
    light_foreground:"@light_foreground",bright_foreground:"@bright_foreground",
    uiText:"@foreground",uiMuted:"@light_foreground",uiHeading:"@bright_foreground",
    accent:{base:"magenta",blend:"foreground",amount:.60},
    uiAccent:{base:"magenta",blend:"foreground",amount:.60},
    uiBorder:"@light_foreground",uiSelectionText:"@background",
    diagramInk:"@foreground",diagramAccent:{base:"magenta",blend:"foreground",amount:.60},
    logoLight:{base:"magenta",blend:"foreground",amount:.60}
   }
  }
 },
 "tokyo-night": {
  original: {
   roles: {
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    uiText:{base:"foreground",blend:"blue",amount:.20},uiMuted:"@light_foreground",uiHeading:"@bright_foreground",
    uiAccent:"@blue",uiBorder:"@blue",uiSelectionText:"@darker_background",
    diagramInk:"@foreground",diagramAccent:"@blue",
    logoLight:"@blue",exitLight:"@red",originRoute:"@blue",transitionLight:"@orange",
    enteringRoute:"@red",retiringRoute:"@magenta",retiringCountry:"@red",
    encryptionKey1:"@blue",encryptionKey2:"@red",encryptionKey3:"@orange"
   },
   settings: {
    "$.mapColor":"@red","$.mapFillColor":"@red","$.markerColor":"@orange",
    "$.voidColor":"@dark_background","$.voidFade":"@background",
    "$.voidStarColor":"@light_foreground","$.voidLightColor":"@red","$.voidLightStrength":.65,
    "$.layers.tunnel.color":"@blue","$.layers.tunnel.highlightColor":"@light_foreground","$.layers.tunnel.guideColor":"@red",
    "$.layers.particles.color":"@red","$.layers.particles.colorMix.0.color":"@red","$.layers.particles.colorMix.1.color":"@orange",
    "$.layers.ripples.color":"@red",
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.36},
    "$.designColors.8.ocean":"@dark_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":"@red",
    "$.designColors.8.lamps":"@orange","$.designColors.8.effect":"@red"
   }
  },
  meridian: {
   circuitLift:.32,
   roles: {
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    foreground:{base:"foreground",blend:"red",amount:.20},
    dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@bright_foreground",
    uiText:{base:"foreground",blend:"red",amount:.20},uiMuted:"@light_foreground",uiHeading:"@bright_foreground",
    uiAccent:"@red",accent:"@red",uiBorder:"@red",uiSelectionText:"@darker_background",
    diagramInk:"@foreground",diagramAccent:"@red",logoLight:"@red",
    globeLand:{base:"background",blend:"blue",amount:.08},
    globeOcean:"@dark_background",globeBorder:{base:"background",blend:"blue",amount:.52},globeHighlight:"@blue",
    spaceVoid:"@dark_background",spaceFade:"@background",spaceEffect:"@red",spaceStar:"@light_foreground",
    exitLight:"@red",originRoute:"@blue",transitionLight:"@orange",
    enteringRoute:"@red",retiringRoute:"@magenta",retiringCountry:"@red",
    encryptionKey1:"@blue",encryptionKey2:"@red",encryptionKey3:"@orange"
   },
   settings: {
    "$.voidStarColor":"@light_foreground","$.voidLightColor":"@red",
    "$.spaceSecondaryColor":"@blue","$.voidLightStrength":.48,"$.voidStarBrightness":.45,
    "$.circuitPrimary":{base:"red",blend:"bright_foreground",amount:.85},"$.circuitSecondary":"@orange",
    "$.mapColor":"@red","$.mapFillColor":{base:"background",blend:"red",amount:.22},"$.markerColor":"@orange",
    "$.designColors.10.grid":.16,
    "$.designColors.10.atmosphere":"@blue","$.designColors.10.skyColor":"@red",
    "$.designColors.10.atmosphereStrength":.25,"$.designColors.10.atmosphereWidth":.028,
    "$.designColors.10.haze":.04
   }
  }
 },
 catppuccin: {
  original: {
   roles: {
    background:"@background",popupSurface:"@background",tooltipSurface:"@dark_background",
    uiText:{base:"foreground",blend:"blue",amount:.14},uiMuted:"@light_foreground",uiHeading:"@bright_foreground",
    uiAccent:"@blue",uiBorder:"@light_foreground",uiSelectionText:"@darker_background",
    diagramInk:"@foreground",diagramAccent:"@blue",
    logoLight:{base:"blue",blend:"foreground",amount:.35},
    exitLight:"@blue",originRoute:"@blue",transitionLight:"@foreground",
    enteringRoute:"@blue",retiringRoute:"@light_foreground",retiringCountry:"@blue"
   },
   settings: {
    "$.mapColor":"@blue","$.mapFillColor":"@blue","$.markerColor":"@foreground",
    "$.voidColor":"@darker_background","$.voidFade":"@dark_background",
    "$.voidStarColor":"@foreground","$.voidLightColor":{base:"blue",blend:"foreground",amount:.25},
    "$.voidLightStrength":.85,
    "$.layers.tunnel.color":"@blue","$.layers.tunnel.highlightColor":"@foreground","$.layers.tunnel.guideColor":"@foreground",
    "$.layers.particles.color":{base:"blue",blend:"foreground",amount:.55},
    "$.layers.particles.colorMix.0.color":"@blue","$.layers.particles.colorMix.1.color":"@foreground",
    "$.layers.ripples.color":{base:"blue",blend:"foreground",amount:.55},
    "$.designColors.8.land":{base:"background",blend:"blue",amount:.48},
    "$.designColors.8.ocean":"@darker_background","$.designColors.8.borders":"@blue",
    "$.designColors.8.atmosphere":"@blue","$.designColors.8.skyColor":{base:"blue",blend:"foreground",amount:.25},
    "$.designColors.8.lamps":"@foreground","$.designColors.8.effect":"@blue"
   }
  },
  meridian: {
   circuitLift:.32,
   roles: {
    background:{base:"darker_background",blend:"magenta",amount:.02},
    popupSurface:{base:"darker_background",blend:"magenta",amount:.02},
    tooltipSurface:{base:"darker_background",blend:"magenta",amount:.02},
    foreground:{base:"foreground",blend:"magenta",amount:.10},
    dark_foreground:"@light_foreground",light_foreground:"@foreground",bright_foreground:"@foreground",
    uiText:{base:"foreground",blend:"magenta",amount:.10},
    uiMuted:"@light_foreground",uiHeading:"@foreground",
    uiAccent:{base:"magenta",blend:"foreground",amount:.30},accent:{base:"magenta",blend:"foreground",amount:.30},uiBorder:"@light_foreground",uiSelectionText:"@darker_background",
    diagramInk:"@foreground",diagramAccent:{base:"magenta",blend:"foreground",amount:.30},
    logoLight:{base:"magenta",blend:"foreground",amount:.25},
    globeLand:{base:"background",blend:"magenta",amount:.05},
    globeOcean:"@darker_background",globeBorder:{base:"background",blend:"foreground",amount:.40},globeHighlight:"@foreground",
    spaceVoid:{base:"darker_background",blend:"magenta",amount:.02},
    spaceFade:{base:"dark_background",blend:"magenta",amount:.035},
    spaceEffect:{base:"magenta",blend:"foreground",amount:.30},spaceStar:"@foreground",
    exitLight:"@magenta",originRoute:"@magenta",transitionLight:"@foreground",
    enteringRoute:"@magenta",retiringRoute:"@light_foreground",retiringCountry:"@magenta",
    encryptionKey1:"@magenta",encryptionKey2:"@blue",encryptionKey3:"@yellow"
   },
   settings: {
    "$.voidStarColor":"@foreground","$.voidLightColor":{base:"magenta",blend:"foreground",amount:.30},
    "$.spaceSecondaryColor":"@foreground","$.voidLightStrength":.28,
    "$.voidStarBrightness":.45,
    "$.circuitPrimary":{base:"magenta",blend:"foreground",amount:.30},"$.circuitSecondary":"@foreground",
    "$.mapColor":"@magenta","$.mapFillColor":{base:"background",blend:"magenta",amount:.22},
    "$.designColors.10.grid":.20,
    "$.designColors.10.atmosphere":{base:"magenta",blend:"foreground",amount:.30},"$.designColors.10.skyColor":"@foreground",
    "$.designColors.10.atmosphereStrength":.28,"$.designColors.10.atmosphereWidth":.028,
    "$.designColors.10.haze":.04
   }
  }
 }
};

// Curated role choices; values remain tied to each desktop's own palette.
// Jade is deliberately empty: all original values and extension colors survive.
var profiles={
 "osaka-jade":{},
 "catppuccin":{exitLight:"@bright_cyan",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "catppuccin-latte":{exitLight:"@cyan",originRoute:"@blue",transitionLight:"@orange",retiringCountry:"@magenta"},
 "ethereal":{exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_magenta"},
 "everforest":{exitLight:"@bright_green",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "flexoki-light":{exitLight:"@cyan",originRoute:"@blue",transitionLight:"@orange",retiringCountry:"@red"},
 "gruvbox":{exitLight:"@bright_green",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "hackerman":{exitLight:"@bright_green",originRoute:"@cyan",transitionLight:"@bright_cyan"},
 "kanagawa":{exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_yellow"},
 "last-horizon":{exitLight:"@bright_cyan",originRoute:"@cyan",transitionLight:"@bright_magenta"},
 "lumon":{exitLight:"@cyan",originRoute:"@blue",transitionLight:"@orange"},
 "lupine":{exitLight:"@bright_magenta",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "matte-black":{exitLight:"@bright_foreground",originRoute:"@bright_blue",transitionLight:"@bright_yellow"},
 "miasma":{exitLight:"@bright_green",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "nord":{exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_yellow"},
 "retro-82":{exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_yellow"},
 "ristretto":{exitLight:"@bright_cyan",originRoute:"@cyan",transitionLight:"@bright_yellow"},
 "rose-pine":{exitLight:"@cyan",originRoute:"@blue",transitionLight:"@bright_yellow"},
 "solitude":{exitLight:"@cyan",originRoute:"@blue",transitionLight:"@orange"},
 "tokyo-night":{exitLight:"@bright_cyan",originRoute:"@blue",transitionLight:"@bright_yellow"},
 "vantablack":{exitLight:"@bright_foreground",originRoute:"@bright_blue",transitionLight:"@bright_foreground",retiringCountry:"@muted"},
 "white":{exitLight:"@foreground",originRoute:"@blue",transitionLight:"@foreground",retiringCountry:"@muted"}
};
