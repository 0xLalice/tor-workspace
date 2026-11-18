#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float longitude;
    float latitude;
    vec4 accent;
    vec4 secondary;
    vec4 surface;
    vec4 atmosphere;
    vec4 lamps;
    vec4 treatment;
    vec4 waterTint;
    vec4 skyTint;
    vec4 cloudTint;
    vec4 waterOptions;
    vec4 waterSurface;
    vec4 skyOptions;
    vec4 skyMotion;
    vec2 borderOptions;
    float lighting;
    float appearance;
    float time;
    vec4 relay0;
    vec4 relay1;
    vec4 relay2;
    vec4 relay3;
    vec4 mappedCountries;
    vec4 mapOptions;
    vec4 mapTint;
    vec4 mapFillTint;
    vec2 mapMotion;
    vec4 departingCountries;
    vec4 surfaceOptions;
    vec4 retiringTint;
    float surfaceGlow;
    vec4 clayMaterial;
    vec4 clayShading;
    float roseAtmosphere;
    vec4 roseTint;
};
layout(binding = 1) uniform sampler2D countryMap;
layout(binding = 2) uniform sampler2D countryIds;
layout(binding = 3) uniform sampler2D groundLightMap;
const float PI = 3.14159265359;
float gridLine(float coordinate) {
    float d = abs(fract(coordinate + 0.5) - 0.5);
    float w = max(fwidth(coordinate), 0.0001);
    return 1.0 - smoothstep(w * 0.15, w * 0.8, d);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Fade out terrain frequencies smaller than the screen pixel footprint.
float filteredNoise(vec2 uv,vec2 dx,vec2 dy,float frequency) {
    float footprint=max(length(dx),length(dy))*frequency;
    float detail=1.0-smoothstep(0.15,0.7,footprint);
    return mix(0.5,noise(uv*frequency),detail);
}
// Great-circle distance makes these wavefronts live on the spherical surface.
// Their edges foreshorten with the map and disappear behind the globe.
float surfaceRipple(vec3 world, vec4 relay, float offset) {
    float angle=acos(clamp(dot(world,relay.xyz),-1.0,1.0));
    float aa=max(fwidth(angle),0.0015);
    float result=0.0;
    for (int i=0;i<3;i++) {
        float phase=fract(time*0.35+float(i)/3.0+offset);
        float radius=0.022+phase*0.19;
        float distanceToRing=abs(angle-radius);
        float line=1.0-smoothstep(0.0015,0.0015+aa*1.2,distanceToRing);
        float glow=exp(-distanceToRing*100.0)*0.18;
        // Fade in AND out: no discontinuity when a new wave starts.
        float envelope=pow(sin(phase*PI),2.0);
        result+=(line+glow)*envelope;
    }
    return result*relay.w;
}
float countryId(vec2 uv) { return floor(texture(countryIds,vec2(fract(uv.x),clamp(uv.y,0.0,1.0))).r*255.0+0.5); }
float countryMatch(float id,vec4 ids){if(id<.5)return 0.0;vec4 match=1.0-step(vec4(.5),abs(ids-vec4(id)));return max(max(match.x,match.y),max(match.z,match.w));}
float selectedCountry(float id){float arrival=countryMatch(id,mappedCountries);if(surfaceOptions.x<.5)return arrival;float departure=countryMatch(id,departingCountries);if(arrival*departure>.5)return 1.0;return max(arrival*smoothstep(0.0,1.0,surfaceOptions.y),departure*(1.0-smoothstep(0.0,1.0,surfaceOptions.z)));}
float hash3(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float cloudNoise(vec3 p) {
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(2.0, -2.0);
    float d = length(p), radius = 0.84;
    float aa = max(fwidth(d), 0.001);
    float mask = 1.0 - smoothstep(radius-aa, radius+aa, d);
    vec2 plane = p / radius;
    vec3 n = vec3(plane, sqrt(max(0.0, 1.0-dot(plane,plane))));
    float yaw = longitude*PI/180.0, pitch = latitude*PI/180.0;
    vec3 u = vec3(n.x, cos(pitch)*n.y+sin(pitch)*n.z, -sin(pitch)*n.y+cos(pitch)*n.z);
    vec3 world = vec3(cos(yaw)*u.x-sin(yaw)*u.z, u.y, sin(yaw)*u.x+cos(yaw)*u.z);
    float phi = asin(clamp(world.y,-1.0,1.0)), lambda = atan(world.x,world.z);
    vec2 uv = vec2(lambda/(2.0*PI)+0.5,0.5-phi/PI);
    vec2 dx=dFdx(uv), dy=dFdy(uv);
    dx.x-=floor(dx.x+0.5); dy.x-=floor(dy.x+0.5);
    vec2 geo=textureGrad(countryMap,uv,dx,dy).rg;
    // Expand the antialiased border mask in screen space; fixed sample count.
    float countryBorder=geo.g;
    if(borderOptions.x>1.0) {
        float extent=(borderOptions.x-1.0)*0.5;
        for(int tap=0;tap<8;tap++) {
            float angle=float(tap)*PI/4.0;
            vec2 offset=(dx*cos(angle)+dy*sin(angle))*extent;
            countryBorder=max(countryBorder,textureGrad(countryMap,uv+offset,dx,dy).g);
        }
    } else countryBorder=pow(max(countryBorder,0.0),1.0/max(0.25,borderOptions.x));
    countryBorder*=borderOptions.y;
    float az=skyMotion.z*PI/180.0,el=skyMotion.w*PI/180.0;
    vec3 sunDirection=vec3(cos(el)*sin(az),sin(el),cos(el)*cos(az));
    float light=max(0.0,dot(n,sunDirection));
    float facing=pow(max(n.z,0.0),0.5);
    float sun=0.36+0.64*light;
    float rim=pow(1.0-clamp(n.z,0.0,1.0),5.0);
    float grid=max(gridLine(phi/(PI/6.0)),gridLine(lambda/(PI/6.0))*smoothstep(0.08,0.3,cos(phi)));
    float detail=treatment.x;
    float lamp=textureGrad(groundLightMap,uv,dx,dy).r;
    vec3 color=surface.rgb;float alpha=mask;
    float halo=exp(-max(d-radius,0.0)*65.0)*0.16*treatment.y;
    // Warm Paper Clay: broad terrain, fine engraving and a satin paper surface.
    float relief=filteredNoise(uv,dx,dy,95.0)*.7+filteredNoise(uv,dx,dy,210.0)*.3;
    float terrain=relief;
    if(clayMaterial.x>0.0)terrain=cloudNoise(world*4.8)*.75+cloudNoise(world*11.0+7.0)*.25;
    float emboss=clamp((dFdx(terrain)-dFdy(terrain))*10.0,-.05,.05)*clayMaterial.x;
    color=mix(surface.rgb,accent.rgb*(.94+.06*terrain+emboss),geo.r)*(clayShading.x+clayShading.y*light);
    float contours=gridLine(terrain*9.0)*geo.r;
    color=mix(color,secondary.rgb,contours*.12*clayMaterial.y);
    float fibre=(filteredNoise(uv,dx,dy,360.0)-.5)*.028*clayMaterial.z;
    color*=1.0+fibre;
    float glaze=pow(max(0.0,dot(n,normalize(vec3(-.4,.55,1.0)))),26.0);
    color=mix(color,skyTint.rgb,glaze*clayMaterial.w);
    float fineBorder=countryBorder*detail*.12*.55*clayShading.z;
    color=mix(color,secondary.rgb,clamp(fineBorder,0.0,1.0));
    // Reflective ocean: analytic wave slopes perturb the spherical surface normal.
    // No wave pattern is painted into the ocean's color.
    if(waterOptions.x>0.5) {
        float phase=time*waterOptions.w;
        float seaState=waterOptions.x<1.5?0.30:waterOptions.x<2.5?0.75:1.35;
        vec3 slope=vec3(0.0);
        for(int wave=0;wave<6;wave++) {
            float i=float(wave);
            vec3 direction=normalize(vec3(sin(i*2.399+0.7),cos(i*1.713+0.3),sin(i*1.117+1.5)));
            float frequency=waterOptions.z*(1.0+i*0.63);
            float angle=dot(world,direction)*frequency-phase*(0.7+i*0.27);
            float filtering=1.0-smoothstep(0.3,1.5,fwidth(angle));
            vec3 tangent=direction-world*dot(world,direction);
            slope+=tangent*cos(angle)*filtering/(1.0+i*0.7);
        }
        vec3 wn=normalize(world-slope*waterSurface.y*seaState);
        // World-to-camera transform, shared with geographic projection.
        vec3 yawNormal=vec3(cos(yaw)*wn.x+sin(yaw)*wn.z,wn.y,-sin(yaw)*wn.x+cos(yaw)*wn.z);
        vec3 waterNormal=normalize(vec3(yawNormal.x,cos(pitch)*yawNormal.y-sin(pitch)*yawNormal.z,sin(pitch)*yawNormal.y+cos(pitch)*yawNormal.z));
        vec3 view=vec3(0,0,1),halfway=normalize(sunDirection+view);
        float nv=max(0.001,dot(waterNormal,view)),nl=max(0.0,dot(waterNormal,sunDirection));
        float nh=max(0.0,dot(waterNormal,halfway)),vh=max(0.0,dot(view,halfway));
        float rough=clamp(waterSurface.x*(0.75+seaState*0.35),0.08,0.65);
        float a2=pow(rough,4.0);
        float denom=nh*nh*(a2-1.0)+1.0;
        float distribution=a2/(PI*denom*denom);
        float k=pow(rough+1.0,2.0)/8.0;
        float geometry=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
        float fresnel=0.02+0.98*pow(1.0-nv,5.0);
        float sunFresnel=0.02+0.98*pow(1.0-vh,5.0);
        float specular=distribution*geometry*sunFresnel/(4.0*nv+0.001);
        // A soft sky and broad light source reflected by the moving water normals.
        vec3 reflection=reflect(-view,waterNormal);
        float sky=0.25+0.75*smoothstep(-0.25,0.85,reflection.y);
        float softbox=exp(-pow((reflection.x+0.45)/0.42,2.0)-pow((reflection.y-0.55)/0.24,2.0));
        vec3 environment=mix(atmosphere.rgb*0.25,skyTint.rgb,sky)+skyTint.rgb*softbox*2.0;
        vec3 transmission=surface.rgb*(0.65+0.35*nl)+waterTint.rgb*0.035*(0.3+0.7*nl);
        vec3 ocean=transmission*(1.0-fresnel)+environment*(fresnel+0.035)*waterSurface.z;
        ocean+=skyTint.rgb*(specular/(1.0+specular))*waterSurface.z*2.0;
        color=mix(color,ocean,clamp(waterOptions.y,0.0,1.0)*(1.0-geo.r));
    }
    // Seamless world-space cloud field: low-frequency wisps instead of flickering grain.
    if(skyOptions.w>0.0) {
        float drift=time*skyMotion.y*0.025;
        vec3 cloudWorld=vec3(cos(drift)*world.x-sin(drift)*world.z,world.y,sin(drift)*world.x+cos(drift)*world.z);
        float cloud=cloudNoise(cloudWorld*4.0)*0.7+cloudNoise(cloudWorld*8.0+7.0)*0.3;
        float coverage=smoothstep(0.75-skyMotion.x*0.5,0.90-skyMotion.x*0.5,cloud);
        color=mix(color,cloudTint.rgb*(0.35+0.65*light),coverage*skyOptions.w*facing);
    }
    vec3 haloColor=atmosphere.rgb*0.6;
    if(skyOptions.z>0.5) {
        float thickness=max(0.012,skyOptions.x);
        float altitude=max(0.0,d-radius);
        float outer=exp(-altitude/thickness)*0.25*treatment.y*(0.35+0.65*light);
        outer*=1.0-smoothstep(0.965,0.995,d);
        halo=max(halo,outer);
        haloColor=mix(atmosphere.rgb,skyTint.rgb,smoothstep(0.0,thickness*1.5,altitude));
        color+=mix(skyTint.rgb,atmosphere.rgb,pow(1.0-n.z,0.5))*pow(1.0-n.z,3.0)*0.22*treatment.y*(0.3+0.7*light);
    }
    color+=skyTint.rgb*skyOptions.y*pow(1.0-clamp(n.z,0.0,1.0),1.5)*(0.2+0.8*light)*treatment.y;
    if(roseAtmosphere>0.0){
        float drift=.5+.5*sin(atan(p.y,p.x)*2.0+time*.055);
        vec3 blush=mix(roseTint.rgb,lamps.rgb,drift);
        float limb=pow(1.0-clamp(n.z,0.0,1.0),2.7);
        color=mix(color,blush,limb*.14*roseAtmosphere*(.75+.25*light));
        float altitude=max(0.0,d-radius);
        float veil=exp(-altitude/.045)*.19*roseAtmosphere;
        veil*=1.0-smoothstep(.965,.995,d);
        halo=max(halo,veil);haloColor=blush;
    }
    alpha=mask+halo*(1.0-mask);
    color=mix(haloColor,color,mask);
    vec3 result=color*lighting*alpha;
    if(mapOptions.x+mapOptions.y>0.0) {
        float id=countryId(uv), chosen=selectedCountry(id);
        vec2 delta=vec2(1.0/2048.0,1.0/1024.0)*mapOptions.z;
        float nearby=chosen, edge=0.0;
        for(int j=0;j<4;j++) {
            vec2 offset=j==0?vec2(delta.x,0):j==1?vec2(-delta.x,0):j==2?vec2(0,delta.y):vec2(0,-delta.y);
            float other=countryId(uv+offset);
            float relevant=max(chosen,selectedCountry(other));
            nearby=max(nearby,relevant);
            edge=max(edge,step(0.5,abs(id-other))*relevant);
        }
        float pulse=mix(1.0,0.68+0.32*sin(time*mapMotion.y*2.0),mapMotion.x);
        float border=max(edge*0.65,geo.g*nearby)*mapOptions.x;
        float amount=(border*0.85+chosen*mapOptions.y*0.20)*mapOptions.w*pulse*mask*(0.35+0.65*facing);
        float weight=mapOptions.w*pulse*mask*(0.35+0.65*facing);
        vec3 lineTint=mapTint.rgb,fillTint=mapFillTint.rgb;
        if(surfaceOptions.x>.5){float isNew=countryMatch(id,mappedCountries),isOld=countryMatch(id,departingCountries);float warmth=isNew*(1.0-isOld)*(1.0-surfaceOptions.y)*surfaceOptions.w;lineTint=mix(retiringTint.rgb,lineTint,isNew);fillTint=mix(retiringTint.rgb,fillTint,isNew);lineTint=mix(lineTint,retiringTint.rgb,warmth);fillTint=mix(fillTint,retiringTint.rgb,warmth);}
        {
            // On daylight materials, construction reads as a soft ink wash.
            result=mix(result,lineTint*alpha,clamp(border*weight*.42,0.0,.25));
            result=mix(result,fillTint*alpha,clamp(chosen*mapOptions.y*weight*.20,0.0,.12));
        }
        alpha=max(alpha,clamp(amount,0.0,1.0));
    }
    fragColor=vec4(result,alpha)*qt_Opacity;
}
