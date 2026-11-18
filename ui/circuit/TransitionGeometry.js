.pragma library
.import "RouteGeometry.js" as Geometry
var steps=64;
function build(route,height,profile,radius) {
 return Geometry.legs(route).map(function(leg){
  var normal=Geometry.normalize([leg.a[1]*leg.tangent[2]-leg.a[2]*leg.tangent[1],leg.a[2]*leg.tangent[0]-leg.a[0]*leg.tangent[2],leg.a[0]*leg.tangent[1]-leg.a[1]*leg.tangent[0]]);
  var points=[],radials=[],radii=[];
  for(var i=0;i<=steps;i++){
   var t=i/steps,v=Geometry.arc(leg,t,height,profile);
   points.push(v);radials.push(Geometry.normalize(v));radii.push(0.027*radius*Math.pow(Math.max(0,Math.sin(Math.PI*t)),0.35));
  }
  return {points:points,radials:radials,radii:radii,normal:normal};
 });
}
function prepare(mesh,angles){
 return mesh.map(function(leg){
  var lanes={};
  angles.forEach(function(angle){
   var ca=Math.cos(angle),sa=Math.sin(angle);
   lanes[angle]=leg.points.map(function(v,i){
    var r=leg.radii[i],n=leg.normal,u=leg.radials[i];
    return [v[0]+r*(n[0]*ca+u[0]*sa),v[1]+r*(n[1]*ca+u[1]*sa),v[2]+r*(n[2]*ca+u[2]*sa)];
   });
  });
  return {center:leg.points,lanes:lanes};
 });
}
function references(world,side){
 return world.map(function(leg,index){
  function ref(lane){return {nativeSide:side,nativeLeg:index,lane:lane};}
  var lanes={};Object.keys(leg.lanes).forEach(function(key){lanes[key]=ref(key)});
  return {nativeSide:side,nativeLeg:index,center:ref(""),lanes:lanes};
 });
}
function rippleBases(route){
 return route.map(function(hop,index){
  var v=Geometry.vector(hop);if(!v)return null;
  var ref=Math.abs(v[1])<0.9?[0,1,0]:[1,0,0],d=Geometry.dot(v,ref);
  var u=Geometry.normalize([ref[0]-d*v[0],ref[1]-d*v[1],ref[2]-d*v[2]]);
  var w=[v[1]*u[2]-v[2]*u[1],v[2]*u[0]-v[0]*u[2],v[0]*u[1]-v[1]*u[0]];
  return {v:v,u:u,w:w,index:index,hop:Geometry.legs(route.slice(0,index+1)).length};
 }).filter(function(b){return b!==null});
}
function worldAt(mesh,progress){
 if(!mesh.length)return null;
 var head=Math.max(0,Math.min(mesh.length,progress)),leg=Math.min(mesh.length-1,Math.floor(head));
 var v=(head-leg)*steps,i=Math.min(steps-1,Math.floor(v)),f=v-i,a=mesh[leg].points[i],b=mesh[leg].points[i+1];
 return [a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f];
}
function releaseFlight(mesh,flight,hop){
 var head=Math.min(mesh.length,flight.head),tail=Math.min(mesh.length,flight.tail),p=worldAt(mesh,head);
 if(!p)return null;
 var lo=Math.max(0,head-0.001),hi=Math.min(mesh.length,head+0.001),a=worldAt(mesh,lo),b=worldAt(mesh,hi);
 var scale=isFinite(hop)&&hi>lo?1/((hi-lo)*hop):0;
 var velocity=[(b[0]-a[0])*scale,(b[1]-a[1])*scale,(b[2]-a[2])*scale],radial=Geometry.normalize(p);
 var drift=0.018+0.012*(0.5+0.5*Math.sin(flight.id*2.13));
 var acceleration=radial.map(function(x){return x*drift});
 var points=[],n=Math.max(1,Math.ceil((head-tail)*steps));
 for(var i=0;i<=n;i++)points.push(worldAt(mesh,tail+(head-tail)*i/n));
 return {id:flight.id,head:p,velocity:velocity,acceleration:acceleration,points:points};
}
function screenOffset(dx,dy,longitude,latitude,size){
 var yaw=longitude*Math.PI/180,pitch=latitude*Math.PI/180;
 var x=dx/(size*0.42),y=-dy/(size*0.42),z0=-Math.sin(pitch)*y;
 return [Math.cos(yaw)*x-Math.sin(yaw)*z0,Math.cos(pitch)*y,Math.sin(yaw)*x+Math.cos(yaw)*z0];
}
