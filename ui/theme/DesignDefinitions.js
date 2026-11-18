.pragma library
// Generated from assets/theme-style.json by tools/sync_themes.py.
var contract = {
  "defaults": {
    "actionLayout": "flow",
    "paletteProfile": "original",
    "colorModel": "calibrated",
    "voidMode": 0,
    "spaceStyle": 0,
    "circuitRenderer": "ember",
    "circuitMaterial": 1,
    "build": 1.5,
    "retire": 12,
    "padding": 16,
    "spacing": 12,
    "radiusBoost": 0,
    "opaqueText": false,
    "opaqueRelay": false,
    "outline": 1,
    "headerScale": 1.15,
    "softIllumination": true,
    "hoverPulse": true,
    "markerSize": 8,
    "markerInset": 0,
    "markerVariant": 1,
    "diagram": 0,
    "diagramSquareLayers": true,
    "diagramRoundLines": true,
    "diagramGlow": true,
    "diagramDashed": false,
    "diagramHaloOpacity": 0.08,
    "diagramHaloWidth": 9,
    "diagramLineOpacity": 0.65,
    "diagramLineWidth": 1,
    "fileLineWidth": 1.4,
    "fileLineOpacity": 0.75,
    "cameraDelay": 6,
    "cameraBlend": 12,
    "cameraMaxRate": 6,
    "cameraZoomBlend": 12,
    "customCameraRelease": false,
    "frameZoomOnOpen": false
  },
  "legacy": {
    "original": {},
    "meridian": {
      "actionLayout": "arc",
      "paletteProfile": "meridian",
      "colorModel": "spectral",
      "voidMode": 2,
      "spaceStyle": 1,
      "circuitRenderer": "material",
      "circuitMaterial": 1,
      "build": 1.8,
      "retire": 2.4,
      "padding": 14,
      "spacing": 10,
      "opaqueText": true,
      "opaqueRelay": true,
      "outline": 0,
      "softIllumination": false,
      "hoverPulse": false,
      "markerSize": 4,
      "markerInset": 5,
      "markerVariant": 0,
      "diagram": 1,
      "diagramSquareLayers": false,
      "diagramRoundLines": false,
      "diagramGlow": false,
      "diagramDashed": true,
      "diagramHaloOpacity": 0,
      "diagramLineOpacity": 1,
      "fileLineOpacity": 1,
      "customCameraRelease": true,
      "cameraDelay": 0.6,
      "cameraBlend": 3,
      "cameraMaxRate": 24,
      "frameZoomOnOpen": true
    },
    "porcelain": {
      "paletteProfile": "porcelain",
      "colorModel": "paper",
      "voidMode": 3,
      "spaceStyle": 2,
      "circuitRenderer": "material",
      "circuitMaterial": 2,
      "build": 2.4,
      "retire": 2.8,
      "padding": 20,
      "spacing": 16,
      "radiusBoost": 5,
      "opaqueText": true,
      "opaqueRelay": true,
      "softIllumination": false,
      "diagram": 2,
      "diagramGlow": false,
      "diagramHaloOpacity": 0.12,
      "diagramHaloWidth": 6,
      "diagramLineOpacity": 1,
      "diagramLineWidth": 2,
      "fileLineWidth": 2,
      "fileLineOpacity": 1
    }
  },
  "enums": {
    "actionLayout": [
      "flow",
      "arc"
    ],
    "colorModel": [
      "calibrated",
      "spectral",
      "paper"
    ],
    "circuitRenderer": [
      "ember",
      "material"
    ]
  },
  "ranges": {
    "voidMode": [
      0,
      3
    ],
    "spaceStyle": [
      0,
      2
    ],
    "circuitMaterial": [
      1,
      2
    ],
    "build": [
      0.1,
      30
    ],
    "retire": [
      0.1,
      30
    ],
    "padding": [
      0,
      40
    ],
    "spacing": [
      0,
      40
    ],
    "radiusBoost": [
      0,
      14
    ],
    "outline": [
      0,
      1
    ],
    "headerScale": [
      0.85,
      1.5
    ],
    "markerSize": [
      2,
      12
    ],
    "markerInset": [
      0,
      12
    ],
    "markerVariant": [
      0,
      2
    ],
    "diagram": [
      0,
      2
    ],
    "diagramHaloOpacity": [
      0,
      1
    ],
    "diagramHaloWidth": [
      0,
      20
    ],
    "diagramLineOpacity": [
      0,
      1
    ],
    "diagramLineWidth": [
      0.5,
      5
    ],
    "fileLineWidth": [
      0.5,
      5
    ],
    "fileLineOpacity": [
      0,
      1
    ],
    "cameraDelay": [
      0,
      30
    ],
    "cameraBlend": [
      0.1,
      30
    ],
    "cameraMaxRate": [
      1,
      180
    ],
    "cameraZoomBlend": [
      0.1,
      30
    ]
  },
  "integers": [
    "voidMode",
    "spaceStyle",
    "circuitMaterial",
    "outline",
    "markerVariant",
    "diagram"
  ]
}
function validate(value) {
 if(value===undefined)return {};
 if(!value||typeof value!=="object"||Array.isArray(value))throw new Error("Invalid presentation style");
 Object.keys(value).forEach(function(key){
  if(!Object.prototype.hasOwnProperty.call(contract.defaults,key))throw new Error("Unknown presentation setting: "+key);
  var v=value[key],base=contract.defaults[key],range=contract.ranges[key],choices=contract.enums[key];
  if(typeof v!==typeof base||(typeof v==="number"&&!isFinite(v)))throw new Error("Invalid presentation setting: "+key);
  if(choices&&choices.indexOf(v)<0)throw new Error("Invalid presentation choice: "+key);
  if(range&&(v<range[0]||v>range[1]))throw new Error("Presentation setting out of range: "+key);
  if(contract.integers.indexOf(key)>=0&&!Number.isInteger(v))throw new Error("Invalid presentation integer: "+key);
  if(key==="paletteProfile"&&!/^[a-zA-Z0-9_-]+$/.test(v))throw new Error("Invalid palette profile");
 });
 return value;
}
function resolve(design,style) {
 var result=Object.assign({},contract.defaults,contract.legacy[design]||{},validate(style));
 // cameraZoomBlend is accepted for old publications, but never splits pose recovery.
 result.cameraRelease=result.customCameraRelease?{delay:result.cameraDelay,blend:result.cameraBlend,maxRate:result.cameraMaxRate}:{};
 return result;
}
