import QtQuick
import "../../build/qml/gpu" as Gpu
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
 property color lightColor:"transparent"
 property real intensity:.72
 property real dotSize:.85
 property real halo:.35
 property real sparkle:.5
 property real pulseSpeed:1.2
 property real pulseFloor:.06
 readonly property var renderedPose:({longitude:longitude,latitude:latitude,roll:roll,zoom:zoom})
 readonly property int geometryUploads:sparks.geometryUploads
 readonly property int atlasPaintCount:0
 Gpu.SparkField {
  id:sparks;anchors.fill:parent;points:root.points
  config:({longitude:root.longitude,latitude:root.latitude,roll:root.roll,zoom:root.zoom,sphereSize:root.sphereSize,
   clock:root.clock,color:String(root.lightColor),intensity:root.intensity,dotSize:root.dotSize,halo:root.halo,sparkle:root.sparkle,pulseSpeed:root.pulseSpeed,pulseFloor:root.pulseFloor})
 }
}
