import QtQuick
import QtTest
import "../../ui/shell/PanelSizing.js" as Sizing
TestCase {
 name:"PanelSizing"
 function test_fit_data(){return [
  {tag:"desktop",height:1080,availableWidth:1910,availableHeight:1037,width:460,wantedHeight:686},
  {tag:"vm",height:800,availableWidth:1270,availableHeight:757,width:402,wantedHeight:600},
  {tag:"vm-roomier-bar",height:800,availableWidth:1260,availableHeight:735,width:402,wantedHeight:600}
 ]}
 function test_fit(data){
  var size=Sizing.fit(data.height,data.availableWidth,data.availableHeight)
  compare(size.width,data.width);compare(size.height,data.wantedHeight)
 }
 function test_constrained_screen(){
  var size=Sizing.fit(480,240,300)
  verify(size.width<=240);verify(size.height<=300)
  verify(Math.abs(size.width/size.height-460/686)<.01)
 }
}
