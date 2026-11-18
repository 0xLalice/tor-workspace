#version 440
layout(location=0) in vec3 position;
layout(location=1) in vec2 corner;
layout(location=2) in float phase;
layout(location=0) out vec2 local;
layout(location=1) out float power;
layout(std140,binding=0) uniform buf {
 mat4 matrix; float opacity; vec4 pose; vec4 viewport; vec4 style; vec4 tint; vec4 timing;
};
float ease(float v){v=clamp(v,0.,1.);return v*v*(3.-2.*v);}
void main(){
 float cy=cos(pose.x),sy=sin(pose.x),cp=cos(pose.y),sp=sin(pose.y);
 float x=cy*position.x+sy*position.z,z0=-sy*position.x+cy*position.z;
 float y=cp*position.y-sp*z0,z=sp*position.y+cp*z0;
 float c=cos(pose.z),s=sin(pose.z);
 vec2 center=viewport.xy*.5+viewport.z*vec2(x*c+y*s,x*s-y*c);
 local=corner;
 float pulse=pow(max(0.,sin(timing.x*timing.y*(.8+phase*.4)+phase*6.2831853)),5.);
 power=style.x*mix(timing.z,1.,pulse)*ease(z/.15)*ease(timing.x/.8)*(1.-ease((timing.x-21.)/3.))*ease((timing.x-phase*3.)/1.1);
 if(timing.x<=0.||timing.x>=24.)power=0.;
 if(z<=0.)power=0.;
 gl_Position=matrix*vec4(center+corner*style.y*4.,0.,1.);
}
