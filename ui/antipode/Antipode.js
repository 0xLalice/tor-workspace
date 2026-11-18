.pragma library
.import "../circuit/RouteGeometry.js" as Geo
function valid(p) {
    return p && typeof p.latitude === "number" && typeof p.longitude === "number"
        && isFinite(p.latitude) && isFinite(p.longitude)
        && Math.abs(p.latitude) <= 90 && Math.abs(p.longitude) <= 180;
}
function calculate(origin, snapshot) {
    if (!valid(origin)) return null;
    var a=Geo.vector(origin),winner=null,score=Infinity,seen={},countries=[],count=0;
    (snapshot.countries||[]).forEach(function(c) {
        if (!valid(c)||typeof c.country!=="string"||seen[c.country]
                || !Number.isInteger(c.exitCount)||c.exitCount<1) return;
        seen[c.country]=true;countries.push(c);count+=c.exitCount;
        var d=Geo.dot(a,Geo.vector(c));
        if (!winner||d<score-1e-14||(Math.abs(d-score)<=1e-14&&c.country<winner.country)) {
            winner=c;score=d;
        }
    });
    if (!winner) return null;
    return {origin:JSON.parse(JSON.stringify(origin)),winner:winner,countries:countries,
        distanceKm:Math.round(6371.0088*Math.acos(Math.max(-1,Math.min(1,score)))),countryCount:countries.length,exitCount:count,publishedAt:snapshot.publishedAt,
        fetchedAt:snapshot.fetchedAt,stale:!!snapshot.stale,error:snapshot.error||""};
}
