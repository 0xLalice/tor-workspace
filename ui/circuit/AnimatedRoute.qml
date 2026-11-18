import ".."
import QtQuick
import "RouteGeometry.js" as Geometry
import "../theme/EffectSettings.js" as Effects

Canvas {
    id: root
    property var route: []
    property bool interacting: false
    onInteractingChanged: if(visible) requestPaint()
    property real longitude: 0
    property real latitude: 0
    property int appearance: 4
    property real time: 0
    property real globeSize: width
    property real trajectoryHeight: 0.22
    property real trajectoryProfile: 1
    property int effectCount: appearance===9 ? 14 : appearance===10 ? 4 : appearance===11 ? 16 : appearance===6 ? 48 : appearance===12 ? 2 : 3
    property real segmentLength: appearance===8 ? 0.25 : 0.015
    property real particleSpread: 0
    property real rippleRadius: 0.2
    property bool tunnelRails: true
    property bool tunnelRings: true
    property bool tunnelCore: true
    property bool tunnelStream: false
    property int tunnelRailCount: 4
    property real tunnelRadius: 1
    property int tunnelStreamCount: 12
    property real tunnelStreamSpeed: 1
    property real tunnelStreamLength: 0.018
    onTunnelRailsChanged: if(visible) requestPaint()
    onTunnelRingsChanged: if(visible) requestPaint()
    onTunnelCoreChanged: if(visible) requestPaint()
    onTunnelStreamChanged: if(visible) requestPaint()
    onTunnelRailCountChanged: if(visible) requestPaint()
    onTunnelRadiusChanged: if(visible) requestPaint()
    onTunnelStreamCountChanged: if(visible) requestPaint()
    onTunnelStreamSpeedChanged: if(visible) requestPaint()
    onTunnelStreamLengthChanged: if(visible) requestPaint()
    onTrajectoryHeightChanged: if(visible) requestPaint()
    onTrajectoryProfileChanged: if(visible) requestPaint()
    onEffectCountChanged: if(visible) requestPaint()
    onSegmentLengthChanged: if(visible) requestPaint()
    onParticleSpreadChanged: if(visible) requestPaint()
    onRippleRadiusChanged: if(visible) requestPaint()
    property bool drawLinks: true
    property bool drawRipples: false
    property real strength: 1
    property real strokeScale: 1
    property real glowAmount: 0
    property var colorMix: []
    property string colorDistribution: "interleaved"
    onColorMixChanged: if(visible) requestPaint()
    onColorDistributionChanged: if(visible) requestPaint()
    function buildMix(count) {
        var result=[]
        if(visible&&colorMix.length)for(var i=0;i<count;i++)result.push(Effects.mixedColor(colorMix,i,count,colorDistribution,customColor))
        return result
    }
    readonly property var elementColors: buildMix(effectCount)
    readonly property var railColors: buildMix(tunnelRailCount)
    readonly property var streamColors: buildMix(tunnelStreamCount)
    function itemColor(index,count,fallback) {
        if(!colorMix.length)return fallback
        var list=count===effectCount?elementColors:count===tunnelRailCount?railColors:streamColors
        return list[((index%count)+count)%count]||fallback
    }
    property color customColor: "transparent"
    opacity: strength
    // Fixed-cost GPU halo over the finished layer. Never blur each Canvas stroke.
    layer.enabled: true
    layer.smooth: true
    layer.effect: ShaderEffect {
        property var source
        property real amount: root.glowAmount
        property vector2d texel: Qt.vector2d(1 / Math.max(1, root.width), 1 / Math.max(1, root.height))
        fragmentShader: Qt.resolvedUrl("../../assets/shaders/route-glow.frag.qsb")
    }
    onStrokeScaleChanged: if(visible) requestPaint()
    onCustomColorChanged: if(visible) requestPaint()
    onAccentChanged: if(visible) requestPaint()
    onInkChanged: if(visible) requestPaint()
    onDrawLinksChanged: if(visible) requestPaint()
    onDrawRipplesChanged: if(visible) requestPaint()
    property color accent: ThemeColors.color("accent")
    property color ink: ThemeColors.color("foreground")
    readonly property var legs: visible ? Geometry.legs(route) : []
    readonly property real cycle: Math.max(1, route.length - 1) * 1.25 + 1.0
    onTimeChanged: if (visible) requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onLongitudeChanged: if(visible) requestPaint()
    onLatitudeChanged: if(visible) requestPaint()
    onRouteChanged: if(visible) requestPaint()
    onAppearanceChanged: if(visible) requestPaint()
    onWidthChanged: if(visible) requestPaint()
    onHeightChanged: if(visible) requestPaint()

    function position(leg, t) {
        return Geometry.project(Geometry.arc(leg, t, lift(leg),trajectoryProfile), longitude, latitude, globeSize)
    }
    function lift(leg) {
        return trajectoryHeight
    }
    function segment(ctx,leg,start,end,color,thickness,alpha,lane) {
        ctx.strokeStyle=color; ctx.lineWidth=thickness*strokeScale; ctx.globalAlpha=alpha
        ctx.lineCap="butt"; ctx.lineJoin="round"; ctx.beginPath()
        var drawing=false
        var steps=Math.max(2,Math.ceil((end-start)*(interacting ? 32 : 96)))
        for(var j=0;j<=steps;j++) {
            var t=start+(end-start)*j/steps, p=position(leg,t)
            if(lane) {
                var ahead=position(leg,Math.min(1,t+0.002)), behind=position(leg,Math.max(0,t-0.002))
                var dx=ahead.x-behind.x,dy=ahead.y-behind.y,length=Math.sqrt(dx*dx+dy*dy)||1
                p.x-=dy/length*lane; p.y+=dx/length*lane
            }
            if(!p.visible){drawing=false;continue}
            if(drawing)ctx.lineTo(p.x,p.y);else ctx.moveTo(p.x,p.y)
            drawing=true
        }
        ctx.stroke()
    }
    function tubePoint(leg,t,angle) {
        var center=Geometry.arc(leg,t,lift(leg),trajectoryProfile)
        var normal=Geometry.normalize([
            leg.a[1]*leg.tangent[2]-leg.a[2]*leg.tangent[1],
            leg.a[2]*leg.tangent[0]-leg.a[0]*leg.tangent[2],
            leg.a[0]*leg.tangent[1]-leg.a[1]*leg.tangent[0]])
        var radial=Geometry.normalize(center)
        var r=0.027*tunnelRadius*Math.pow(Math.sin(Math.PI*t),0.35)
        return Geometry.project([0,1,2].map(function(n){return center[n]+r*(normal[n]*Math.cos(angle)+radial[n]*Math.sin(angle))}),longitude,latitude,globeSize)
    }
    function dot(ctx, p, radius, color, opacity) {
        if (!p.visible) return
        ctx.globalAlpha = Math.max(0, Math.min(1, opacity))
        ctx.fillStyle = color
        ctx.beginPath(); ctx.arc(p.x, p.y, radius*strokeScale, 0, Math.PI*2); ctx.fill()
    }
    property int paintCount:0
    onPaint: {
        if(!visible)return
        paintCount++
        var ctx = getContext("2d")
        ctx.reset()
        ctx.translate((width-globeSize)/2, (height-globeSize)/2)
        var colors = [ThemeColors.color("foreground"), ThemeColors.color("bright_blue"), ThemeColors.color("cyan"), ThemeColors.color("bright_cyan"), ThemeColors.color("bright_blue")]
        var color = Qt.tint(colors[Math.max(0, appearance-4)] || ThemeColors.color("bright_blue"), "transparent")
        if(customColor.a>0) color=customColor
        var clock = time % cycle
        // Project each particle in 3D, including globe occlusion. No invented hops.
        for (var k=0; k<(drawLinks ? legs.length : 0); k++) {
            var leg=legs[k]
            var head=(clock-leg.index*1.25)/1.25
            if (appearance === 9) {
                // A steady train of rectangular packet marks on every link.
                segment(ctx,leg,0,1,accent,0.8,0.24,0)
                for(var packet=0;packet<effectCount;packet++) {
                    var t=(packet/effectCount+time*0.16+leg.index*0.09)%1
                    segment(ctx,leg,t,Math.min(1,t+segmentLength),colorMix.length ? itemColor(packet,effectCount,color) : packet%4===0 ? ink : color,2.2,0.9,0)
                }
            } else if (appearance === 10) {
                // A persistent ribbon with travelling bands, not isolated projectiles.
                segment(ctx,leg,0,1,accent,5,0.16,0)
                segment(ctx,leg,0,1,color,0.7,0.38,-2.1)
                segment(ctx,leg,0,1,color,0.7,0.38,2.1)
                for(var stripe=0;stripe<64;stripe++) {
                    var t=stripe/64
                    var flow=Math.pow(0.5+0.5*Math.sin((t-time*0.16)*Math.PI*2*effectCount+leg.index),5)
                    segment(ctx,leg,t,Math.min(1,t+1/64),itemColor(Math.floor((t-time*0.16)*effectCount),effectCount,color),2.3,0.12+flow*0.72,0)
                }
            } else if (appearance === 11) {
                // A real projected tube: longitudinal rails and advancing cross sections.
                for(var rail=0;rail<(tunnelRails ? tunnelRailCount : 0);rail++) {
                    ctx.strokeStyle=itemColor(rail,tunnelRailCount,color);ctx.lineWidth=0.65*strokeScale;ctx.globalAlpha=0.22;ctx.beginPath()
                    var drawing=false
                    var railSteps=interacting ? 28 : 80
                    for(var j=0;j<=railSteps;j++) {
                        var p=tubePoint(leg,j/railSteps,rail*Math.PI*2/tunnelRailCount)
                        if(!p.visible){drawing=false;continue}
                        if(drawing)ctx.lineTo(p.x,p.y);else ctx.moveTo(p.x,p.y)
                        drawing=true
                    }
                    ctx.stroke()
                }
                for(var ring=0;ring<(tunnelRings ? effectCount : 0);ring++) {
                    var t=(ring/effectCount+time*0.12)%1
                    ctx.strokeStyle=itemColor(ring,effectCount,color);ctx.lineWidth=0.8*strokeScale
                    ctx.globalAlpha=Math.sin(Math.PI*t)*0.65;ctx.beginPath()
                    var drawing=false
                    var ringSteps=interacting ? 12 : 24
                    for(var j=0;j<=ringSteps;j++) {
                        var p=tubePoint(leg,t,j/ringSteps*Math.PI*2)
                        if(!p.visible){drawing=false;continue}
                        if(drawing)ctx.lineTo(p.x,p.y);else ctx.moveTo(p.x,p.y)
                        drawing=true
                    }
                    ctx.stroke()
                }
                if(tunnelCore) segment(ctx,leg,0,1,accent,0.7,0.35,0)
                if(tunnelStream) for(var packet=0;packet<tunnelStreamCount;packet++) {
                    var t=(time*0.16*tunnelStreamSpeed+packet/tunnelStreamCount)%1
                    segment(ctx,leg,t,Math.min(1,t+tunnelStreamLength),itemColor(packet,tunnelStreamCount,color),1.3,0.9,0)
                }
            } else if (appearance === 8) {
                for(var arcIndex=0;arcIndex<effectCount;arcIndex++) {
                    var phase=(time*0.16+arcIndex/effectCount+leg.index*0.13)%1
                    segment(ctx,leg,phase,Math.min(1,phase+segmentLength),itemColor(arcIndex,effectCount,color),1.6,0.85,0)
                }
            } else if (appearance === 6) {
                for (var j=0; j<effectCount; j++) {
                    var t=(time*0.16+j/effectCount)%1
                    var p=position(leg,t)
                    var shimmer=0.5+0.5*Math.sin(j*7.13)
                    var spread=Math.sin(Math.PI*t)*particleSpread
                    p.x+=Math.sin(j*12.7+time)*spread
                    p.y+=Math.cos(j*4.7+time)*spread
                    dot(ctx,p,3.2,itemColor(j,effectCount,color),0.035+shimmer*0.035)
                    dot(ctx,p,0.85+shimmer*0.45,itemColor(j,effectCount,color),0.3+shimmer*0.65)
                }
            } else {
                // Broad travelling stroke segments, with no spherical leading head.
                var count=appearance===4 ? 5 : appearance===5 ? 2 : 3
                var span=appearance===4 ? 0.035 : appearance===5 ? 0.26 : 0.12
                for(var pulse=0;pulse<count;pulse++) {
                    var phase=(time*0.2+pulse/count+leg.index*0.13)%1
                    segment(ctx,leg,phase,Math.min(1,phase+span),color,appearance===5 ? 1.5 : 1.1,0.8,0)
                }
            }
        }
        // Wavefronts are circles on the sphere, so they foreshorten correctly.
        for (var i=0;i<route.length;i++) {
            var v=Geometry.vector(route[i]); if (!v) continue
            if(!drawRipples) continue
            var age=(clock-i*1.25+cycle)%cycle
            if (appearance>=8 && appearance<12) age=((time/4+(i-1)*0.31-1+2.5)%1.25)*4
            if (appearance===6 || appearance===12) age=(time+i*0.4)%1.9

            var ref=Math.abs(v[1])<0.9 ? [0,1,0] : [1,0,0]
            var d=Geometry.dot(v,ref)
            var u=Geometry.normalize([ref[0]-d*v[0],ref[1]-d*v[1],ref[2]-d*v[2]])
            var w=[v[1]*u[2]-v[2]*u[1],v[2]*u[0]-v[0]*u[2],v[0]*u[1]-v[1]*u[0]]
            for (var ring=0;ring<effectCount;ring++) {
                var a=(time*0.6+ring/effectCount+i*0.13)%1
                var radius=0.015+a*rippleRadius
                ctx.strokeStyle=itemColor(ring,effectCount,color); ctx.lineWidth=ring===0 ? 1.1 : 0.6
                ctx.globalAlpha=Math.sin(Math.PI*a)*0.7
                ctx.beginPath(); var drawing=false
                var rippleSteps=interacting ? 24 : 64
                for(var s=0;s<=rippleSteps;s++) {
                    var angle=s/rippleSteps*Math.PI*2
                    var point=[0,1,2].map(function(n){return v[n]*Math.cos(radius)+(u[n]*Math.cos(angle)+w[n]*Math.sin(angle))*Math.sin(radius)})
                    var q=Geometry.project(point,longitude,latitude,globeSize)
                    if(q.z<=0){drawing=false;continue}
                    if(drawing)ctx.lineTo(q.x,q.y);else ctx.moveTo(q.x,q.y)
                    drawing=true
                }
                ctx.stroke()
            }
        }
    }
}
