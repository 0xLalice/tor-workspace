#include <QMap>
#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QVariant>
#include <QtQml/QQmlExtensionPlugin>
#include <QtQml/qqml.h>
#include <QtQuick/QQuickPaintedItem>
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

namespace {
constexpr int Steps = 64;
constexpr double Pi = 3.14159265358979323846;
struct Vec {
    double x = 0, y = 0, z = 0;
};
struct Point {
    double x = 0, y = 0, z = 0;
    bool visible = false;
};
struct Leg {
    std::vector<Vec> center;
    QMap<QString, std::vector<Vec>> lanes;
};
struct Projected {
    std::vector<Point> center;
    QMap<QString, std::vector<Point>> lanes;
};
struct Draw {
    QPainterPath path;
    QColor color;
    double width = 1, alpha = 1;
    bool fill = false;
    QBrush material;
    Qt::PenCapStyle cap = Qt::FlatCap;
};
struct Flight {
    double id = 0;
    Vec head, velocity, acceleration;
    std::vector<Vec> points;
    QColor tint;
};
struct Group {
    QString type, key;
    double intensity = 1, width = 1;
    std::vector<Flight> items;
};
double number(const QVariantMap &m, const char *key, double fallback = 0) {
    auto i = m.constFind(QLatin1String(key));
    return i == m.end() ? fallback : i->toDouble();
}
Vec vector(const QVariant &value) {
    auto a = value.toList();
    return a.size() >= 3 ? Vec{a[0].toDouble(), a[1].toDouble(), a[2].toDouble()} : Vec{};
}
std::vector<Vec> vectors(const QVariant &value) {
    std::vector<Vec> out;
    auto list = value.toList();
    out.reserve(list.size());
    for (const auto &v : list)
        out.push_back(vector(v));
    return out;
}
QColor color(const QVariant &value) {
    return value.canConvert<QColor>() ? value.value<QColor>()
                                      : QColor::fromString(value.toString());
}
double clamp(double x) { return std::max(0., std::min(1., x)); }
double smooth(double x) {
    x = clamp(x);
    return x * x * (3 - 2 * x);
}
double noise(double id) {
    double n = std::sin(id * 127.1 + 311.7) * 43758.5453;
    return n - std::floor(n);
}
Point interpolate(const std::vector<Point> &a, int i, double f) {
    if (i < 0 || i + 1 >= int(a.size()))
        return {};
    const auto &p = a[i];
    const auto &q = a[i + 1];
    return {p.x + (q.x - p.x) * f, p.y + (q.y - p.y) * f, 0, p.visible && q.visible};
}
Point at(const std::vector<Point> &a, double t) {
    double v = std::max(0., std::min(double(Steps), t * Steps));
    int i = std::min(Steps - 1, int(std::floor(v)));
    return interpolate(a, i, v - i);
}
Vec releasedAt(Vec p, const Flight &f, double age, double drift) {
    return {p.x + f.velocity.x * age + f.acceleration.x * drift,
            p.y + f.velocity.y * age + f.acceleration.y * drift,
            p.z + f.velocity.z * age + f.acceleration.z * drift};
}
} // namespace

// Retain QImage/QPainter rasterization and the reference command order. Geometry
// and path construction run natively; Qt paints the current frame during scene
// graph synchronization, without a separate queue of older Canvas textures.
class CircuitPainter : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QColor strokeStyle MEMBER strokeStyle)
    Q_PROPERTY(QColor fillStyle MEMBER fillStyle)
    Q_PROPERTY(double lineWidth READ currentLineWidth WRITE setLineWidth)
    Q_PROPERTY(double globalAlpha READ currentAlpha WRITE setAlpha)
    Q_PROPERTY(double contrastGain MEMBER contrastGain)
    Q_PROPERTY(double strokeScale MEMBER strokeScale)
    Q_PROPERTY(QColor strokeUnderlay MEMBER strokeUnderlay)
    std::array<std::vector<Leg>, 2> world;
    std::array<std::vector<Projected>, 2> projected;
    std::vector<Group> releasedGroups;
    std::vector<Draw> commands;
    QTransform transform;
    double cy = 1, sy = 0, cp = 1, sp = 0, size = 400;
    double lastYaw = NAN, lastPitch = NAN, lastSize = NAN;
    std::array<bool, 2> invalid{{true, true}};
    std::array<QString, 12> ringKeys;
    QColor strokeStyle = Qt::black, fillStyle = Qt::black;
    double lineWidth = 1, globalAlpha = 1;
    double contrastGain = 1, strokeScale = 1;
    QColor strokeUnderlay = Qt::transparent;
    Point project(Vec v) const {
        double x = cy * v.x + sy * v.z, z0 = -sy * v.x + cy * v.z, y = cp * v.y - sp * z0,
               z = sp * v.y + cp * z0;
        return {size / 2 + size * .42 * x, size / 2 - size * .42 * y, z,
                z >= 0 || x * x + y * y >= 1.001};
    }
    void projectPoints(const std::vector<Vec> &from, std::vector<Point> &to) {
        to.resize(from.size());
        for (size_t i = 0; i < from.size(); ++i)
            to[i] = project(from[i]);
    }
    void append(QPainterPath path, bool fill = false) {
        if (!path.isEmpty())
            commands.push_back(
                {std::move(path), fill ? fillStyle : strokeStyle, lineWidth, globalAlpha, fill});
    }
    static void vertex(QPainterPath &path, const Point &p, bool &drawing) {
        if (!p.visible) {
            drawing = false;
            return;
        }
        if (drawing)
            path.lineTo(p.x, p.y);
        else
            path.moveTo(p.x, p.y);
        drawing = true;
    }
    static QPainterPath circle(double x, double y, double r) {
        QPainterPath p;
        QRectF box(x - r, y - r, r * 2, r * 2);
        p.arcMoveTo(box, 0);
        p.arcTo(box, 0, 360);
        p.setFillRule(Qt::WindingFill);
        return p;
    }

  public:
    CircuitPainter() {
        setRenderTarget(QQuickPaintedItem::Image);
        setFillColor(Qt::transparent);
        commands.reserve(800);
    }
    double currentLineWidth() const { return lineWidth; }
    double currentAlpha() const { return globalAlpha; }
    // Match Canvas: invalid alpha/width assignments preserve the previous state.
    void setLineWidth(double value) {
        if (std::isfinite(value) && value > 0)
            lineWidth = value;
    }
    void setAlpha(double value) {
        if (std::isfinite(value) && value >= 0 && value <= 1)
            globalAlpha = value;
    }

    Q_INVOKABLE void setGeometry(int side, const QVariantList &list) {
        if (side < 0 || side > 1)
            return;
        auto &out = world[side];
        out.clear();
        out.reserve(list.size());
        for (const auto &value : list) {
            auto m = value.toMap();
            Leg leg;
            leg.center = vectors(m.value("center"));
            auto lanes = m.value("lanes").toMap();
            for (auto i = lanes.begin(); i != lanes.end(); ++i)
                leg.lanes.insert(i.key(), vectors(i.value()));
            for (int n = 0; n < 12; n++) {
                double angle = n * Pi * 2 / 12;
                for (auto key = leg.lanes.cbegin(); key != leg.lanes.cend(); ++key)
                    if (key.key().toDouble() == angle) {
                        ringKeys[n] = key.key();
                        break;
                    }
            }
            out.push_back(std::move(leg));
        }
        projected[side].clear();
        invalid[side] = true;
    }
    Q_INVOKABLE void beginFrame(double yaw, double pitch, double globeSize, bool old, bool next) {
        bool changed = yaw != lastYaw || pitch != lastPitch || globeSize != lastSize;
        size = globeSize;
        double a = yaw * Pi / 180, b = pitch * Pi / 180;
        cy = std::cos(a);
        sy = std::sin(a);
        cp = std::cos(b);
        sp = std::sin(b);
        if (changed)
            invalid = {{true, true}};
        for (int side = 0; side < 2; side++)
            if ((side ? next : old) && invalid[side]) {
                projected[side].resize(world[side].size());
                for (size_t k = 0; k < world[side].size(); k++) {
                    auto &src = world[side][k];
                    auto &dst = projected[side][k];
                    projectPoints(src.center, dst.center);
                    for (auto i = src.lanes.begin(); i != src.lanes.end(); ++i)
                        projectPoints(i.value(), dst.lanes[i.key()]);
                }
                invalid[side] = false;
            }
        lastYaw = yaw;
        lastPitch = pitch;
        lastSize = size;
    }
    Q_INVOKABLE void reset() {
        commands.clear();
        transform.reset();
        strokeStyle = fillStyle = Qt::black;
        lineWidth = globalAlpha = 1;
    }
    Q_INVOKABLE void scale(double x, double y) { transform.scale(x, y); }
    Q_INVOKABLE void translate(double x, double y) { transform.translate(x, y); }
    Q_INVOKABLE void beginPath() {}
    Q_INVOKABLE void finishFrame() { update(); }
    Q_INVOKABLE void strokeGeometry(int side, int leg, const QString &lane, double start,
                                    double end) {
        if (side < 0 || side > 1 || leg < 0 || leg >= int(projected[side].size()))
            return;
        const auto &g = projected[side][leg];
        const std::vector<Point> *storage = &g.center;
        if (!lane.isEmpty()) {
            auto it = g.lanes.constFind(lane);
            if (it == g.lanes.cend())
                return;
            storage = &it.value();
        }
        const auto &points = *storage;
        if (points.size() != Steps + 1)
            return;
        QPainterPath path;
        bool drawing = false;
        vertex(path, at(points, start), drawing);
        int first = int(std::floor(start * Steps)) + 1, last = int(std::ceil(end * Steps));
        for (int i = first; i < last && i < int(points.size()); i++)
            vertex(path, points[i], drawing);
        vertex(path, at(points, end), drawing);
        append(std::move(path));
    }
    Q_INVOKABLE void ring(int side, int leg, double t, const QVariantMap &visual, int ringStyle,
                          int exitStyle, double scatter, double strength, int id) {
        if (side < 0 || side > 1 || leg < 0 || leg >= int(projected[side].size()))
            return;
        const auto &g = projected[side][leg];
        double v = std::max(0., std::min(double(Steps), t * Steps));
        int index = std::min(Steps - 1, int(std::floor(v)));
        double f = v - index;
        Point center = interpolate(g.center, index, f);
        std::array<Point, 12> lanes;
        // QML numeric-key strings are supplied by the caller once with geometry.
        for (int i = 0; i < 12; i++) {
            auto it = g.lanes.constFind(ringKeys[i]);
            if (it == g.lanes.cend())
                return;
            lanes[i] = interpolate(it.value(), index, f);
        }
        bool exit = visual.value("exit").toBool(), erosion = exit && exitStyle == 4,
             fixed = !exit && number(visual, "rotation") == 0;
        int segments = erosion ? 53 : 48, previousShard = -1;
        double progress = number(visual, "progress");
        bool drawing = false;
        QPainterPath path;
        for (int r = 0; r <= segments; r++) {
            double fraction = double(r) / segments, angle = 0, radius = number(visual, "radius", 1);
            int shard = 0;
            bool present = true;
            if (erosion) {
                shard = r / 9;
                double n = noise(id * 13 + shard + 1), offset = scatter * .35 * n,
                       eaten = std::pow(::smooth((progress - offset) / (1 - offset)),
                                        1 / std::max(.2, strength));
                double anchor = .2 + .6 * noise(id * 19 + shard + 3), start = eaten * anchor,
                       end = 1 - eaten * (1 - anchor), local = double(r % 9) / 8;
                present = eaten < 1;
                angle = (shard + start + local * (end - start)) * Pi / 3;
                radius = 1;
            } else if (exit) {
                shard = std::min(5, int(std::floor(fraction * 6)));
                double local = fraction * 6 - shard, n = noise(id * 13 + shard + 1),
                       direction = noise(id + 5) > .5 ? 1 : -1,
                       amount = progress * progress * strength;
                angle = fraction * Pi * 2;
                if (exitStyle == 1) {
                    present = local <= 1 - progress * (.3 + n * .5);
                    angle += direction * amount * (.25 + n * .8);
                    radius = 1 + amount * (.5 + n * 1.8);
                } else if (exitStyle == 2) {
                    present = local <= 1 - progress * progress * .75;
                    angle += direction * amount * .25;
                    radius = 1 + amount * 2.8;
                } else {
                    present = fraction <= 1 - progress;
                    angle += direction * amount * Pi * 2;
                    radius = std::max(.15, 1 - .65 * progress) + amount * fraction * .6;
                    shard = 0;
                }
            } else {
                present = ringStyle == 2
                              ? std::fmod(fraction * 6, 1) <= number(visual, "coverage", 1)
                          : ringStyle == 4 ? fraction <= number(visual, "coverage", 1)
                                           : true;
                angle = fraction * Pi * 2 + number(visual, "rotation");
            }
            if (!present) {
                drawing = false;
                continue;
            }
            if (exit && progress > 0 && shard != previousShard)
                drawing = false;
            if (exit)
                previousShard = shard;
            if (fixed)
                angle = double(r) / 48 * Pi * 2;
            angle = std::fmod(std::fmod(angle, Pi * 2) + Pi * 2, Pi * 2);
            double lane = angle / (Pi * 2) * 12;
            int lo = int(std::floor(lane)) % 12;
            double blend = lane - std::floor(lane);
            const auto &a = lanes[lo];
            const auto &b = lanes[(lo + 1) % 12];
            if (!a.visible || !b.visible) {
                drawing = false;
                continue;
            }
            vertex(path,
                   {center.x + (a.x + (b.x - a.x) * blend - center.x) * radius,
                    center.y + (a.y + (b.y - a.y) * blend - center.y) * radius, 0, true},
                   drawing);
        }
        append(std::move(path));
    }
    Q_INVOKABLE void dots(int side, const QVariantList &items, const QVariantMap &p, double clock,
                          double alpha, const QVariantList &colors) {
        if (side < 0 || side > 1 || colors.isEmpty())
            return;
        std::vector<QColor> palette;
        for (const auto &v : colors)
            palette.push_back(color(v));
        double width = number(p, "width", 1);
        for (const auto &item : items) {
            auto flight = item.toMap();
            double head = number(flight, "head"), id = number(flight, "id");
            int k = int(std::floor(head));
            if (k < 0 || k >= int(projected[side].size()))
                continue;
            double t = head - k;
            auto q = at(projected[side][k].center, t);
            if (!q.visible)
                continue;
            double spread = std::sin(Pi * t) * number(p, "spread");
            q.x += std::sin(id * 12.7 + clock) * spread;
            q.y += std::cos(id * 4.7 + clock) * spread;
            int count = int(palette.size());
            fillStyle = palette[((qint64(id) % count) + count) % count];
            setAlpha(number(p, "intensity", 1) * .8 * alpha);
            append(circle(q.x, q.y, (.9 + .4 * (.5 + .5 * std::sin(id * 7.13))) * width), true);
        }
    }
    Q_INVOKABLE void ripple(const QVariantMap &basis, double radius, int stride) {
        Vec v = vector(basis.value("v")), u = vector(basis.value("u")),
            w = vector(basis.value("w"));
        double cr = std::cos(radius), sr = std::sin(radius);
        bool drawing = false;
        QPainterPath path;
        for (int i = 0; i <= 64; i += std::max(1, stride)) {
            double c = std::cos(i * Pi * 2 / 64), s = std::sin(i * Pi * 2 / 64);
            auto q =
                project({v.x * cr + (u.x * c + w.x * s) * sr, v.y * cr + (u.y * c + w.y * s) * sr,
                         v.z * cr + (u.z * c + w.z * s) * sr});
            q.visible = q.z > 0;
            vertex(path, q, drawing);
        }
        append(std::move(path));
    }
    Q_INVOKABLE void setReleasedGroups(const QVariantList &groups) {
        releasedGroups.clear();
        for (const auto &value : groups) {
            auto m = value.toMap(), s = m.value("stream").toMap(), p = s.value("params").toMap();
            Group g;
            g.type = s.value("type").toString();
            g.key = s.value("key").toString();
            g.width = number(p, "width", 1);
            g.intensity = number(p, "intensity", 1);
            for (const auto &value : m.value("items").toList()) {
                auto f = value.toMap();
                g.items.push_back({number(f, "id"), vector(f.value("head")),
                                   vector(f.value("velocity")), vector(f.value("acceleration")),
                                   vectors(f.value("points")), color(f.value("tint"))});
            }
            releasedGroups.push_back(std::move(g));
        }
    }
    Q_INVOKABLE void released(double age, double alpha) {
        double drift = 2 * (age - 2 * (1 - std::exp(-age / 2))),
               stretchRate = .25 * (1 - std::exp(-age / 3));
        for (const auto &g : releasedGroups)
            for (const auto &f : g.items) {
                setAlpha(g.intensity * .9 * alpha);
                strokeStyle = fillStyle = f.tint;
                if (g.type == "dot") {
                    auto q = project(releasedAt(f.head, f, age, drift));
                    if (q.visible)
                        append(circle(q.x, q.y,
                                      (.9 + .4 * (.5 + .5 * std::sin(f.id * 7.13))) * g.width),
                               true);
                } else {
                    setLineWidth((g.type == "arc" ? 1.6 : g.key == "tunnel" ? 1.3 : 2.2) * g.width);
                    QPainterPath path;
                    bool drawing = false;
                    for (size_t k = 0; k < f.points.size(); k++) {
                        auto point = releasedAt(f.points[k], f, age, drift);
                        double stretch =
                            stretchRate *
                            (1 - double(k) / std::max(1., double(f.points.size()) - 1));
                        point.x -= f.velocity.x * stretch;
                        point.y -= f.velocity.y * stretch;
                        point.z -= f.velocity.z * stretch;
                        vertex(path, project(point), drawing);
                    }
                    append(std::move(path));
                }
            }
    }
    // Resolve the descriptor once on presentation/palette changes, outside frame work.
    QColor designInk, designAccent, designHighlight;
    int designKind = 1;
    Q_INVOKABLE void setDesign(int kind, QColor ink, QColor accent, QColor highlight) {
        designKind = kind; designInk = ink; designAccent = accent; designHighlight = highlight;
    }
    Q_INVOKABLE void clearGeometry() {
        for (auto &side : world) side.clear();
        for (auto &side : projected) side.clear();
        releasedGroups.clear(); commands.clear(); invalid = {{true,true}}; update();
    }
    QPainterPath offsetPath(const std::vector<Point> &points, double start, double end, double offset) {
        QPainterPath path; bool drawing=false;
        int count=std::max(2,int(std::ceil((end-start)*Steps)));
        for(int i=0;i<=count;++i){
            double t=start+(end-start)*i/count; auto p=at(points,t);
            if(offset!=0){
                auto a=at(points,std::max(0.,t-.01)), b=at(points,std::min(1.,t+.01));
                double dx=b.x-a.x,dy=b.y-a.y,n=std::max(.001,std::hypot(dx,dy));
                p.x-=dy/n*offset; p.y+=dx/n*offset;
            }
            vertex(path,p,drawing);
        }
        return path;
    }
    Q_INVOKABLE void drawDesign(int side, double clock, double front, double retirement, bool retiring) {
        if(side<0||side>1)return;
        const auto &legs=projected[side];
        auto blend=[](QColor a,QColor b,double t){t=clamp(t);return QColor::fromRgbF(a.redF()+(b.redF()-a.redF())*t,a.greenF()+(b.greenF()-a.greenF())*t,a.blueF()+(b.blueF()-a.blueF())*t);};
        for(size_t index=0;index<legs.size();++index){
            const auto &g=legs[index]; if(g.center.size()!=Steps+1)continue;
            double end=clamp(front-index),start=retiring?clamp(retirement*legs.size()-index):0;
            if(end<=start)continue;
            double alpha=retiring?1-::smooth(retirement):1;
            double previousStart=-1,previousEnd=-1,previousOffset=0;
            QPainterPath previousPath;
            auto stroke=[&](double a,double b,double offset,QColor tint,double width,double opacity,bool gradient=false){
                a=std::max(start,a);b=std::min(end,b);if(b<=a||opacity<=0)return;
                if(a!=previousStart||b!=previousEnd||offset!=previousOffset){
                    previousPath=offsetPath(g.center,a,b,offset);
                    previousStart=a;previousEnd=b;previousOffset=offset;
                }
                const auto &path=previousPath;if(path.isEmpty())return;
                Draw draw{path,tint,width,clamp(opacity*alpha),false};
                draw.cap=Qt::RoundCap;
                if(gradient){
                    QLinearGradient dye(path.pointAtPercent(0),path.pointAtPercent(1));
                    dye.setColorAt(0,tint);dye.setColorAt(.55,blend(tint,designInk,.30));dye.setColorAt(1,designInk);
                    draw.material=QBrush(dye);
                }
                commands.push_back(std::move(draw));
            };
            // The glow, body and tapered transport share exactly the projected route.
            // A small number of long envelopes replace repeated collars and beads.
            double glowWidth=designKind==3?8:designKind==6?7:5;
            stroke(start,end,0,designAccent,glowWidth,.045,true);
            stroke(start,end,0,designAccent,glowWidth*.55,.085,true);
            if(designKind==1){
                // Meridian: precise, open optical rails with a warm/cool signal between them.
                stroke(start,end,-1.45,designAccent,.65,.56,true);
                stroke(start,end,1.45,designInk,.55,.44);
                stroke(start,end,0,designAccent,.65,.20,true);
            }else if(designKind==2){
                // Obsidian: a copper fibre with a lit bevel, without a ladder silhouette.
                stroke(start,end,0,designAccent,2.0,.22,true);
                stroke(start,end,-.65,designAccent,.7,.78,true);
                stroke(start,end,.70,designInk,.45,.38);
            }else if(designKind==3){
                // Celadon: a broad silk flow, gently illuminated at its centre.
                stroke(start,end,0,designAccent,2.5,.20,true);
                stroke(start,end,0,designAccent,.8,.58,true);
            }else if(designKind==4){
                // Nocturne: a fine amber backbone supporting long comet-like transmissions.
                stroke(start,end,0,designAccent,.65,.36,true);
            }else if(designKind==5){
                // Terra: interwoven copper and gold strands with a quiet engraved centre.
                for(int segment=0;segment<32;++segment){
                    double a=segment/32.,b=(segment+1)/32.;
                    double weave=1.2*std::sin((a+b)*.5*Pi*8-clock*.35);
                    stroke(a,b,weave,designAccent,.75,.67,true);
                    stroke(a,b,-weave,designInk,.55,.45);
                }
                stroke(start,end,0,designAccent,.45,.25);
            }else if(designKind==6){
                // Smoked glass: translucent volume with cool refractive edges.
                stroke(start,end,0,designAccent,3.2,.12,true);
                stroke(start,end,-1.8,designAccent,.55,.50,true);
                stroke(start,end,1.8,designInk,.45,.36);
                stroke(start,end,0,designHighlight,.6,.23);
            }else if(designKind==8){
                // Rose paper: a gilded arc in a diffuse rose envelope, with a lit inner edge.
                stroke(start,end,0,designInk,6.0,.09);
                stroke(start,end,0,designAccent,2.7,.24,true);
                stroke(start,end,-.45,designAccent,.85,.82,true);
                stroke(start,end,.65,designInk,.55,.48);
            }else{
                // Cinder: a restrained rose/amber arc over the shadowed planet.
                stroke(start,end,0,designAccent,1.2,.22,true);
                stroke(start,end,0,designAccent,.55,.60,true);
            }
            int packets=designKind==4?3:2;
            double speed=designKind==8?.09:designKind==1?.105:designKind==3?.055:designKind==4?.075:.065;
            double length=designKind==8?.22:designKind==4?.19:designKind==3?.17:.13;
            double body=designKind==8?3.0:designKind==3?3.1:designKind==6?2.5:1.8;
            auto transport=[&](double head,double gain){
                // Continuous tapered ribbons avoid seams and repeated overlapping strokes.
                double a=std::max(start,head-length),b=std::min(end,head);
                if(b<=a)return;
                auto tail=at(g.center,a),nose=at(g.center,b);
                auto ribbon=[&](double spread,double opacity,bool highlight){
                    std::vector<QPointF> left,right;QPainterPath shape;
                    auto close=[&](){if(left.size()>1){shape.moveTo(left.front());for(size_t j=1;j<left.size();++j)shape.lineTo(left[j]);for(auto j=right.rbegin();j!=right.rend();++j)shape.lineTo(*j);shape.closeSubpath();}left.clear();right.clear();};
                    constexpr int samples=16;
                    for(int j=0;j<=samples;++j){
                        double t=a+(b-a)*j/samples,u=clamp((t-head+length)/length);
                        auto p=at(g.center,t);
                        if(!p.visible){close();continue;}
                        auto before=at(g.center,std::max(0.,t-.01)),after=at(g.center,std::min(1.,t+.01));
                        double dx=after.x-before.x,dy=after.y-before.y,n=std::max(.001,std::hypot(dx,dy));
                        double taper=std::pow(std::sin(Pi*u),.8)*(.25+.75*u);
                        double radius=(highlight?.28:body*.5+spread)*taper;
                        left.push_back({p.x-dy/n*radius,p.y+dx/n*radius});right.push_back({p.x+dy/n*radius,p.y-dx/n*radius});
                    }
                    close();if(shape.isEmpty())return;
                    QLinearGradient light(QPointF(tail.x,tail.y),QPointF(nose.x,nose.y));
                    QColor cool=highlight?blend(designInk,designHighlight,.35):designInk;
                    QColor warm=highlight?blend(designAccent,designHighlight,.35):designAccent;
                    cool.setAlphaF(.10);light.setColorAt(0,cool);cool.setAlphaF(.70);light.setColorAt(.35,cool);light.setColorAt(.8,warm);warm.setAlphaF(.30);light.setColorAt(1,warm);
                    Draw draw{shape,designAccent,1,clamp(alpha*opacity*gain),true};draw.material=QBrush(light);commands.push_back(std::move(draw));
                };
                ribbon(2.0,.17,false);ribbon(0,.90,false);ribbon(0,.65,true);
            };
            for(int packet=0;packet<packets;++packet){
                double t=std::fmod(clock*speed+packet/double(packets)+index*.17,1+length);
                transport(t,1);
            }
            if(front-index<1&&!retiring)transport(end,1.15);
            // Relay contacts sit on the globe: their projected ring foreshortens with the surface.
            auto contact=[&](const Vec &v,double acquisition){
                auto p=project(v);if(!p.visible||p.z<=0)return;
                double n=std::max(.001,std::sqrt(v.x*v.x+v.y*v.y+v.z*v.z));
                Vec normal{v.x/n,v.y/n,v.z/n},ref=std::abs(normal.y)<.9?Vec{0,1,0}:Vec{1,0,0};
                double dot=normal.x*ref.x+normal.y*ref.y+normal.z*ref.z;
                Vec u{ref.x-dot*normal.x,ref.y-dot*normal.y,ref.z-dot*normal.z};
                double m=std::max(.001,std::sqrt(u.x*u.x+u.y*u.y+u.z*u.z));u={u.x/m,u.y/m,u.z/m};
                Vec w{normal.y*u.z-normal.z*u.y,normal.z*u.x-normal.x*u.z,normal.x*u.y-normal.y*u.x};
                double radius=designKind==8?.020+.040*acquisition:.014+.018*acquisition;
                QPainterPath ring;bool drawing=false;
                for(int sample=0;sample<=24;++sample){
                    double angle=sample*Pi*2/24,c=std::cos(angle),s=std::sin(angle);
                    auto q=project({normal.x*std::cos(radius)+(u.x*c+w.x*s)*std::sin(radius),normal.y*std::cos(radius)+(u.y*c+w.y*s)*std::sin(radius),normal.z*std::cos(radius)+(u.z*c+w.z*s)*std::sin(radius)});
                    q.visible=q.z>0;vertex(ring,q,drawing);
                }
                double ringAlpha=designKind==8?.70*std::pow(std::sin(Pi*acquisition),2):.38+.35*(1-acquisition);
                commands.push_back({ring,designAccent,designKind==8?.85:.65,alpha*ringAlpha,false});
                if(designKind==8){
                    fillStyle=designInk;setAlpha(alpha*.10);append(circle(p.x,p.y,5.0),true);
                    commands.push_back({circle(p.x,p.y,2.8),designInk,.6,alpha*.40,false});
                }
                fillStyle=designAccent;setAlpha(alpha*.80);append(circle(p.x,p.y,designKind==8?1.7:1.35),true);
                fillStyle=designHighlight;setAlpha(alpha*.65);append(circle(p.x-.25,p.y-.25,.45),true);
            };
            if(index==0&&start==0)contact(world[side][index].center.front(),0);
            if(end>=1){
                double phase=retiring?retirement:std::fmod(clock*.18+index*.23,1.);
                contact(world[side][index].center.back(),phase);
            }
        }
    }
    void paint(QPainter *p) override {
        p->setWorldTransform(transform, true);
        p->setRenderHint(QPainter::Antialiasing, antialiasing());
        const double gain = std::isfinite(contrastGain) ? std::clamp(contrastGain, .5, 3.) : 1.;
        const double scale = std::isfinite(strokeScale) ? std::clamp(strokeScale, .5, 3.) : 1.;
        for (const auto &cmd : commands) {
            p->setOpacity(clamp(cmd.alpha * gain));
            if (cmd.fill)
                p->fillPath(cmd.path, cmd.material.style()==Qt::NoBrush?QBrush(cmd.color):cmd.material);
            else {
                if (strokeUnderlay.alpha() > 0) {
                    QPen outline(strokeUnderlay, cmd.width * scale + 1.4,
                                 Qt::SolidLine, cmd.cap, Qt::MiterJoin);
                    outline.setMiterLimit(10);
                    p->strokePath(cmd.path, outline);
                }
                QPen pen(cmd.material.style()==Qt::NoBrush?QBrush(cmd.color):cmd.material, cmd.width * scale, Qt::SolidLine, cmd.cap, Qt::MiterJoin);
                pen.setMiterLimit(10);
                p->strokePath(cmd.path, pen);
            }
        }
        emit framePainted();
    }
  signals:
    void framePainted();
};
class CircuitPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
  public:
    void registerTypes(const char *uri) override {
        qmlRegisterType<CircuitPainter>(uri, 1, 0, "CircuitPainter");
    }
};
#include "circuit.moc"
