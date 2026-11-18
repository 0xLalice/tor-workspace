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
