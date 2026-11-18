.pragma library
// Approved Ember Wake surface appearance. Shared by live and viewer renderers.
var id="soft-illumination";
var config={
  "timing": {
    "enter": 4,
    "exit": 5,
    "enterDelay": 0,
    "exitDelay": 0.5,
    "sequential": false,
    "stagger": 0,
    "order": 0
  },
  "country": {
    "theme": true,
    "width": 0.6,
    "brightness": 0.7,
    "fill": 0.3,
    "glow": 0.25,
    "color": "#f3dc85",
    "oldColor": "#d99c62",
    "blend": 0.2
  },
  "surface": {
    "enter": 0,
    "exit": 0
  },
  "scan": {
    "direction": 0,
    "width": 0.12,
    "origin": 0,
    "speed": 1,
    "softness": 0.12,
    "reverse": false
  },
  "fragments": {
    "pulses": 1,
    "radius": 0.5,
    "softness": 0.15,
    "size": 0.08,
    "density": 0.7,
    "stagger": 0.5,
    "seed": 17,
    "dissolve": 0.12
  },
  "marker": {
    "size": 4,
    "opacity": 0.8,
    "glow": 0.85,
    "halo": 6,
    "theme": true,
    "color": "#f3dc85",
    "oldColor": "#d99c62",
    "blend": 0.2
  },
  "markerMotion": {
    "enter": 0,
    "exit": 0,
    "startScale": 0.15,
    "endScale": 0.1,
    "pulse": 0.5,
    "pulses": 1,
    "bounce": 0,
    "stagger": 0,
    "height": 24
  },
  "markerTiming": {
    "enter": 4,
    "exit": 5,
    "enterDelay": 0.15,
    "exitDelay": 0.5,
    "sequential": false,
    "stagger": 0,
    "order": 0,
    "seed": 17
  },
  "labels": {
    "mode": 0,
    "text": 0,
    "size": 11,
    "offset": 12,
    "delay": 0.3,
    "fade": 0.6,
    "suppress": true
  }
};
function adopt(settings){return Object.assign({},settings,{transitionPreset:"ember",surfacePreset:id,cameraPreset:"circuit-orbit"})}
function progress(clock,enter){var t=config.timing;return Math.max(0,Math.min(1,(clock-(enter?t.enterDelay:t.exitDelay))/(enter?t.enter:t.exit)))}
