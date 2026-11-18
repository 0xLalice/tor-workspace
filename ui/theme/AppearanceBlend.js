.pragma library

function color(value) {return typeof value==="string"&&/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value)}
function mix(a,b,t) {
 var x=Qt.color(a),y=Qt.color(b)
 return String(Qt.rgba(x.r+(y.r-x.r)*t,x.g+(y.g-x.g)*t,x.b+(y.b-x.b)*t,x.a+(y.a-x.a)*t))
}
function blend(a,b,t,path) {
 if(t>=1||a===undefined)return b
 if(t<=0)return a
 if(color(a)&&color(b))return mix(a,b,t)
 // The camera keeps its orbit phase while the selected design's framing eases.
 if(path==="$.settings.zoom"&&typeof a==="number"&&typeof b==="number")return a+(b-a)*t
 // Route geometry, timing, counts and discrete shader modes never tween.
 if(typeof a==="number"&&typeof b==="number") {
  if(/trajectory|camera|zoom|longitude|latitude|spinRate|count|seed|mode|style|timing/i.test(path))return b
  return a+(b-a)*t
 }
 if(Array.isArray(b))return b.map((value,i)=>blend((a||[])[i],value,t,path+"."+i))
 if(b&&typeof b==="object"){
  var result={};Object.keys(b).forEach(key=>result[key]=blend((a||{})[key],b[key],t,path+"."+key));return result
 }
 return b
}
