.pragma library
.import "../circuit/RouteGeometry.js" as Geo
var rad=Math.PI/180;
function clamp(x,a,b){return Math.max(a===undefined?0:a,Math.min(b===undefined?1:b,x))}
function smooth(x){x=clamp(x);return x*x*(3-2*x)}
function mix(a,b,t){return a+(b-a)*t}
function delta(a,b){return ((b-a+540)%360+360)%360-180}
function hash(x){var v=Math.sin(x*127.1+311.7)*43758.5453;return v-Math.floor(v)}
function valid(route){return (route||[]).filter(function(h){return Geo.vector(h)!==null})}
function order(index,c,timing){var q=timing||c.timing;return q.order===1?3-index:q.order===2?hash(index+(q.seed===undefined?c.fragments.seed:q.seed))*3:index}
function progress(t,index,c,enter,marker){var q=marker&&c.markerTiming?c.markerTiming:c.timing,delay=enter?q.enterDelay:q.exitDelay,duration=enter?q.enter:q.exit;if(enter&&q.sequential)delay+=q.exitDelay+q.exit+3*q.stagger;delay+=order(index,c,q)*(q.stagger+(marker?c.markerMotion.stagger:0));return clamp((t-delay)/duration)}
function unique(route){var out=[];valid(route).forEach(function(h,i){if(!out.some(function(p){return Math.abs(p.longitude-h.longitude)<.0001&&Math.abs(p.latitude-h.latitude)<.0001}))out.push(Object.assign({index:i},h))});return out}
// Route identity, geographic vectors and label text change with the route,
// not with the camera or transition clock.
function prepareMarkers(a,b){var old=unique(a),next=unique(b),out=[];
 function add(h,enter){var same=(enter?old:next).some(function(v){return Math.abs(v.longitude-h.longitude)<.0001&&Math.abs(v.latitude-h.latitude)<.0001});if(!enter&&same)return;
  out.push({hop:h,enter:enter,shared:same,vector:Geo.vector(h),country:h.countryName||h.country||"Unknown",name:h.name||["Origin","Guard","Middle","Exit"][h.index]||"Relay"})}
 old.forEach(function(h){add(h,false)});next.forEach(function(h){add(h,true)});return out}
function markerRows(a,b,c,t,pose,size,departureConfig){return projectMarkers(prepareMarkers(a,b),c,t,pose,size,departureConfig)}
function projectMarkers(prepared,c,t,pose,size,departureConfig){var arrivalConfig=c,rows=[];
 var angle=(pose.roll+pose.tilt)*rad,ca=Math.cos(angle),sa=Math.sin(angle);
 for(var i=0;i<prepared.length;i++){var entry=prepared[i],h=entry.hop,enter=entry.enter,same=entry.shared,c=enter?arrivalConfig:(departureConfig||arrivalConfig);
 var q=Geo.project(entry.vector,pose.yaw,pose.pitch,size);if(q.z<.015)continue;var p=same?1:progress(t,h.index,c,enter,true),life=same?1:enter?smooth(p):1-smooth(p),kind=enter?c.markerMotion.enter:c.markerMotion.exit,m=c.markerMotion,scale=1,offset=0;
 if(kind===1)scale=enter?mix(m.startScale,1,smooth(p)):mix(1,m.endScale,smooth(p));if(kind===2)offset=(enter?1-p:p)*m.height;if(kind===3)scale=1+Math.sin(p*Math.PI*(m.pulses||1))*m.pulse*(1-p);
 scale+=Math.sin(p*Math.PI*2)*m.bounce*(1-p);var dx=q.x-size/2,dy=q.y-size/2;
 rows.push({longitude:h.longitude,latitude:h.latitude,x:(dx*ca-dy*sa)*pose.zoom+size/2,y:(dx*sa+dy*ca)*pose.zoom+size/2-offset,life:life,scale:Math.max(.05,scale),kind:kind,progress:p,enter:enter,shared:same,index:h.index,country:entry.country,name:entry.name})}
 return rows}
