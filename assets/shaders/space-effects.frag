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
 vec4 occluder;
 vec4 materialDetail;
 vec4 secondTint;
 vec4 celestial;
};

// Palette colors are composited with coverage, including on light surfaces.
// Three independent fields supply distant pinpoints, soft stars and rare glints.
float hash(vec2 p){
 vec3 q=fract(vec3(p.xyx)*0.1031);
 q+=dot(q,q.yzx+33.33);
 return fract((q.x+q.y)*q.z);
}
float noise(vec2 p){
 vec2 cell=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
vec4 over(vec4 a,vec4 b){return a+b*(1.0-a.a);}
vec4 field(vec2 p,float cellSize,float scale,float density,float depth){
 vec2 cell=floor(p/cellSize);
 float seed=hash(cell+depth*47.0+motion.w*113.0);
 if(seed>density)return vec4(0.0);
 vec2 center=vec2(0.2+0.6*hash(cell+19.0),0.2+0.6*hash(cell+37.0))*cellSize;
 vec2 d=mod(p,cellSize)-center;
 float phase=hash(cell+103.0);
 float radius=stars.y*scale*(0.5+0.8*hash(cell+71.0));
 if(materialDetail.z>0.5&&depth>0.4)radius*=mix(.8,2.0,smoothstep(.75,.98,phase));
 float dist=length(d);
 float core=1.0-smoothstep(max(0.0,radius-0.45),radius+0.65,dist);
 float halo=exp(-dot(d,d)/max(1.0,radius*radius*11.0))*stars.w*0.28;
 float twinkle=1.0-motion.z*(0.12+0.16*depth)*(0.5+0.5*sin(time*(0.35+phase*0.55)+phase*6.283));
 if(celestial.z>0.0&&motion.z>0.0)twinkle=.68+.32*(.5+.5*sin(time*(.4+phase*.35)+phase*6.283));
 float glint=0.0;
 if(depth>0.8&&phase>0.66){
  float span=radius*(motion.w>1.5?2.8:4.8);
  glint=(exp(-abs(d.x)*4.0-abs(d.y)/span)+exp(-abs(d.y)*4.0-abs(d.x)/span))*0.38*twinkle;
  if(celestial.z>0.0){
   float shimmer=pow(.5+.5*sin(time*.55+phase*6.283),4.0);
   glint*=1.0+1.6*shimmer;
  }
 }
 float a=clamp((core+halo+glint)*stars.z*(0.45+0.55*phase)*twinkle,0.0,0.85);
 vec3 tint=mix(starColor.rgb,lightColor.rgb,depth*0.28);
 if(materialDetail.z>0.5)tint=mix(tint,secondTint.rgb,smoothstep(.65,.95,phase)*.28);
 if(celestial.z>0.0)tint=mix(tint,mix(lightColor.rgb,secondTint.rgb,phase),depth*.45);
 return vec4(tint*a,a);
}
void main(){
 vec2 uv=qt_TexCoord0,p=uv*resolution;
 if(occluder.z>0.0&&length(p-occluder.xy)<occluder.z-0.75){fragColor=vec4(0.0);return;}
 vec2 q=(uv-0.5)*vec2(resolution.x/resolution.y,1.0)+themeTravel.zw;
 float slow=driftTime;
 float haze=0.0;
 vec3 hazeTint=lightColor.rgb;
 if(enabledLayers.z>0.5){
  vec2 cloud=q*vec2(3.0,4.5)+vec2(slow*0.025,-slow*0.018);
  float n=noise(cloud)+0.5*noise(cloud*2.1+13.0);
  if(motion.w<0.5){
   // Classic's wide folded nebula, with coverage for light desktop surfaces.
   float band=q.y+0.24*sin(q.x*3.0+slow*.025);
   float fold=.65+.35*sin(q.x*7.0+q.y*3.0+slow*.03);
   haze=exp(-band*band*28.0)*exp(-q.x*q.x*1.3)*fold*.24;
   hazeTint=mix(lightColor.rgb,secondTint.rgb,smoothstep(-.28,.28,q.x));
  }else if(motion.w<1.5){
   float belt=q.y+q.x*.8+.06*sin(q.x*9.0+slow*.04);
   haze=exp(-belt*belt*65.0)*(.15+.33*noise(q*14.0+slow*.03));
   hazeTint=mix(lightColor.rgb,secondTint.rgb,noise(q*7.0));
  }else{
   float curl=q.x+0.24*sin(q.y*5.0+slow*0.018);
   float veil=exp(-pow(curl+0.24,2.0)*9.0)+0.50*exp(-pow(curl-0.35,2.0)*18.0);
   haze=veil*smoothstep(0.2,1.25,n)*0.23;
  }
 }
 if(enabledLayers.w>0.5)haze+=exp(-pow(q.x+q.y*0.7+0.28,2.0)*70.0)*0.15;
 if(motion.w>1.5){
  float a=.28*exp(-dot(q-vec2(-.26,-.36),q-vec2(-.26,-.36))*13.0);
  float b=.25*exp(-dot(q-vec2(.25,.38),q-vec2(.25,.38))*13.0);
  haze=a+b;hazeTint=(lightColor.rgb*a+secondTint.rgb*b)/max(haze,.0001);
 }
 if(celestial.x>0.0&&enabledLayers.z>0.5){
  // Rose/ochre volumes: a slow folded veil and a separate warm pool of dust light.
  float fold=q.x+q.y*.48+.08*sin(q.y*5.0+slow*.035);
  float a=.46*exp(-pow(fold+.18,2.0)*10.0)*(.65+.35*noise(q*4.0+slow*.012));
  float b=.40*exp(-dot(q-vec2(.25,.30),q-vec2(.25,.30))*7.0);
  haze=mix(haze,a+b,clamp(celestial.x,0.0,1.0));
  hazeTint=(lightColor.rgb*a+secondTint.rgb*b)/max(a+b,.0001);
 }
 if(enabledLayers.z+enabledLayers.w<.5)haze=0.0;
 haze=clamp(haze*motion.y*materialDetail.y,0.0,motion.w<1.5?.28:.62);
 vec4 c=vec4(hazeTint*haze,haze);
 if(materialDetail.w>0.0){
  // Screen-stable paper fibres, with no animated noise or stippling on the globe.
  float grain=(hash(floor(p))-.5)*materialDetail.w;
  float fibre=sin(p.x*.7+noise(p*.04)*2.0)*sin(p.y*.13)*materialDetail.w*.20;
  float a=abs(grain+fibre);
  c=over(vec4(mix(vec3(1.0),starColor.rgb,step(0.0,grain+fibre))*a,a),c);
 }

 vec2 drift=vec2(slow*1.5,slow*0.45);
 if(enabledLayers.y>0.5)c=over(field(p-drift*0.3+271.0+themeTravel.xy*.35,27.0,0.45,stars.x*0.85,0.15),c);
 if(enabledLayers.x>0.5){
  c=over(field(p+drift+themeTravel.xy,51.0,0.95,stars.x,0.55),c);
  c=over(field(p+drift*1.4+117.0+themeTravel.xy*1.35,97.0,1.65,stars.x*0.65,1.0),c);
 }
 vec2 edge=abs(p-resolution*0.5)-(resolution*0.5-18.0);
 float sdf=length(max(edge,0.0))+min(max(edge.x,edge.y),0.0)-18.0;
 float mask=1.0-smoothstep(-1.0,0.0,sdf);
 // A translucent cartographic globe still blocks distant stars and nebulae.
 if(occluder.z>0.0)mask*=smoothstep(occluder.z-0.75,occluder.z+0.75,length(p-occluder.xy));
 fragColor=c*mask*qt_Opacity;
}
