.pragma library
.import "RouteGeometry.js" as Geo
var id="circuit-orbit";
var rad=Math.PI/180;
function clamp(v,a,b){return Math.max(a,Math.min(b,v))}
function delta(a,b){return ((b-a+540)%360+360)%360-180}
function smoother(t){t=clamp(t,0,1);return t*t*t*(t*(t*6-15)+10)}
function configuration(zoom,release){return {position:{yaw:-24,pitch:15,roll:0,zoom:zoom},earth:{speed:.75,tilt:23.44,wobble:0},movement:{duration:360,sweep:3,bank:.4,zoom:.01},release:Object.assign({delay:2,blend:16,maxRate:4},release||{})}}
// Route geography is invariant while the camera orbits. The controller prepares
// it on route changes, instead of rebuilding vectors and all pairs every frame.
function prepareRoute(route){
 var hops=(route||[]).filter(function(h){return Geo.vector(h)!==null}),span=0;
 for(var i=0;i<hops.length;i++)for(var j=0;j<i;j++)span=Math.max(span,Math.acos(clamp(Geo.dot(Geo.vector(hops[i]),Geo.vector(hops[j])),-1,1))/rad);
 return {hops:hops,center:Geo.camera(hops),span:span};
}
function pose(c,t,route,prepared){
 var geography=prepared||prepareRoute(route),hops=geography.hops,p=c.position,m=c.movement;
 var spin=Math.max(.1,c.earth.speed),w=2*Math.PI/Math.max(180,m.duration);
 var sway=Math.min(Math.abs(m.sweep),spin*.2/w),center=geography.center;
 var yaw=(center?center.longitude:p.yaw)+spin*t+sway*Math.sin(w*t),weighted=0,weight=0,span=geography.span;
 for(var i=0;i<hops.length;i++){
  var h=hops[i],facing=Math.pow(Math.max(0,Math.cos((h.longitude+yaw)*rad)),4)+.05;
  weighted+=h.latitude*facing;weight+=facing;
 }
 return {yaw:yaw,pitch:weight?clamp(weighted/weight,-70,70):p.pitch,
  roll:p.roll+m.bank*Math.sin(w*t*.53),zoom:clamp(p.zoom*(1.15-.4*span/180)+m.zoom*Math.sin(w*t*.61),.5,2.5),
  tilt:c.earth.tilt+c.earth.wobble*Math.sin(w*t)};
}
function rejoin(c,t,route,event,prepared){
 var normal=pose(c,t,route,prepared);if(!event)return normal;
 var at=pose(c,event.time,route,prepared),offset={yaw:delta(at.yaw,event.pose.yaw),pitch:event.pose.pitch-at.pitch,roll:delta(at.roll,event.pose.roll),zoom:event.pose.zoom-at.zoom};
 var distance=Math.max(Math.abs(offset.yaw),Math.abs(offset.pitch),Math.abs(offset.roll));
 // One easing weight returns yaw, pitch, roll and zoom to the moving orbit together.
 var duration=Math.max(c.release.blend,1.875*distance/c.release.maxRate),weight=1-smoother((t-event.time-c.release.delay)/duration);
 return {yaw:normal.yaw+offset.yaw*weight,pitch:clamp(normal.pitch+offset.pitch*weight,-80,80),roll:normal.roll+offset.roll*weight,zoom:clamp(normal.zoom+offset.zoom*weight,.5,2.5),tilt:normal.tilt};
}
function smoothInput(current,target,dt){
 var a=1-Math.exp(-Math.min(dt,.05)/.12);
 return {yaw:current.yaw+delta(current.yaw,target.yaw)*a,pitch:current.pitch+(target.pitch-current.pitch)*a,
  roll:current.roll+delta(current.roll,target.roll)*a,zoom:Math.exp(Math.log(current.zoom)+(Math.log(target.zoom)-Math.log(current.zoom))*a),tilt:current.tilt};
}
function inputError(a,b){return Math.max(Math.abs(delta(a.yaw,b.yaw)),Math.abs(a.pitch-b.pitch),Math.abs(delta(a.roll,b.roll)),Math.abs(a.zoom-b.zoom)*100)}
