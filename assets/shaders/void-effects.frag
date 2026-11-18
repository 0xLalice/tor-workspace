#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
 mat4 qt_Matrix;
 float qt_Opacity;
 vec2 resolution;
 float time;
 float driftTime;
 vec4 themeTravel;
 vec4 starColor;
 vec4 lightColor;
 vec4 enabledLayers;
 vec4 stars;
 vec4 motion;
};
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec3 field(vec2 p,float cellSize,float scale){
 vec2 cell=floor(p/cellSize),local=mod(p,cellSize);
 // A margin around each cell keeps the full halo inside it.
 vec2 center=vec2(0.25+0.5*hash(cell),0.25+0.5*hash(cell+37.0))*cellSize;
 float seed=hash(cell+71.0);
 float present=step(seed,stars.x);
 float d=length(local-center);
 float radius=stars.y*scale*(0.45+0.55*hash(cell+19.0));
 float core=1.0-smoothstep(max(0.0,radius-0.65),radius+0.65,d);
 float halo=exp(-d*d/max(1.0,radius*radius*7.0))*stars.w*0.22;
 float shimmer=1.0-motion.z*0.3*(0.5+0.5*sin(time*0.7+seed*6.283));
 return starColor.rgb*(core+halo)*present*(0.35+0.65*seed)*stars.z*shimmer;
}
void main(){
 vec2 uv=qt_TexCoord0,p=uv*resolution;
 vec2 drift=vec2(driftTime*2.0,driftTime*0.55);
 vec3 c=vec3(0.0);
 if(enabledLayers.x>0.5)c+=field(p+drift+themeTravel.xy,32.0,1.0);
 if(enabledLayers.y>0.5)c+=field(p*1.6-drift*0.4+271.0+themeTravel.xy*.35,25.0,0.55)*0.35;
 vec2 q=(uv-0.5)*vec2(resolution.x/resolution.y,1.0)+themeTravel.zw;
 if(enabledLayers.z>0.5){
  float band=q.y+0.24*sin(q.x*3.0+driftTime*0.025);
  float haze=exp(-band*band*28.0)*exp(-q.x*q.x*1.3);
  float fold=0.65+0.35*sin(q.x*7.0+q.y*3.0+driftTime*0.03);
  c+=lightColor.rgb*haze*fold*motion.y*0.13;
 }
 if(enabledLayers.w>0.5){
  float beam=exp(-pow(q.x+q.y*0.7+0.28,2.0)*90.0);
  beam+=0.45*exp(-pow(q.x+q.y*0.7-0.19,2.0)*180.0);
  c+=lightColor.rgb*beam*(0.6-0.4*uv.y)*motion.y*0.15;
 }
 // Rounded mask matches the panel; no light leaks into surrounding UI.
 vec2 edge=abs(p-resolution*0.5)-(resolution*0.5-18.0);
 float sdf=length(max(edge,0.0))+min(max(edge.x,edge.y),0.0)-18.0;
 float mask=1.0-smoothstep(-1.0,0.0,sdf);
 float a=clamp(max(c.r,max(c.g,c.b)),0.0,1.0)*mask;
 fragColor=vec4(min(c,vec3(1.0))*mask,a)*qt_Opacity;
}
