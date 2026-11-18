#include <QtQuick/QQuickItem>
#include <QtQuick/QSGGeometryNode>
#include <QtQuick/QSGMaterial>
#include <QtQuick/QSGMaterialShader>
#include <QtQml/QQmlExtensionPlugin>
#include <QtGui/QColor>
#include <QtGui/QVector4D>
#include <cmath>
#include <atomic>
#include <cstring>
struct SparkMaterial:QSGMaterial {
 QVector4D pose,viewport,style,tint,timing;
 SparkMaterial(){setFlag(Blending);setFlag(NoBatching);setFlag(RequiresFullMatrix);}
 QSGMaterialType *type()const override{static QSGMaterialType t;return &t;}
 QSGMaterialShader *createShader(QSGRendererInterface::RenderMode)const override;
};
class SparkShader:public QSGMaterialShader {
public:
 SparkShader(){setShaderFileName(VertexStage,":/sparks/sparks.vert.qsb");setShaderFileName(FragmentStage,":/sparks/sparks.frag.qsb");}
 bool updateUniformData(RenderState &s,QSGMaterial *m,QSGMaterial*)override {
  auto *v=static_cast<SparkMaterial*>(m);auto *d=s.uniformData();
  auto matrix=s.combinedMatrix();memcpy(d->data(),matrix.constData(),64);
  float opacity=s.opacity();memcpy(d->data()+64,&opacity,4);
  auto copy=[&](int offset,const QVector4D &x){float f[]={x.x(),x.y(),x.z(),x.w()};memcpy(d->data()+offset,f,16);};
  copy(80,v->pose);copy(96,v->viewport);copy(112,v->style);copy(128,v->tint);copy(144,v->timing);return true;
 }
};
QSGMaterialShader *SparkMaterial::createShader(QSGRendererInterface::RenderMode)const{return new SparkShader;}
struct Vertex{float x,y,z,u,v,phase;};
class Sparks:public QQuickItem {
 Q_OBJECT
 Q_PROPERTY(QVariantList points READ points WRITE setPoints NOTIFY pointsChanged)
 Q_PROPERTY(QVariantMap config READ config WRITE setConfig NOTIFY configChanged)
 Q_PROPERTY(int geometryUploads READ geometryUploads NOTIFY geometryUploadsChanged)
public:
 Sparks(){setFlag(ItemHasContents);}
 QVariantList points()const{return data;}
 QVariantMap config()const{return settings;}
 int geometryUploads()const{return uploads;}
 void setPoints(const QVariantList &v){if(data==v)return;data=v;dirty=true;update();emit pointsChanged();}
 void setConfig(const QVariantMap &v){settings=v;update();emit configChanged();}
signals:void pointsChanged();void configChanged();void geometryUploadsChanged();
protected:
 void geometryChange(const QRectF &r,const QRectF &old)override{QQuickItem::geometryChange(r,old);update();}
 QSGNode *updatePaintNode(QSGNode *old,UpdatePaintNodeData*)override {
  auto *node=static_cast<QSGGeometryNode*>(old);
  if(!node){node=new QSGGeometryNode;node->setMaterial(new SparkMaterial);node->setFlag(QSGNode::OwnsMaterial);dirty=true;}
  if(dirty){
   static QSGGeometry::Attribute attrs[]={QSGGeometry::Attribute::create(0,3,QSGGeometry::FloatType,true),QSGGeometry::Attribute::create(1,2,QSGGeometry::FloatType),QSGGeometry::Attribute::create(2,1,QSGGeometry::FloatType)};
   static QSGGeometry::AttributeSet set={3,sizeof(Vertex),attrs};
   auto *geometry=new QSGGeometry(set,data.size()*6);geometry->setDrawingMode(QSGGeometry::DrawTriangles);geometry->setVertexDataPattern(QSGGeometry::StaticPattern);
   auto *out=static_cast<Vertex*>(geometry->vertexData());const float corners[][2]={{-1,-1},{1,-1},{-1,1},{-1,1},{1,-1},{1,1}};
   for(const auto &entry:data){
    const auto p=entry.toMap();
    double lon=p["longitude"].toDouble()*M_PI/180.;
    double lat=p["latitude"].toDouble()*M_PI/180.;
    float phase=p["phase"].toFloat();
    for(auto &c:corners)*out++={float(cos(lat)*sin(lon)),float(sin(lat)),float(cos(lat)*cos(lon)),c[0],c[1],phase};
   }
   // setGeometry releases the previous geometry when OwnsGeometry is set.
   node->setGeometry(geometry);node->setFlag(QSGNode::OwnsGeometry);node->markDirty(QSGNode::DirtyGeometry);dirty=false;uploads++;QMetaObject::invokeMethod(this,[this]{emit geometryUploadsChanged();},Qt::QueuedConnection);
  }
  auto *m=static_cast<SparkMaterial*>(node->material());auto f=[&](const char *key,float fallback){return settings.value(key,fallback).toFloat();};
  m->pose={f("longitude",0)*float(M_PI/180),f("latitude",20)*float(M_PI/180),f("roll",23.44)*float(M_PI/180),0};
  m->viewport={float(width()),float(height()),f("sphereSize",width())*.42f*f("zoom",1),0};
  m->style={f("intensity",.7),f("dotSize",.75),f("halo",.3),f("sparkle",.5)};
  QColor tint(settings.value("color","#98c9c1").toString());m->tint={float(tint.redF()),float(tint.greenF()),float(tint.blueF()),1};
  m->timing={f("clock",0),f("pulseSpeed",1.2),f("pulseFloor",.06),0};
  node->markDirty(QSGNode::DirtyMaterial);return node;
 }
private:QVariantList data;QVariantMap settings;bool dirty=true;std::atomic<int> uploads{0};
};
class SparkPlugin:public QQmlExtensionPlugin {
 Q_OBJECT
 Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:void registerTypes(const char *uri)override{qmlRegisterType<Sparks>(uri,1,0,"SparkField");}
};
#include "Sparks.moc"
