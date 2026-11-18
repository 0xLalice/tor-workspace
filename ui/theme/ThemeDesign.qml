pragma Singleton
import QtQuick
import "DesignDefinitions.js" as Definitions
QtObject {
 id:root
 property string design:"original"
 property var styleOverrides:({})
 property string styleOwner:""
 readonly property var definition:Definitions.resolve(design,styleOwner===design?styleOverrides:{})
 // Theme identity is metadata; consumers use presentation capabilities.
 function apply(settings){var next=settings.design||"original";styleOwner=next;styleOverrides=settings.style||{};design=next}
 property string fontFamily:Qt.application.font.family
 property var fontSizes:({})
 property real fontScale:1
 function px(size){return Math.round((fontSizes[size]||size*fontScale)*100)/100}
 // Text resolves aliases and missing desktop fonts through Qt's font fallback.
 // Canvas validates literal family names, so give it the same resolved face.
 property Text fontProbe: Text {visible:false;text:"M";font.family:root.fontFamily}
 function canvasFont(size){return px(size)+"px "+JSON.stringify(fontProbe.fontInfo.family)}
 readonly property int padding:definition.padding
 readonly property int spacing:definition.spacing
 readonly property int diagramStyle:definition.diagram
 function radius(base){return definition.radiusBoost?Math.max(base,Math.min(14,base+definition.radiusBoost)):base}
 function borderAlpha(base){return base}
 function textOpacity(base){return definition.opaqueText?1:base}
}
