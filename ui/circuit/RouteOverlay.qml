import ".."
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "RouteGeometry.js" as Geometry

Item {
  id: root
  property var route: []
  property bool showMarkers: false
  property real longitude: 0
  property real latitude: 0
  property bool active: false
  property int appearance: 0
  property color accent: ThemeColors.color("accent")
  property color secondary: ThemeColors.color("bright_blue")
  property real time: 0
  readonly property var legs: visible ? Geometry.legs(route) : []
  readonly property var markers: visible && showMarkers ? Geometry.markers(route, longitude, latitude, width) : []
  readonly property var paths: visible ? legs.map(function(leg) { return Geometry.path(leg, longitude, latitude, width) }) : []

  Repeater {
    model: root.legs.length
    delegate: Shape {
      id: legShape
      required property int index
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      layer.enabled: root.appearance === 3
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: ThemeColors.color("accent"); shadowOpacity: 1; shadowBlur: 0.65; shadowVerticalOffset: 0 }
      readonly property color routeColor: root.appearance === 3 ? ThemeColors.color("bright_blue") : root.appearance === 1 ? Qt.lighter(root.secondary, 1.3) : Qt.lighter(root.accent, 1.4)
      ShapePath {
        strokeColor: Qt.rgba(legShape.routeColor.r, legShape.routeColor.g, legShape.routeColor.b, root.appearance === 3 ? 0.32 : root.appearance === 0 ? 0.10 : 0)
        strokeWidth: root.appearance === 3 ? 6 : 2.5; fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg { path: root.paths[index] || "" }
      }
      ShapePath {
        strokeColor: Qt.rgba(legShape.routeColor.r, legShape.routeColor.g, legShape.routeColor.b,
          root.appearance === 0 ? 0.68 + 0.22 * Math.sin(root.time * 0.65 - legShape.index * 0.7) : 0.78)
        strokeWidth: root.appearance === 3 ? 1.7 : root.appearance === 1 ? 0.65 : 0.8
        fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathSvg { path: root.paths[index] || "" }
      }
    }
  }
  Repeater {
    model: root.showMarkers ? root.markers.length : 0
    delegate: Rectangle {
      id: relayMarker
      required property int index
      readonly property var marker: root.markers[index]
      x: marker.anchorX - width / 2; y: marker.anchorY - height / 2
      width: root.appearance === 3 ? 12 : root.appearance === 1 ? 6 : 3
      height: width; radius: width / 2
      color: root.appearance === 3 ? ThemeColors.color("routeSurface") : root.appearance === 1 ? "transparent" : ThemeColors.color("light_foreground")
      border.width: root.appearance === 3 ? 0.8 : root.appearance === 1 ? 0.6 : 0
      border.color: root.appearance === 3 ? ThemeColors.color("bright_blue") : Qt.lighter(root.secondary, 1.3)
      Rectangle {
        anchors.centerIn: parent
        visible: root.appearance === 3
        width: 6; height: 6; radius: 3; color: ThemeColors.color("light_foreground")
      }
      Rectangle {
        anchors.centerIn: parent
        visible: root.appearance === 3
        width: 16; height: 16; radius: 8; color: "transparent"
        border.width: 0.6; border.color: Qt.alpha(ThemeColors.color("routeBorder"),80/255)
      }
      Accessible.role: Accessible.StaticText
      Accessible.name: marker.country || "Relay location"
    }
  }
  Repeater {
    model: root.visible && root.appearance === 3 ? Geometry.callouts(root.route, root.longitude, root.latitude, root.width) : []
    delegate: Item {
      required property var modelData
      anchors.fill: parent
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0.65; strokeColor: Qt.alpha(ThemeColors.color("routeStroke"),153/255); fillColor: "transparent"
          startX: modelData.anchorX; startY: modelData.anchorY
          PathLine { x: modelData.edgeX; y: modelData.edgeY }
        }
      }
      Item {
        x: modelData.x; y: modelData.y
        width: modelData.width; height: modelData.height
        Accessible.role: Accessible.StaticText
        Accessible.name: modelData.country + ": " + modelData.roles
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeWidth: 0.7; strokeColor: ThemeColors.color("accent"); fillColor: Qt.alpha(ThemeColors.color("routeLabelSurface"),237/255)
            startX: 7; startY: 0
            PathLine { x: modelData.width-7; y: 0 }
            PathLine { x: modelData.width; y: 7 }
            PathLine { x: modelData.width; y: modelData.height-7 }
            PathLine { x: modelData.width-7; y: modelData.height }
            PathLine { x: 7; y: modelData.height }
            PathLine { x: 0; y: modelData.height-7 }
            PathLine { x: 0; y: 7 }
            PathLine { x: 7; y: 0 }
          }
        }
        Text {
          x: 8; y: 6; width: parent.width-37
          text: modelData.country.toUpperCase()
          color: ThemeColors.color("light_foreground"); font.family:ThemeDesign.fontFamily
          font.pixelSize:ThemeDesign.px(9); font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
        Text {
          x: 8; y: 21; width: parent.width-14
          text: modelData.roles
          color: ThemeColors.color("dark_foreground"); font.family:ThemeDesign.fontFamily
          font.pixelSize:ThemeDesign.px(7); font.letterSpacing: 0.5
          elide: Text.ElideRight
        }
        Text {
          anchors.right: parent.right; anchors.rightMargin: 7; y: 4
          text: /^[A-Z]{2}$/.test(modelData.code)
            ? String.fromCodePoint(127397+modelData.code.charCodeAt(0),127397+modelData.code.charCodeAt(1)) : ""
          font.family:ThemeDesign.fontFamily; font.pixelSize:ThemeDesign.px(18)
          renderType: Text.NativeRendering
        }
      }
    }
  }

}
