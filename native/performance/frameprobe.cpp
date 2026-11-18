#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickWindow>
#include <QtQml/QQmlExtensionPlugin>
#include <QtQml/qqml.h>
#include <QElapsedTimer>
#include <QMutex>
#include <QMutexLocker>
#include <QTimer>
#include <QScreen>
#include <QGuiApplication>
#include <QSGRendererInterface>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <deque>
#include <vector>
#include <algorithm>
#include <cmath>
#include <memory>

// Only this shared state is touched by the render-thread callback. No QML, disk
// writes, queued per-frame signals or wall-clock timestamps on the hot path.
struct Samples {
    QMutex mutex;
    QElapsedTimer clock;
    std::deque<qint64> recent;
    std::vector<qint64> capture;
    bool enabled=false, recording=false, truncated=false;
    int graphicsApi=0;
    qint64 started=0, captureStart=0;
    Samples(){clock.start();capture.reserve(72000);}
};
static QVariantMap summarize(const std::vector<qint64>& frames, qint64 start, qint64 end, double hz) {
    const double seconds=std::max(0.0, double(end-start)/1e9);
    std::vector<double> intervals;
    int late=0;
    for(size_t i=1;i<frames.size();++i){
        const double ms=double(frames[i]-frames[i-1])/1e6;
        intervals.push_back(ms);
        if(ms>1500.0/hz)++late;
    }
    std::sort(intervals.begin(),intervals.end());
    auto p=[&](double fraction)->QVariant {
        if(intervals.empty())return QVariant();
        return intervals[std::max(0,int(std::ceil(fraction*intervals.size()))-1)];
    };
    return {{"fps",seconds>0?frames.size()/seconds:0.0},{"seconds",seconds},
        {"frames",int(frames.size())},{"intervals",int(intervals.size())},
        {"p50Ms",p(.5)},{"p95Ms",p(.95)},{"p99Ms",p(.99)},{"maxMs",p(1)},
        {"lateIntervals",late},{"budgetMs",1000.0/hz}};
}
class FrameProbe : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(bool collecting READ collecting WRITE setCollecting NOTIFY collectingChanged)
    Q_PROPERTY(bool hud READ hud WRITE setHud NOTIFY hudChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY statsChanged)
    Q_PROPERTY(QString lastCapture READ lastCapture NOTIFY captureChanged)
    Q_PROPERTY(QString error READ error NOTIFY captureChanged)
    std::shared_ptr<Samples> data=std::make_shared<Samples>();
    QMetaObject::Connection connection;
    QTimer ticker, finish;
    bool m_collecting=false,m_hud=true;
    QVariantMap m_stats, metadata;
    QString m_path,m_error;
    double refreshRate() const {return window()&&window()->screen()?std::max(1.0,window()->screen()->refreshRate()):60.0;}
    void attach(QQuickWindow* w){
        disconnect(connection);
        if(recording()){m_error="Capture interrupted: window changed";stopCapture();}
        {QMutexLocker lock(&data->mutex);data->recent.clear();data->started=data->clock.nsecsElapsed();}
        if(!w)return;
        // The callback owns state independently of the QML item's lifetime.
        auto state=data;
        connection=connect(w,&QQuickWindow::frameSwapped,w,[state,w](){
            QMutexLocker lock(&state->mutex);
            if(!state->enabled)return;
            state->graphicsApi=int(w->rendererInterface()->graphicsApi());
            qint64 now=state->clock.nsecsElapsed();
            state->recent.push_back(now);
            while(!state->recent.empty()&&(state->recent.size()>72000||state->recent.front()<now-5000000000LL))state->recent.pop_front();
            if(state->recording){
                if(state->capture.size()<72000)state->capture.push_back(now);
                else state->truncated=true;
            }
        },Qt::DirectConnection);
    }
public:
    FrameProbe(){
        connect(this,&QQuickItem::windowChanged,this,&FrameProbe::attach);
        ticker.setInterval(1000);
        connect(&ticker,&QTimer::timeout,this,&FrameProbe::publish);
        finish.setSingleShot(true);connect(&finish,&QTimer::timeout,this,&FrameProbe::stopCapture);
    }
    ~FrameProbe() override {disconnect(connection);if(recording()){m_error="Capture interrupted: probe unloaded";stopCapture();}}
    bool collecting() const{return m_collecting;}
    bool hud() const{return m_hud;}
    bool recording() const{QMutexLocker lock(&data->mutex);return data->recording;}
    QVariantMap stats() const{return m_stats;}
    QString lastCapture() const{return m_path;}
    QString error() const{return m_error;}
    void setCollecting(bool value){
        if(value==m_collecting)return;
        if(!value&&recording()){m_error="Capture interrupted: panel closed or diagnostics disabled";stopCapture();}
        m_collecting=value;
        {QMutexLocker lock(&data->mutex);data->enabled=value;data->recent.clear();data->started=data->clock.nsecsElapsed();}
        m_stats.clear();emit statsChanged();
        if(value&&m_hud)ticker.start();else ticker.stop();
        emit collectingChanged();
    }
    void setHud(bool value){if(m_hud==value)return;m_hud=value;if(value&&m_collecting)ticker.start();else ticker.stop();emit hudChanged();}
    Q_INVOKABLE QVariantMap snapshot() const {
        std::vector<qint64> frames;qint64 now,start;
        {QMutexLocker lock(&data->mutex);now=data->clock.nsecsElapsed();start=std::max(data->started,now-5000000000LL);
         for(auto t:data->recent)if(t>=start)frames.push_back(t);}
        auto result=summarize(frames,start,now,refreshRate());
        const qint64 fpsStart=std::max(start,now-1000000000LL);
        auto count=std::count_if(frames.begin(),frames.end(),[fpsStart](qint64 t){return t>=fpsStart;});
        result["fps5s"]=result["fps"];
        result["fps"]=now>fpsStart?double(count)*1e9/double(now-fpsStart):0.0;
        result["source"]="QQuickWindow.frameSwapped / render-thread monotonic clock";
        result["refreshHz"]=refreshRate();result["collecting"]=m_collecting;
        result["scope"]="whole Qt Quick window; submitted frames, not compositor presentation";
        result["hud"]=m_hud;result["recording"]=recording();result["lastCapture"]=m_path;result["error"]=m_error;
        if(window()){result["windowWidth"]=window()->width();result["windowHeight"]=window()->height();result["devicePixelRatio"]=window()->devicePixelRatio();}
        return result;
    }
    Q_INVOKABLE void publish(){m_stats=snapshot();emit statsChanged();}
    Q_INVOKABLE bool startCapture(int seconds, const QVariantMap& context){
        if(!m_collecting||!window()||recording()||seconds<1||seconds>300)return false;
        metadata=context;metadata["qtVersion"]=qVersion();metadata["hud"]=m_hud;
        metadata["startedUtc"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
        metadata["refreshHz"]=refreshRate();
        metadata["windowWidth"]=window()->width();metadata["windowHeight"]=window()->height();
        metadata["devicePixelRatio"]=window()->devicePixelRatio();
        metadata["requestedSeconds"]=seconds;
        metadata["pid"]=QCoreApplication::applicationPid();
        metadata["platform"]=QGuiApplication::platformName();
        metadata["renderLoopOverride"]=QString::fromLocal8Bit(qgetenv("QSG_RENDER_LOOP"));
        {QMutexLocker lock(&data->mutex);metadata["graphicsApi"]=data->graphicsApi;}
        m_error.clear();m_path.clear();
        {QMutexLocker lock(&data->mutex);data->capture.clear();data->truncated=false;data->captureStart=data->clock.nsecsElapsed();data->recording=true;}
        finish.start(seconds*1000);emit recordingChanged();emit captureChanged();return true;
    }
    Q_INVOKABLE void stopCapture(){
        std::vector<qint64> frames;qint64 start,end;bool truncated;
        {QMutexLocker lock(&data->mutex);if(!data->recording)return;data->recording=false;
         frames=data->capture;start=data->captureStart;end=data->clock.nsecsElapsed();truncated=data->truncated;}
        finish.stop();
        QJsonArray timestamps;for(auto t:frames)timestamps.append(double(t-start)/1e6);
        auto summary=summarize(frames,start,end,metadata.value("refreshHz").toDouble());
        QString dir=QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)+"/omarchy/tor-panel/performance";
        QDir().mkpath(dir);QFile::setPermissions(dir,QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);
        QString path=dir+"/frames-"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss-zzz")+".json";
        QSaveFile file(path);
        QJsonObject report{{"version",1},{"source","QQuickWindow.frameSwapped"},
          {"clock","monotonic render-thread nanosecond clock; exported as milliseconds"},
          {"scope","whole window frame submissions; not GPU execution time or physical presentation"},
          {"metadata",QJsonObject::fromVariantMap(metadata)},{"summary",QJsonObject::fromVariantMap(summary)},
          {"frameTimestampsMs",timestamps},{"truncated",truncated},{"interruption",m_error}};
        if(!file.open(QIODevice::WriteOnly)){m_error=file.errorString();}
        else{file.setPermissions(QFile::ReadOwner|QFile::WriteOwner);
          auto bytes=QJsonDocument(report).toJson();
          if(file.write(bytes)!=bytes.size()||!file.commit())m_error=file.errorString();else m_path=path;}
        emit recordingChanged();emit captureChanged();
    }
signals:
    void collectingChanged();void hudChanged();void recordingChanged();void statsChanged();void captureChanged();
};
class PerformancePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:void registerTypes(const char* uri) override {qmlRegisterType<FrameProbe>(uri,1,0,"FrameProbe");}
};
#include "frameprobe.moc"

#ifdef FRAMEPROBE_TEST_MAIN
#include <cassert>
int main(){
    std::vector<qint64> frames;
    for(int i=1;i<=60;i++)frames.push_back(qint64(i)*1000000000LL/60);
    auto normal=summarize(frames,0,1000000000LL,60);
    assert(normal["frames"].toInt()==60);
    assert(normal["fps"].toDouble()==60);
    assert(std::abs(normal["p99Ms"].toDouble()-1000.0/60)<.001);
    assert(normal["lateIntervals"].toInt()==0);
    frames.push_back(1200000000LL);
    auto stall=summarize(frames,0,1200000000LL,60);
    assert(stall["maxMs"].toDouble()==200);
    assert(stall["lateIntervals"].toInt()==1);
    auto empty=summarize({},0,1000000000LL,60);
    assert(empty["fps"].toDouble()==0);
    assert(!empty["p99Ms"].isValid());
    auto single=summarize({1000000000LL},0,1000000000LL,60);
    assert(single["frames"].toInt()==1 && single["intervals"].toInt()==0);
    return 0;
}
#endif
