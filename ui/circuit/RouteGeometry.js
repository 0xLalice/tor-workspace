.pragma library

function vector(hop) {
    if (!hop || typeof hop.longitude !== "number" || typeof hop.latitude !== "number"
            || !isFinite(hop.longitude) || !isFinite(hop.latitude)) return null;
    var lon = hop.longitude * Math.PI / 180;
    var lat = hop.latitude * Math.PI / 180;
    return [Math.cos(lat) * Math.sin(lon), Math.sin(lat), Math.cos(lat) * Math.cos(lon)];
}
function dot(a, b) { return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]; }
function normalize(v) {
    var n = Math.sqrt(dot(v, v));
    return n < 0.000001 ? null : [v[0]/n, v[1]/n, v[2]/n];
}
function camera(route) {
    var points = [], center = null, widest = 1;
    for (var i = 0; i < route.length; ++i) {
        var v = vector(route[i]);
        if (!v) continue;
        center = center || v;
        for (var k = 0; k < points.length; ++k) {
            var distance = dot(v,points[k]);
            if (distance < widest) {
                widest = distance;
                center = normalize([v[0]+points[k][0],v[1]+points[k][1],v[2]+points[k][2]]) || center;
            }
        }
        points.push(v);
    }
    return center ? {longitude: -Math.atan2(center[0], center[2]) * 180 / Math.PI,
                     latitude: Math.max(-65, Math.min(65, Math.asin(center[1]) * 180 / Math.PI))} : null;
}
function legs(route) {
    var result = [];
    for (var i = 0; i + 1 < route.length; ++i) {
        var a = vector(route[i]), b = vector(route[i+1]);
        // Missing locations break the path; never join across an unknown hop.
        // Same-country hops share a marker, rather than inventing locations.
        if (!a || !b || dot(a, b) > 0.999999) continue;
        var cosine = Math.max(-1, Math.min(1, dot(a, b)));
        var tangent = normalize([b[0]-cosine*a[0], b[1]-cosine*a[1], b[2]-cosine*a[2]]);
        if (!tangent) {
            var ref = Math.abs(a[1]) < 0.9 ? [0,1,0] : [1,0,0];
            var d = dot(a, ref);
            tangent = normalize([ref[0]-d*a[0],ref[1]-d*a[1],ref[2]-d*a[2]]);
        }
        result.push({index: i, a: a, b: b, tangent: tangent, angle: Math.acos(cosine)});
    }
    return result;
}
function arc(leg, t, lift, profile) {
    var angle = leg.angle * t;
    var height = 1 + (lift === undefined ? Math.min(0.18, 0.05 + leg.angle * 0.07) : lift) * Math.pow(Math.max(0,Math.sin(Math.PI*t)),profile === undefined ? 1 : profile);
    return [0,1,2].map(function(k) {
        return height * (Math.cos(angle)*leg.a[k] + Math.sin(angle)*leg.tangent[k]);
    });
}
function project(v, longitude, latitude, size) {
    var yaw = longitude * Math.PI / 180, pitch = latitude * Math.PI / 180;
    var x = Math.cos(yaw)*v[0] + Math.sin(yaw)*v[2];
    var z0 = -Math.sin(yaw)*v[0] + Math.cos(yaw)*v[2];
    var y = Math.cos(pitch)*v[1] - Math.sin(pitch)*z0;
    var z = Math.sin(pitch)*v[1] + Math.cos(pitch)*z0;
    return {x: size/2 + size*0.42*x, y: size/2 - size*0.42*y, z: z,
            visible: z >= 0 || x*x + y*y >= 1.001};
}
function path(leg, longitude, latitude, size) {
    var output = "", previous = null, previousT = 0, drawing = false;
    function command(letter, p) { return letter + p.x.toFixed(2) + "," + p.y.toFixed(2) + " "; }
    for (var i = 0; i <= 96; ++i) {
        var t = i / 96, p = project(arc(leg,t),longitude,latitude,size);
        if (previous && p.visible !== previous.visible) {
            var low = previousT, high = t;
            for (var b = 0; b < 10; ++b) {
                var mid = (low+high)/2;
                if (project(arc(leg,mid),longitude,latitude,size).visible === previous.visible) low = mid;
                else high = mid;
            }
            var edge = project(arc(leg,(low+high)/2),longitude,latitude,size);
            output += command(drawing ? "L" : "M", edge);
            drawing = p.visible;
        }
        if (p.visible) { output += command(drawing ? "L" : "M",p); drawing = true; }
        else drawing = false;
        previous = p; previousT = t;
    }
    return output;
}
function markers(route, longitude, latitude, size) {
    var groups = [];
    for (var i = 0; i < route.length; ++i) {
        var v = vector(route[i]);
        if (!v) continue;
        var existing = -1;
        for (var k = 0; k < groups.length; ++k) {
            if (dot(groups[k].v,v) > 0.999999) existing = k;
        }
        if (existing >= 0) { groups[existing].numbers.push(i+1); continue; }
        groups.push({v:v, numbers:[i+1], country:route[i].countryName || route[i].country});
    }
    var visible = [];
    groups.forEach(function(group) {
        var p = project(group.v,longitude,latitude,size);
        if (p.z < 0.025) return;
        group.anchorX = p.x; group.anchorY = p.y;
        group.text = group.numbers.join("·");
        group.width = Math.max(20, group.text.length*6+12);
        group.x = p.x; group.y = p.y;
        group.color = group.numbers.indexOf(1) >= 0 ? "#7ddbc6"
            : group.numbers.indexOf(route.length) >= 0 ? "#f1c48a" : "#c0a5ed";
        visible.push(group);
    });
    // Separate labels in dense regions (e.g. Europe); leader lines stay tied
    // to the real country anchor. No fake relay coordinates are introduced.
    for (var pass = 0; pass < 10; ++pass) {
        for (var a = 0; a < visible.length; ++a) {
            for (var b = a+1; b < visible.length; ++b) {
                var p = visible[a], q = visible[b];
                if (Math.abs(p.x-q.x) < (p.width+q.width)/2+4 && Math.abs(p.y-q.y) < 25) {
                    var sign = p.y <= q.y ? -1 : 1;
                    var amount = (25-Math.abs(p.y-q.y))/2;
                    p.y += sign*amount; q.y -= sign*amount;
                }
            }
        }
    }
    return visible;
}

// Country-level locations may be shared by several circuit hops. Keep one
// callout per anchor and list all roles instead of inventing separate places.
function callouts(route, longitude, latitude, size, reserveInternet) {
    var groups = markers(route, longitude, latitude, size);
    var w = Math.min(110, size * 0.36), h = 36, margin = 3;
    var placed = [];
    groups.sort(function(a,b) { return a.anchorY-b.anchorY; });
    groups.forEach(function(group) {
        var hops = group.numbers.map(function(n) { return route[n-1]; });
        var roles = group.numbers.map(function(n) {
            return n === 1 ? "YOU" : String(route[n-1].role || "Relay").toUpperCase();
        });
        var best = null, bestCost = Infinity;
        for (var side=0;side<2;++side) {
            var x = side === 0 ? margin : size-w-margin;
            for (var y=margin;y<=size-h-margin;y+=5) {
                var overlaps = placed.some(function(p) {
                    return x < p.x+w+5 && x+w+5 > p.x && y < p.y+h+6 && y+h+6 > p.y;
                });
                if (overlaps || (reserveInternet && side === 1 && y+h > size*0.68)) continue;
                var edgeX = side === 0 ? x+w : x;
                var cost = Math.pow(edgeX-group.anchorX,2)+Math.pow(y+h/2-group.anchorY,2);
                groups.forEach(function(g) {
                    if (g.anchorX>x-10 && g.anchorX<x+w+10 && g.anchorY>y-10 && g.anchorY<y+h+10) cost+=100000;
                });
                if (cost<bestCost) { bestCost=cost; best={x:x,y:y,edgeX:edgeX,edgeY:y+h/2}; }
            }
        }
        if (!best) return;
        best.width=w; best.height=h; best.anchorX=group.anchorX; best.anchorY=group.anchorY;
        best.country=group.country || "Unknown"; best.code=hops[0].country || "";
        best.roles=roles.join(" / ");
        placed.push(best);
    });
    return placed;
}

// Trackball rotation in camera space. The camera, globe and polar axis share
// the same yaw/pitch/roll; spinning longitude still rotates about Earth's poles.
function dragOrientation(longitude,latitude,roll,fromX,fromY,toX,toY) {
    function ball(x,y) {
        var d=x*x+y*y;
        return normalize([x,-y,Math.sqrt(Math.max(0,1-d))]);
    }
    var a=ball(fromX,fromY),b=ball(toX,toY),c=dot(a,b);
    if(c < -0.999999) return {longitude:longitude,latitude:latitude,roll:roll};
    var v=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
    var k=[[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]];
    function mul(a,b) {
        var out=[[0,0,0],[0,0,0],[0,0,0]];
        for(var i=0;i<3;i++)for(var j=0;j<3;j++)for(var n=0;n<3;n++)out[i][j]+=a[i][n]*b[n][j];
        return out;
    }
    var kk=mul(k,k),delta=[[0,0,0],[0,0,0],[0,0,0]];
    for(var i=0;i<3;i++)for(var j=0;j<3;j++)delta[i][j]=(i===j?1:0)+k[i][j]+kk[i][j]/(1+c);
    var y=longitude*Math.PI/180,p=latitude*Math.PI/180,r=roll*Math.PI/180;
    var cy=Math.cos(y),sy=Math.sin(y),cp=Math.cos(p),sp=Math.sin(p),cr=Math.cos(r),sr=Math.sin(r);
    var current=[[cr*cy+sr*sp*sy,sr*cp,cr*sy-sr*sp*cy],[-sr*cy+cr*sp*sy,cr*cp,-sr*sy-cr*sp*cy],[-cp*sy,sp,cp*cy]];
    var m=mul(delta,current);
    var pitch=Math.asin(Math.max(-1,Math.min(1,m[2][1])));
    var yaw,angle;
    if(Math.abs(Math.cos(pitch))>0.000001) {
        yaw=Math.atan2(-m[2][0],m[2][2]);angle=Math.atan2(m[0][1],m[1][1]);
    } else { yaw=Math.atan2(m[0][2],m[0][0]);angle=0; }
    return {longitude:yaw*180/Math.PI,latitude:pitch*180/Math.PI,roll:angle*180/Math.PI};
}
