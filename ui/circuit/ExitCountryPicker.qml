import ".."
import QtQuick
import QtQuick.Controls

Item {
 id:root
 property var countries:[]
 property string country:""
 property string observedCountry:""
 property color ink:ThemeColors.color("foreground")
 property color accent:ThemeColors.color("accent")
 property bool opened:false
 property bool sharedTooltip:false
 property var route:[]
 readonly property bool hovered:labelMouse.containsMouse||pin.hovered
 property bool sidePicker:false
 property bool openToLeft:false
 property string closedLabel:selectedLabel
 property real labelSize:10
 property real labelSpacing:1
 property var openCountries:[]
 property real scrollRemainder:0
 property bool pixelScrolling:false
 readonly property int rowHeight:26
 readonly property int selectedIndex:{for(var i=0;i<countries.length;i++)if(countries[i].code===country)return i;return -1}
 readonly property string selectedLabel:country?country.toUpperCase():"AUTO"
 signal chosen(string code)
 signal pinRequested(string code)
 implicitHeight:rowHeight
 activeFocusOnTab:true
 Accessible.role:Accessible.ComboBox
 Accessible.name:"Exit country"
 Accessible.description:selectedLabel
 function open() {
  if(!enabled||!countries.length)return
  openCountries=countries;scrollRemainder=0;opened=true;forceActiveFocus()
  wheel.currentIndex=Math.max(0,selectedIndex)
  wheel.positionViewAtIndex(wheel.currentIndex,ListView.Center)
 }
 function choose(index) {
  if(index<0||index>=openCountries.length)return
  chosen(openCountries[index].code);opened=false
 }
 function step(delta) {
  if(!opened)open()
  if(wheel.moving){wheel.cancelFlick();syncIndex()}
  wheel.currentIndex=Math.max(0,Math.min(openCountries.length-1,wheel.currentIndex+delta))
  wheel.positionViewAtIndex(wheel.currentIndex,ListView.Center)
 }
 function syncIndex() {
  var index=wheel.indexAt(wheel.width/2,wheel.contentY+wheel.height/2)
  if(index>=0)wheel.currentIndex=index
 }
 function scroll(event) {
  event.accepted=true
  forceActiveFocus()
  var pixels=event.pixelDelta.y!==0
  var delta=-(pixels?event.pixelDelta.y:event.angleDelta.y)
  if(!delta)return
  if(pixelScrolling!==pixels||event.phase===Qt.ScrollBegin||scrollRemainder*delta<0)scrollRemainder=0
  pixelScrolling=pixels
  scrollRemainder+=delta
  var unit=pixels?rowHeight:120
  var steps=Math.trunc(scrollRemainder/unit)
  if(!steps)return
  scrollRemainder-=steps*unit
  step(steps)
  if(wheel.currentIndex===0||wheel.currentIndex===openCountries.length-1)scrollRemainder=0
 }
 onEnabledChanged:if(!enabled)opened=false
 Keys.onPressed:function(event) {
  if(event.key===Qt.Key_Down){step(1);event.accepted=true}
  else if(event.key===Qt.Key_Up){step(-1);event.accepted=true}
  else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter||event.key===Qt.Key_Space){if(opened)choose(wheel.currentIndex);else open();event.accepted=true}
  else if(event.key===Qt.Key_Escape&&opened){opened=false;event.accepted=true}
 }
 Text {
  id:codeLabel
  anchors.verticalCenter:parent.verticalCenter;anchors.horizontalCenter:parent.horizontalCenter;anchors.horizontalCenterOffset:pin.visible&&!root.sidePicker?-5:0;visible:!root.opened
  width:Math.min(implicitWidth,parent.width-(pin.visible&&!root.sidePicker?14:4));horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
  text:root.closedLabel;color:labelMouse.containsMouse||root.activeFocus?root.accent:root.ink
  font.pixelSize:ThemeDesign.px(root.labelSize);font.letterSpacing:root.labelSpacing;font.family:ThemeDesign.fontFamily
  opacity:root.enabled?0.85:0.4
  font.weight:root.country?Font.Medium:Font.Normal
 }
 MouseArea {
  id:labelMouse;anchors.fill:parent;anchors.rightMargin:pin.visible&&!root.sidePicker?12:0;visible:!root.opened;hoverEnabled:true
  cursorShape:Qt.PointingHandCursor
  onClicked:root.open()
 }
 CircuitToolTip {route:root.route;hovered:root.hovered&&!root.opened&&!root.sharedTooltip;exitAction:true;ink:root.ink;accent:root.accent}

 Button {
  id:pin;objectName:"exit-country-pin";hoverEnabled:true
  width:14;height:22;padding:0;x:root.sidePicker?(root.width+codeLabel.width)/2+3:root.width-width;anchors.verticalCenter:parent.verticalCenter
  visible:!root.opened&&!!(root.country||root.observedCountry)
  Accessible.name:root.country?"Remove country restriction":"Use this exit country"
  onClicked:root.pinRequested(root.country?"":root.observedCountry)
  background:Item {}
  contentItem:Item {
   Canvas {
   anchors.centerIn:parent;width:12;height:16
   id:pinGlyph;opacity:pin.hovered?1:root.country?.9:.35
   onPaint:{
    var c=getContext("2d");c.reset();c.strokeStyle=root.country?root.accent:root.ink;c.lineWidth=1;c.lineCap="round"
    c.strokeRect(2.5,7,7,6)
    c.beginPath();c.moveTo(4,7);c.lineTo(4,5);c.bezierCurveTo(4,2,8,2,8,5)
    if(root.country)c.lineTo(8,7)
    c.stroke()
   }
   Connections {target:root;function onCountryChanged(){pinGlyph.requestPaint()}function onInkChanged(){pinGlyph.requestPaint()}function onAccentChanged(){pinGlyph.requestPaint()}}
  }
  }
  HoverHandler {cursorShape:pin.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
 }
 ListView {
  id:wheel;objectName:"exit-country-wheel"
  visible:root.opened||opacity>0;enabled:root.opened;opacity:root.opened?1:0
  Behavior on opacity {NumberAnimation {duration:180;easing.type:Easing.InOutSine}}
  x:root.sidePicker?(root.openToLeft?8-width:root.width-8):0;y:root.sidePicker?(root.height-height)/2:root.height-height;width:root.sidePicker?44:root.width;height:5*root.rowHeight
  clip:true;model:root.openCountries;spacing:0
  topMargin:2*root.rowHeight;bottomMargin:2*root.rowHeight
  boundsBehavior:Flickable.StopAtBounds;snapMode:ListView.SnapToItem
  highlightMoveDuration:0
  onMovementEnded:root.syncIndex()
  delegate:Item {
   required property int index
   required property var modelData
   width:wheel.width;height:root.rowHeight
   readonly property real distance:Math.abs((y-wheel.contentY+height/2)-wheel.height/2)/height
   opacity:Math.pow(Math.max(0,1-distance/2.5),1.5)
   Text {
    anchors.centerIn:parent;width:parent.width-4;text:modelData.code?modelData.code.toUpperCase():"AUTO"
    horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
    color:optionMouse.containsMouse?root.accent:root.ink
    font.pixelSize:ThemeDesign.px(root.labelSize);font.letterSpacing:root.labelSpacing;font.family:ThemeDesign.fontFamily
   }
   MouseArea {
    id:optionMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
    onClicked:root.choose(index)
   }
  }
 }
 // A stationary hit area covers the list AND the label where it was opened.
 // Keep it outside ListView's scrolling content and above the globe. Mouse
 // clicks and drags still pass through to the country delegates.
 MouseArea {
  objectName:"exit-country-scroll-area";z:2
  visible:root.opened;acceptedButtons:Qt.NoButton
  x:Math.min(0,wheel.x)-4;y:Math.min(0,wheel.y)-4
  width:Math.max(root.width,wheel.x+wheel.width)-x+4
  height:Math.max(root.height,wheel.y+wheel.height)-y+4
  onWheel:function(event){root.scroll(event)}
 }
}
