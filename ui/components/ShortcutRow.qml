import ".."
import QtQuick
import QtQuick.Controls

Row {
 id:root
 property var bindings:({})
 property bool busy:false
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 signal changed(string action,string key)
 onCurrentKeyChanged:key.text=currentKey
 onBusyChanged:if(!busy)key.text=currentKey
 spacing:8
 readonly property string currentKey:bindings.open&&bindings.open.key?bindings.open.key.split(" + ").pop():""
 Text {text:"Super / Super ⇧";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);anchors.verticalCenter:parent.verticalCenter}
 TextField {
  id:key;objectName:"shortcut-key";width:32;height:28;text:root.currentKey;placeholderText:""
  maximumLength:1;validator:RegularExpressionValidator {regularExpression:/[a-zA-Z]?/}
  enabled:!root.busy;selectByMouse:true;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);horizontalAlignment:Text.AlignHCenter
  Accessible.name:"Tor shortcut key";background:Rectangle {radius:ThemeDesign.radius(4);color:Qt.alpha(root.accent,key.activeFocus?.12:.05);border.color:Qt.alpha(root.accent,key.activeFocus?.6:.2)}
  onTextEdited:if(text.length===1){root.changed("pair",text.toUpperCase());focus=false}
  Keys.onEscapePressed:{text=root.currentKey;focus=false}
  Keys.onReturnPressed:{root.changed("pair",text.toUpperCase());focus=false}
 }
}
