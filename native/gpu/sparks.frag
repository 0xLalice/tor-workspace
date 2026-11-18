#version 440
layout(location=0) in vec2 local;
layout(location=1) in float power;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
 mat4 matrix; float opacity; vec4 pose; vec4 viewport; vec4 style; vec4 tint; vec4 timing;
};
void main(){
 float r=length(local),aa=max(fwidth(r),.03);
 float core=1.-smoothstep(.20-aa,.20+aa,r);
 float glow=exp(-r*r*9.)*style.z*.3;
 float cross=exp(-abs(local.x)*65.)*exp(-abs(local.y)*5.)+exp(-abs(local.y)*65.)*exp(-abs(local.x)*5.);
 float a=clamp((core+glow+cross*style.w*.12)*power,0.,.8)*opacity;
 fragColor=vec4(tint.rgb*a,a);
}
