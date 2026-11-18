import ".."
import QtQuick
Item {
 id:root
 property var points:[]
 property real clock:0
 property int variant:3
 property real longitude:0
 property real latitude:20
 property real roll:23.44
 property real zoom:1
 property real sphereSize:width
 property color lightColor:ThemeColors.color("exitLight")
 property real intensity:.72
 property real dotSize:.85
 property real halo:.35
 property real sparkle:.5
 property real pulseSpeed:1.2
 property real pulseFloor:.06
 readonly property var renderedPose:({longitude:longitude,latitude:latitude,roll:roll,zoom:zoom})
 readonly property bool rendererLoaded:loader.item!==null
 readonly property int geometryUploads:loader.item?loader.item.geometryUploads:0
 readonly property int atlasPaintCount:0
 Loader {
  id:loader;anchors.fill:parent;active:root.visible&&root.points.length>0&&RenderCapabilities.nativeReady
  source:Qt.resolvedUrl("GpuExitLights.qml").toString().replace(/^qs:/,"file:")
  onLoaded: {
   item.points=Qt.binding(function(){return root.points})
   item.clock=Qt.binding(function(){return root.clock})
   item.longitude=Qt.binding(function(){return root.longitude})
   item.latitude=Qt.binding(function(){return root.latitude})
   item.roll=Qt.binding(function(){return root.roll})
   item.zoom=Qt.binding(function(){return root.zoom})
   item.sphereSize=Qt.binding(function(){return root.sphereSize})
   item.lightColor=Qt.binding(function(){return root.lightColor})
   item.intensity=Qt.binding(function(){return root.intensity})
   item.dotSize=Qt.binding(function(){return root.dotSize})
   item.halo=Qt.binding(function(){return root.halo})
   item.sparkle=Qt.binding(function(){return root.sparkle})
   item.pulseSpeed=Qt.binding(function(){return root.pulseSpeed})
   item.pulseFloor=Qt.binding(function(){return root.pulseFloor})
  }
 }
}
