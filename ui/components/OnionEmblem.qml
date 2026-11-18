import ".."
import QtQuick
import QtQuick.Shapes

Item {
  id: root
  property int appearance: 0
  property bool circuitReady: false
  property real idleOpacity:.28
  property color idleTint:ThemeColors.color("muted")
  property bool active: true
  property bool reducedMotion: false
  property int lightStyle: 1
  readonly property bool lit: circuitReady && lightStyle > 0
  readonly property bool breathing: illumination > 0 && lightStyle === 2 && active && visible && !reducedMotion
  property real illumination: lit ? 1 : 0
  Behavior on illumination {NumberAnimation {duration:root.reducedMotion?0:700;easing.type:Easing.InOutSine}}
  property real lightLevel: 1
  SequentialAnimation on lightLevel {
    running: root.breathing; loops: Animation.Infinite
    NumberAnimation {from: 0.45; to: 1; duration: 2600; easing.type: Easing.InOutSine}
    NumberAnimation {from: 1; to: 0.45; duration: 2600; easing.type: Easing.InOutSine}
    onRunningChanged: if (!running) root.lightLevel = 1
  }
  property color accent: ThemeColors.color("accent")
  property color secondary: ThemeColors.color("bright_blue")
  property string lightRole:"logoLight"
  readonly property color tint: ThemeColors.treatmentColor(lightRole) || (appearance === 3 ? ThemeColors.color("bright_cyan") : appearance === 1 ? secondary : Qt.lighter(accent, 1.35))
  readonly property color outlineTint: circuitReady?tint:(ThemeColors.treatmentColor(lightRole==="trayLight"?"trayIdle":"logoIdle")||idleTint)
  readonly property real outlineWidth:(appearance===1?1.05:1.8)*(circuitReady?(ThemeColors.visualTreatment.logoActiveStrokeScale):1)
  implicitWidth: 38
  implicitHeight: 44
  Accessible.role: Accessible.Graphic
  Accessible.name: "Tor onion"

  // A soft radial bloom behind the vector keeps the outline crisp on every renderer.
  Canvas {
    id: bloom; objectName: "onion-light"
    anchors.centerIn: parent
    width: root.width * (root.lightStyle === 3 ? 3.5 : 2.7)
    height: width
    visible: root.circuitReady && root.illumination > 0
    opacity: root.illumination * root.lightLevel
    onWidthChanged: if(visible)requestPaint()
    onVisibleChanged: if(visible)requestPaint()
    Connections {
      target: root;enabled:bloom.visible
      function onTintChanged() {bloom.requestPaint()}
      function onLightStyleChanged() {bloom.requestPaint()}
    }
    onPaint: {
      if(!visible)return
      var ctx = getContext("2d"); ctx.reset()
      var c = root.tint, r = width / 2
      var glow = ctx.createRadialGradient(r,r,0,r,r,r)
      glow.addColorStop(0, Qt.rgba(c.r,c.g,c.b,root.lightStyle === 3 ? .7 : .5))
      glow.addColorStop(.3, Qt.rgba(c.r,c.g,c.b,.27))
      glow.addColorStop(.65, Qt.rgba(c.r,c.g,c.b,.08))
      glow.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
      ctx.fillStyle = glow; ctx.fillRect(0,0,width,height)
    }
  }

  Item {
    objectName:"onion-outline"
    opacity:root.circuitReady?1:root.idleOpacity
    width: 60; height: 72
    scale: Math.min(root.width / width, root.height / height)
    transformOrigin: Item.TopLeft
    x: (root.width - width * scale) / 2
    y: (root.height - height * scale) / 2
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: root.outlineTint
        strokeWidth: root.outlineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        strokeStyle: root.appearance === 2 ? ShapePath.DashLine : ShapePath.SolidLine
        dashPattern: [0.4, 2.2]
        PathSvg {
          path: "M 32,15 C 31,7 35,3 40,2 C 35,8 35,10 35,14 M 32,15 C 27,10 29,5 33,3 M 32,15 C 31,25 9,31 7,47 C 4,60 15,69 30,69 C 45,69 56,60 53,47 C 50,32 35,28 32,15 Z M 32,17 C 27,33 16,38 15,50 C 14,61 21,68 30,69 M 32,18 C 31,36 23,42 23,53 C 23,61 26,66 30,69 M 32,18 C 35,36 40,41 40,52 C 40,61 36,67 30,69 M 32,17 C 38,31 47,40 47,51 C 47,62 39,68 30,69 M 32,20 C 33,42 32,58 30,69"
        }
      }
    }
  }
}
