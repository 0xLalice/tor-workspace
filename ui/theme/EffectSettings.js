.pragma library
.import "DesignDefinitions.js" as Presentation
var keys=["packets","arcs","ribbon","tunnel","particles","ripples"];
var labels=["Packets","Moving arcs","Ribbon","Tunnel","Particles","Ripples"];
var counts={packets:14,arcs:3,ribbon:4,tunnel:16,particles:48,ripples:2};
function layer(settings,key) {
    var s=settings||{};
    return Object.assign({count:counts[key],speed:s.speed===undefined?1:s.speed,
        intensity:s.intensity===undefined?0.8:s.intensity,width:s.thickness===undefined?1:s.thickness,
        glow:s.glow===undefined?0.3:s.glow,palette:s.palette===undefined?1:s.palette,
        rails:true,rings:true,core:true,stream:false,railCount:4,tubeRadius:1,streamCount:12,streamSpeed:1,streamLength:0.018,
        length:key==="arcs"?0.25:0.015,spread:0,radius:0.2},(s.layers||{})[key]||{});
}
function trajectory(settings) {
    return Object.assign({height:0.22,profile:1},(settings||{}).trajectory||{});
}
function editLayer(settings,key,field,value) {
    var next=Object.assign({},settings), layers=Object.assign({},next.layers||{});
    layers[key]=Object.assign({},layer(settings,key)); layers[key][field]=value;
    next.layers=layers; return next;
}

// Osaka Jade's complete palette, including its neutral surfaces.
var swatches=[
 {name:"Deepest",hex:"#090f0d"},{name:"Dark",hex:"#0c1512"},{name:"Background",hex:"#111c18"},
 {name:"Raised",hex:"#23372B"},{name:"Selection",hex:"#32473B"},{name:"Muted",hex:"#53685B"},
 {name:"Jade",hex:"#509475"},{name:"Sage",hex:"#81B8A8"},{name:"Pale teal",hex:"#ACD4CF"},
 {name:"Sea glass",hex:"#8CD3CB"},{name:"Mint",hex:"#75bbb3"},{name:"Cyan",hex:"#2DD5B7"},
 {name:"Green",hex:"#549e6a"},{name:"Bright green",hex:"#63b07a"},{name:"Forest",hex:"#459451"},
 {name:"Cream",hex:"#C1C497"},{name:"Ivory",hex:"#D6D5BC"},{name:"Warm light",hex:"#F7E8B2"},
 {name:"Gold",hex:"#E5C736"},{name:"Copper",hex:"#a2734b"},{name:"Brown",hex:"#513925"},
 {name:"Rose",hex:"#db9f9c"},{name:"Magenta",hex:"#D2689C"},{name:"Coral",hex:"#FF5345"}
];
var designNames=["Eclipse","Orbital","Bloom","Nightwatch","Relay","Comet","Fireflies","Aurora","Airways","Atlas"];
var presetNames=["Jade & ivory","Sea glass","Copper & jade","Mint signal","Warm atlas","Silver sage","Rose quartz","Emerald night"];
// land, borders, atmosphere, lamps, suggested effect
var schemes=[
 ["#509475","#D6D5BC","#81B8A8","#F7E8B2","#ACD4CF"],
 ["#81B8A8","#ACD4CF","#8CD3CB","#D6D5BC","#2DD5B7"],
 ["#53685B","#81B8A8","#509475","#a2734b","#F7E8B2"],
 ["#509475","#8CD3CB","#75bbb3","#ACD4CF","#2DD5B7"],
 ["#C1C497","#D6D5BC","#a2734b","#F7E8B2","#509475"],
 ["#53685B","#D6D5BC","#ACD4CF","#8CD3CB","#81B8A8"],
 ["#81B8A8","#db9f9c","#75bbb3","#D6D5BC","#D2689C"],
 ["#549e6a","#81B8A8","#509475","#F7E8B2","#63b07a"]
];
var designPresets=[0,5,1,2,4,1,7,3,5,4];
function scheme(index) {
 var c=schemes[index];
 return {land:c[0],borders:c[1],atmosphere:c[2],lamps:c[3],effect:c[4],ocean:"#111c18"};
}
function colors(settings,appearance) {
 var s=settings||{}, a=Math.max(0,Math.min(11,appearance||0));
 return Object.assign({brightness:1,detail:1,borderWidth:1,borderLight:1,atmosphereStrength:0.65,groundLight:1,grid:0.35,
  waterRoughness:0.22,waveHeight:0.09,waterReflection:1,waterMode:0,waterStrength:0.85,waterScale:12,waterSpeed:0.35,waterColor:"#81B8A8",
  layeredAtmosphere:true,atmosphereWidth:0.045,haze:0.12,skyColor:"#ACD4CF",
  clouds:false,cloudOpacity:0.25,cloudCoverage:0.45,cloudSpeed:0.2,cloudColor:"#D6D5BC",sunAzimuth:-50,sunElevation:35},scheme(designPresets[a]===undefined?0:designPresets[a]),(s.designColors||{})[a]||{});
}
function editColor(settings,appearance,key,value) {
 var s=Object.assign({},settings), all=Object.assign({},s.designColors||{});
 all[appearance]=Object.assign({},all[appearance]||{});all[appearance][key]=value;
 s.designColors=all;return s;
}
function applyScheme(settings,appearance,index) {
 var s=Object.assign({},settings), all=Object.assign({},s.designColors||{});
 all[appearance]=Object.assign({},all[appearance]||{},scheme(index));s.designColors=all;return s;
}
function effectColor(params,fallback) {
 return params.color || ["#81B8A8","#ACD4CF","#C1C497"][params.palette] || fallback || "#509475";
}
function surfacePalette(settings) {
 var s=settings||{};
 return {panel:s.voidColor||"#090f0d",fade:s.voidFade||"#111c18",mode:s.voidMode===undefined?1:s.voidMode};
}

function defaults() {
 return {transitionPreset:"ember",spin:true,earthTilt:true,spinRate:3.6,reverse:false,packets:true,arcs:false,ribbon:false,tunnel:false,particles:false,ripples:true,
         speed:1,intensity:0.8,thickness:1,glow:0.3,palette:1,
         mapBorders:true,mapFill:true,mapIntensity:0.5};
}

// Curated random exploration: coordinated theme colors and restrained layers.
// Camera and rotation settings belong to the user and are never randomized.
function randomize(current,rng) {
 var random=rng||Math.random;
 function number(low,high){return low+(high-low)*random()}
 function integer(low,high){return low+Math.floor(random()*(high-low+1))}
 function chance(p){return random()<p}
 function pick(a){return a[integer(0,a.length-1)]}
 var palette=scheme(integer(0,schemes.length-1));
 var s=Object.assign({},current||{});
 s.layers={};s.designColors={};
 s.trajectory={height:number(0.10,0.34),profile:number(0.8,1.3)};
 var countRanges={packets:[8,22],arcs:[2,5],ribbon:[3,8],tunnel:[6,16],particles:[20,52],ripples:[1,3]};
 keys.forEach(function(k){
  s[k]=false;
  s.layers[k]={count:integer(countRanges[k][0],countRanges[k][1]),
   speed:number(0.3,1.1),intensity:number(0.45,0.78),width:number(0.65,1.35),glow:number(0.05,0.35),
   color:palette.effect,highlightColor:palette.borders,guideColor:palette.atmosphere,
   multicolor:chance(0.5),colorDistribution:"interleaved",colorMix:[{color:palette.effect,weight:70},{color:palette.borders,weight:25},{color:palette.atmosphere,weight:5}],
   length:k==="arcs"?number(0.12,0.32):number(0.01,0.035),spread:0,radius:number(0.07,0.18),
   rails:true,rings:chance(0.65),core:chance(0.4),stream:chance(0.45),railCount:integer(2,5),
   tubeRadius:number(0.5,1.1),streamCount:integer(6,16),streamSpeed:number(0.3,0.9),streamLength:number(0.01,0.035)};
 });
 // One leading route treatment; an optional lighter companion and surface rings.
 var primary=pick(["packets","arcs","ribbon","tunnel","particles"]);
 s[primary]=true;
 if(chance(0.45)) {
  var companion=pick(primary==="particles"?["arcs","ribbon"]:["particles","arcs"].filter(function(k){return k!==primary}));
  s[companion]=true;s.layers[companion].intensity=number(0.2,0.38);s.layers[companion].glow=number(0.03,0.15);
 }
 s.ripples=chance(0.4);s.layers.ripples.intensity=number(0.2,0.4);
 for(var d=0;d<10;d++)s.designColors[d]=Object.assign({},palette,{
  ocean:pick(["#090f0d","#0c1512","#111c18"]),
  waterMode:integer(0,3),waterStrength:number(0.7,0.95),waterScale:number(8,18),waterSpeed:number(0.15,0.4),waterColor:palette.atmosphere,
  layeredAtmosphere:true,atmosphereWidth:number(0.025,0.065),haze:number(0.04,0.15),skyColor:palette.borders,
  clouds:chance(0.3),cloudOpacity:number(0.1,0.25),cloudCoverage:number(0.3,0.5),cloudSpeed:number(0.1,0.25),cloudColor:palette.borders,
  borderWidth:number(0.6,1.5),borderLight:number(0.7,1.3),brightness:number(0.95,1.25),detail:number(0.7,1.2),atmosphereStrength:number(0.35,0.75),groundLight:number(0.7,1.2),grid:number(0.1,0.4)});
 s.mapMarkers=false;s.markerHalo=false;s.mapBorders=chance(0.7);s.mapFill=chance(0.35);s.mapPulse=chance(0.25);
 s.markerSize=number(1.5,3);s.markerIntensity=number(0.4,0.7);s.mapIntensity=number(0.25,0.5);s.mapWidth=number(0.7,1.3);s.mapSpeed=number(0.3,0.8);
 s.mapColor=palette.borders;s.mapFillColor=palette.land;s.markerColor=palette.effect;
 s.voidColor=pick(["#090f0d","#0c1512"]);s.voidFade=pick(["#0c1512","#111c18"]);s.voidMode=integer(0,2);
 s.voidStars=chance(0.75);s.voidDust=chance(0.25);s.voidNebula=chance(0.4);s.voidRays=chance(0.15);
 s.voidAnimate=chance(0.3);s.voidTwinkle=false;
 s.voidStarColor=palette.borders;s.voidLightColor=palette.atmosphere;
 s.voidDensity=number(0.15,0.4);s.voidStarSize=number(0.5,0.95);
 s.voidStarBrightness=number(0.2,0.45);s.voidStarGlow=number(0.1,0.3);s.voidLightStrength=number(0.2,0.6);s.voidSpeed=number(0.1,0.4);
 return {settings:s,appearance:integer(0,9)};
}

function mixedColor(entries,index,count,distribution,fallback) {
 var list=(entries||[]).filter(function(e){return e.weight>0});
 if(!list.length)return fallback;
 count=Math.max(1,Math.round(count));
 var total=list.reduce(function(sum,e){return sum+e.weight},0),used=0;
 var bins=list.map(function(e,i){var exact=e.weight/total*count,n=Math.floor(exact);used+=n;return {color:e.color,n:n,remainder:exact-n,index:i}});
 var order=bins.slice().sort(function(a,b){return b.remainder-a.remainder||a.index-b.index});
 for(var i=0;i<count-used;i++)order[i%order.length].n++;
 var rank=((Math.floor(index)%count)+count)%count;
 if(distribution!=="grouped") {
  function gcd(a,b){while(b){var t=b;b=a%b;a=t}return a}
  var stride=Math.max(1,Math.floor(count*0.61803398875));
  while(gcd(stride,count)!==1)stride++;
  rank=(rank*stride)%count;
 }
 for(var j=0;j<bins.length;j++){if(rank<bins[j].n)return bins[j].color;rank-=bins[j].n}
 return list[list.length-1].color;
}

// Resolve every visual default at SAVE time so a preset is self-contained.
// Apply never mixes a saved snapshot with the plugin's previous settings.
function completeSettings(settings,appearance,camera) {
 var source=JSON.parse(JSON.stringify(settings||{}));
 var profile=colors(source,appearance),surface=surfacePalette(source);
 var out=Object.assign({transitionPreset:"ember",spin:true,earthTilt:true,spinRate:3.6,reverse:false,zoom:1,
  elevation:camera&&isFinite(camera.latitude)?camera.latitude:0,viewReset:0,
  mapMarkers:false,markerHalo:false,markerSize:3,markerIntensity:0.8,
  mapBorders:false,mapFill:false,mapPulse:false,mapWidth:1,mapIntensity:0.6,mapSpeed:1,
  mapColor:source.mapColor||effectColor({palette:source.mapPalette},profile.effect),
  mapFillColor:source.mapFillColor||source.mapColor||effectColor({palette:source.mapPalette},profile.effect),
  markerColor:source.markerColor||source.mapColor||profile.effect,
  voidColor:surface.panel,voidFade:surface.fade,voidMode:surface.mode,
  voidStars:false,voidDust:false,voidNebula:false,voidRays:false,voidAnimate:false,voidTwinkle:false,
  voidStarColor:"#ACD4CF",voidLightColor:"#509475",voidDensity:0.4,voidStarSize:0.8,
  voidStarBrightness:0.45,voidStarGlow:0.35,voidLightStrength:0.6,voidSpeed:0.5},source);
 out.trajectory=trajectory(source);out.layers={};out.designColors={};
 keys.forEach(function(key){
  out[key]=!!source[key];var params=layer(source,key);
  out.layers[key]=Object.assign({multicolor:false,colorDistribution:"interleaved",colorMix:[],
   color:effectColor(params,profile.effect),highlightColor:profile.borders,guideColor:profile.atmosphere},params);
 });
 for(var d=0;d<10;d++)out.designColors[d]=colors(source,d);
 return JSON.parse(JSON.stringify(out));
}
function fileSharingConfig(value) {
 if(value===undefined)value={};
 if(value===null||typeof value!=="object"||Array.isArray(value))throw new Error("Invalid file sharing settings");
 var out={titleAlignment:"center",footerAlignment:"center",addAlignment:"center"};
 Object.keys(value).forEach(function(key){if(!(key in out)||["left","center"].indexOf(value[key])<0)throw new Error("Invalid file sharing alignment");out[key]=value[key]});
 return out;
}
function interfaceConfig(value) {
 var out=Object.assign({design:"original",layout:0,cyclingEnabled:true,reducedMotion:false,sentenceSize:12,sentenceInterval:45000,uiScale:1,cardStyle:1,relayInspector:0,activityMarker:1,noteStyle:0,onionLight:1},value||{});
 if(typeof out.design!=="string"||!/^[a-zA-Z0-9_-]+$/.test(out.design))throw new Error("Invalid interface design");
 out.style=Presentation.validate(out.style);
 out.fileSharing=fileSharingConfig(out.fileSharing);
 if(!Number.isInteger(out.onionLight)||out.onionLight<0||out.onionLight>3)throw new Error("Invalid onion lighting");
 if(!Number.isInteger(out.noteStyle)||out.noteStyle<0||out.noteStyle>7)throw new Error("Invalid cycling note style");
 if(!Number.isInteger(out.activityMarker)||out.activityMarker<0||out.activityMarker>2)throw new Error("Invalid activity marker");
 if(typeof out.cyclingEnabled!=="boolean")throw new Error("Invalid cycling setting");
 if(typeof out.reducedMotion!=="boolean")throw new Error("Invalid reduced motion setting");
 if(!Number.isInteger(out.relayInspector)||out.relayInspector<0||out.relayInspector>3)throw new Error("Invalid relay inspector");
 if(out.cardStyle!==0&&out.cardStyle!==1)throw new Error("Invalid card style");
 if(typeof out.uiScale!=="number"||!isFinite(out.uiScale)||out.uiScale<.85||out.uiScale>1.5)throw new Error("Invalid interface size");
 if(!Number.isInteger(out.layout)||out.layout<0||out.layout>14)throw new Error("Invalid interface layout");
 if(typeof out.sentenceSize!=="number"||!isFinite(out.sentenceSize)||out.sentenceSize<9||out.sentenceSize>20)throw new Error("Invalid sentence size");
 if(!Number.isInteger(out.sentenceInterval)||out.sentenceInterval<3000||out.sentenceInterval>60000)throw new Error("Invalid sentence interval");
 return out;
}
function snapshot(preset) {
 var result=JSON.parse(JSON.stringify(preset));
 if(!result.settings || !Number.isInteger(result.appearance) || result.appearance<0 || result.appearance>11)
  throw new Error("Invalid preset configuration");
 if(!result.settings.transitionPreset)result.settings.transitionPreset="ember";
 result.interface=interfaceConfig(result.interface);
 if(result.version===2)return result;
 if(result.version!==1)throw new Error("Unsupported preset version");
 result.camera=Object.assign({longitude:-24,latitude:0,viewRoll:0,automaticRotation:false},result.camera||{});
 result.settings=completeSettings(result.settings,result.appearance,result.camera);
 result.version=2;
 return result;
}
