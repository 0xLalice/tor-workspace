#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;
    vec2 texel;
};
layout(binding=1) uniform sampler2D source;
void main() {
    vec4 core=texture(source,qt_TexCoord0);
    if(amount<=0.0) { fragColor=core*qt_Opacity; return; }
    // Fixed taps and fixed radius: the slider changes only halo strength.
    vec2 d=texel*2.5;
    vec4 halo=texture(source,qt_TexCoord0+vec2(d.x,0.0))
             +texture(source,qt_TexCoord0-vec2(d.x,0.0))
             +texture(source,qt_TexCoord0+vec2(0.0,d.y))
             +texture(source,qt_TexCoord0-vec2(0.0,d.y));
    halo+=0.5*(texture(source,qt_TexCoord0+d)
              +texture(source,qt_TexCoord0-d)
              +texture(source,qt_TexCoord0+vec2(d.x,-d.y))
              +texture(source,qt_TexCoord0+vec2(-d.x,d.y)));
    halo*=amount*0.14;
    // Premultiplied source-over keeps the core crisp and alpha bounded.
    fragColor=(core+halo*(1.0-core.a))*qt_Opacity;
}
