import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/EffectSettings.js" as Effects
TestCase {
 id:test;name:"ExitCountryScroll";when:windowShown;visible:true;width:400;height:400
 property int leaked:0
 MouseArea {anchors.fill:parent;onWheel:function(event){test.leaked++;event.accepted=true}}
 Tor.ExitCountryPicker {id:picker;x:100;y:200;width:60;height:30;countries:Array.from({length:80},(_,i)=>({code:i===0?"":String(i),name:"Country "+i}))}
 Component {id:dashboardFactory;Tor.TorDashboard {}}
 function init(){picker.visible=true;picker.sidePicker=false;picker.country="";picker.open();wait(200);test.leaked=0}
 function cleanup(){picker.opened=false}
 function visualChild(item,name){
  if(item.objectName===name)return item
  for(var child of item.children||[]){var found=visualChild(child,name);if(found)return found}
  return null
 }
 function test_main_interface_keeps_globe_still_data(){return [{tag:"left",layout:3},{tag:"right",layout:7},{tag:"right-low",layout:11},{tag:"right-orbit",layout:14}]}
 function test_main_interface_keeps_globe_still(data){
  picker.visible=false
  var panel=createTemporaryObject(dashboardFactory,test,{width:400,height:400,z:5,active:true,torRunning:true,showLaunchControls:true,exitCountries:picker.countries,interfaceSettings:Effects.interfaceConfig({layout:data.layout,uiScale:1.15}),route:[{country:"TH"},{country:"DE"},{country:"FR"},{country:"US"}]})
  wait(1000)
  var selector=visualChild(panel,"interface-exit-country-selector")
  verify(selector!==null);selector.open();wait(200)
  var wheel=findChild(selector,"exit-country-wheel"),zoom=panel.globe.zoomLevel
  mouseWheel(selector,selector.width/2,selector.height/2,0,-120)
  compare(wheel.currentIndex,1);compare(panel.globe.zoomLevel,zoom)
  wait(100)
  mouseWheel(wheel,wheel.width/2,wheel.height/2,0,-120)
  compare(wheel.currentIndex,2);compare(panel.globe.zoomLevel,zoom)
  var point=wheel.mapToItem(panel,0,0);verify(point.x>=0&&point.x+wheel.width*1.15<=panel.width)
  wheel.currentIndex=79;wheel.positionViewAtIndex(79,ListView.Center)
  mouseWheel(selector,selector.width/2,selector.height/2,0,-120)
  compare(wheel.currentIndex,79);compare(panel.globe.zoomLevel,zoom)
  selector.forceActiveFocus();keyClick(Qt.Key_Escape);verify(!selector.opened)
  panel.destroy()
 }
 function test_long_list_data(){return [{tag:"footer",side:false},{tag:"side",side:true}]}
 function test_long_list(data){
  picker.sidePicker=data.side;wait(50)
  var wheel=findChild(picker,"exit-country-wheel")
  for(var i=1;i<65;i++){
   mouseWheel(wheel,wheel.width/2,wheel.height/2,0,-120)
   wait(15);compare(wheel.currentIndex,i,"Scroll at country "+i)
   fuzzyCompare(wheel.currentItem.mapToItem(wheel,0,13).y,65,1)
  }
  compare(test.leaked,0)
  for(var j=63;j>=0;j--){mouseWheel(wheel,wheel.width/2,wheel.height/2,0,120);compare(wheel.currentIndex,j)}
 }
 function test_small_wheel_deltas(){
  var wheel=findChild(picker,"exit-country-wheel")
  for(var i=0;i<12;i++)mouseWheel(wheel,wheel.width/2,wheel.height/2,0,-10)
  compare(wheel.currentIndex,1,"One wheel notch split into small events must move one country")
 }
 function test_drag_then_wheel(){
  var wheel=findChild(picker,"exit-country-wheel")
  mouseDrag(wheel,wheel.width/2,100,0,-70,Qt.LeftButton)
  wait(500)
  var center=wheel.indexAt(wheel.width/2,wheel.contentY+wheel.height/2)
  verify(center>0,"List dragged")
  mouseWheel(wheel,wheel.width/2,wheel.height/2,0,-120)
  compare(wheel.currentIndex,center+1,"Wheel continues from dragged position")
 }
 function test_side_scroll_at_opening_label(){
  picker.sidePicker=true;wait(30)
  mouseWheel(picker,picker.width/2,picker.height/2,0,-120)
  compare(findChild(picker,"exit-country-wheel").currentIndex,1)
  compare(test.leaked,0)
 }
 function test_open_at_middle(){
  picker.country="40";picker.open();wait(200)
  var wheel=findChild(picker,"exit-country-wheel")
  compare(wheel.currentIndex,40)
  mouseWheel(wheel,wheel.width/2,wheel.height/2,0,-120)
  compare(wheel.currentIndex,41);compare(test.leaked,0)
 }
}
