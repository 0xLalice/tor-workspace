import ".."
import QtQuick
import QtQuick.Controls
OverlayPanel {
 id:root;objectName:"speed-comparison"
 property bool torRunning:false
 property bool routingReady:true
 property var measurement:({})
 property bool requested:false
 property bool accepting:false
 readonly property bool running:requested||!!measurement.running
 readonly property var torResult:measurement.tor||({})
 readonly property var circuitPaths:torResult.paths||[]
 readonly property bool conflux:torResult.multipath===true&&circuitPaths.length>1
 // Only Tor's Conflux attribution establishes that these paths share an exit.
 readonly property bool joinedPair:conflux&&torResult.sharedExitConfirmed===true&&circuitPaths.length===2&&circuitPaths.every(function(path){
  var c=path.countries||[]
  return c.length===5&&c.slice(0,-1).every(code=>/^[A-Z]{2}$/.test(code))&&c[0]===circuitPaths[0].countries[0]&&c[3]===circuitPaths[0].countries[3]
 })
 function distanceText(path){
  if(path.roundTripKm>0)return "~"+Number(path.roundTripKm).toLocaleString(Qt.locale(),"f",0)+" km return"
  return path.sameCountry?"Same country":""
 }
 function cancel(){accepting=false;requested=false;measurement=Object.assign({},measurement,{running:false,error:"Comparison cancelled."});cancelRequested()}
 function circuitText(path){
  var countries=path.countries||[]
  if(countries.length<3)return ""
  var relays=countries.slice(1,-1)
  if(relays.some(c=>!c||c==="?"))return ""
  var route="Circuit: "+countries.filter(c=>/^[A-Z]{2}$/.test(c)).join(" → ")
  var distance=distanceText(path)
  return route+(distance?" · "+distance:"")
 }
 signal startRequested()
 signal cancelRequested()
 function receive(value){if(accepting){requested=false;measurement=value;if(!value.running)accepting=false}}
 function start(){if(running||!torRunning||!routingReady)return;accepting=true;requested=true;measurement={};startRequested()}
 width:Math.min(344,parent.width-24);height:Math.min(body.implicitHeight+2*padding,parent.height-24)
 x:(parent.width-width)/2;y:(parent.height-height)/2
 closePolicy:Popup.CloseOnEscape
 onAboutToShow:{measurement={};requested=false;accepting=false}
 onOpened:header.closeControl.forceActiveFocus()
 Timer {interval:250;running:root.opened;onTriggered:header.closeControl.forceActiveFocus()}
 onAboutToHide:{accepting=false;requested=false;cancelRequested()}
 onTorRunningChanged:if(!torRunning&&running){cancelRequested();requested=false;measurement={running:false,error:"Tor disconnected. Comparison cancelled."};accepting=false}
 component Copy:Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);wrapMode:Text.WordWrap}
 contentItem:ScrollView {
  clip:true;contentWidth:availableWidth
  OverlayBody {
   id:body;width:parent.width
   OverlayHeader {id:header;title:"Speed test";closeName:"speed-close";ink:root.ink;accent:root.accent;onClosed:root.close()}
   Copy {objectName:"speed-privacy-disclosure";width:parent.width;text:"⚠ Running both tests could link your real IP to your Tor activity."}
   Row {
    width:parent.width;spacing:8
    Repeater {
     model:["direct","tor"]
     Rectangle {
      required property string modelData
      readonly property var value:root.measurement[modelData]||({status:"waiting"})
      width:(parent.width-8)/2;height:metrics.implicitHeight+24;radius:ThemeDesign.radius(8);color:Qt.alpha(root.accent,.06);border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.2))
      Column {
       id:metrics;x:10;y:12;width:parent.width-20;spacing:10
       Copy {width:parent.width;font.bold:true;text:modelData==="direct"?"Direct internet · Fast.com":"Through Tor · Cloudflare"}
       Copy {objectName:"speed-result-"+modelData;width:parent.width;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(18);text:value.status==="complete"?Number(value.mbps).toFixed(2)+" Mbps":"Pending"}
       Copy {width:parent.width;text:value.status==="complete"?"Time to first byte: "+(Number.isFinite(value.ttfb)?Math.round(value.ttfb)+" ms":"Unavailable"):value.status==="running"?"Downloading · "+Number((value.bytes||0)/1048576).toFixed(1)+" MiB\n"+Math.floor(value.elapsed||0)+" / 30 s":value.message||"Waiting"}
       Rectangle {
        width:parent.width;height:4;radius:ThemeDesign.radius(2);color:Qt.alpha(root.ink,.12);visible:value.status==="complete"
        Rectangle {height:parent.height;radius:ThemeDesign.radius(2);color:root.accent;width:parent.width*(value.mbps||0)/Math.max(root.measurement.direct&&root.measurement.direct.mbps||0,root.measurement.tor&&root.measurement.tor.mbps||0,0.001)}
       }
      }
     }
    }
   }
   Column {
    objectName:"speed-routes";width:parent.width;spacing:6
    visible:root.conflux||root.circuitPaths.some(path=>!!root.circuitText(path))
    Item {
     id:joinedDiagram;objectName:"speed-joined-routes"
     width:Math.min(208,parent.width);height:58;anchors.horizontalCenter:parent.horizontalCenter
     visible:root.joinedPair
     readonly property real guardX:Math.round(width*.3173)
     readonly property real middleX:Math.round(width*.5288)
     readonly property real exitX:width-48
     Canvas {
      anchors.fill:parent
      property color lineColor:root.accent
      onLineColorChanged:requestPaint()
      onWidthChanged:requestPaint()
      onVisibleChanged:if(visible)requestPaint()
      onPaint:{
       var c=getContext("2d");c.reset();c.strokeStyle=lineColor;c.lineWidth=1;c.lineCap="round";c.lineJoin="round"
       function line(points,arrow){
        c.beginPath();c.moveTo(points[0][0],points[0][1])
        for(var i=1;i<points.length;i++)c.lineTo(points[i][0],points[i][1])
        c.stroke()
        if(arrow){
         var end=points[points.length-1],prev=points[points.length-2],a=Math.atan2(end[1]-prev[1],end[0]-prev[0])
         c.beginPath();c.moveTo(end[0]-4*Math.cos(a-.55),end[1]-4*Math.sin(a-.55));c.lineTo(end[0],end[1]);c.lineTo(end[0]-4*Math.cos(a+.55),end[1]-4*Math.sin(a+.55));c.stroke()
        }
       }
       var g=joinedDiagram.guardX,m=joinedDiagram.middleX,e=joinedDiagram.exitX
       line([[34,30],[g-12,12]],true);line([[34,30],[g-12,48]],true)
       line([[g+12,12],[m-12,12]],true);line([[g+12,48],[m-12,48]],true)
       line([[m+12,12],[e-16,30],[m+12,48]],false)
       line([[e-16,30],[e-7,30]],true)
      }
     }
     Copy {objectName:"speed-shared-client";text:root.joinedPair?root.circuitPaths[0].countries[0]:"";x:14;y:24;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
     Repeater {
      model:root.joinedPair?root.circuitPaths:[]
      Item {
       required property var modelData
       required property int index
       width:joinedDiagram.width;height:36;y:index*36
       Copy {objectName:"speed-guard-"+index;text:modelData.countries[1];x:joinedDiagram.guardX-width/2;y:6;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
       Copy {objectName:"speed-middle-"+index;text:modelData.countries[2];x:joinedDiagram.middleX-width/2;y:6;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
      }
     }
     Copy {objectName:"speed-shared-exit";text:root.joinedPair?root.circuitPaths[0].countries[3]:"";x:joinedDiagram.exitX;y:24;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
     Copy {text:"Exit";x:joinedDiagram.exitX;y:38;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);opacity:ThemeDesign.textOpacity(.7)}
    }
    Column {
     width:joinedDiagram.width;anchors.horizontalCenter:parent.horizontalCenter;spacing:4
     visible:root.joinedPair&&root.circuitPaths.some(path=>!!root.distanceText(path))
     Repeater {
      model:root.joinedPair?root.circuitPaths:[]
      Row {
       required property var modelData
       required property int index
       objectName:"speed-distance-row-"+index;width:parent.width
       visible:!!distance.text
       Copy {objectName:"speed-distance-label-"+index;text:"Circuit "+(index+1)+" total";width:84;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);opacity:ThemeDesign.textOpacity(.7)}
       Copy {id:distance;objectName:"speed-branch-distance-"+index;text:root.distanceText(modelData);width:parent.width-84;horizontalAlignment:Text.AlignRight;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);opacity:ThemeDesign.textOpacity(.7)}
      }
     }
    }
    Repeater {
     model:root.joinedPair?[]:root.circuitPaths
     Copy {
      required property var modelData
      required property int index
      objectName:"speed-circuit-"+index;width:parent.width;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);visible:!!text
      text:root.circuitText(modelData)
     }
    }
    Copy {objectName:"speed-conflux-explanation";width:parent.width;visible:root.conflux;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);opacity:ThemeDesign.textOpacity(.7);text:root.torResult.sharedExitConfirmed===true?(root.circuitPaths.length===2?"Conflux: two paths share one exit to improve speed.":"Conflux: linked paths share one exit to improve speed."):"Conflux: Tor attributed these linked paths to the test stream."}
   }
   Copy {width:parent.width;visible:!!root.measurement.error;text:root.measurement.error||"";color:root.accent}
   Copy {width:parent.width;visible:!root.torRunning;text:"Connect Tor to start."}
   Copy {width:parent.width;visible:root.torRunning&&!root.routingReady;text:"Waiting for a verified Tor circuit…"}
   ActionCardRow {
    ActionCard {kind:root.running?"stop":"play";ink:root.ink;accent:root.accent;objectName:"speed-start";text:root.running?"Cancel":Object.keys(root.measurement).length?"Run again":"Compare";enabled:root.running||(root.torRunning&&root.routingReady);onClicked:{if(root.running)root.cancel();else root.start()}}
   }
  }
 }
}
