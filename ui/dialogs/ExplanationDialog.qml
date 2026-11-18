import ".."
import QtQuick
import QtQuick.Controls

OverlayPanel {
 id:root;objectName:"footer-explanation"
 property bool presentationActive:true
 onPresentationActiveChanged:if(!presentationActive)close()
 property string topic:"onion-address"
 readonly property bool browser:topic==="browser-protections"
 readonly property bool snowflake:topic==="snowflake"
 readonly property bool onionLocation:topic==="onion-location"
 readonly property bool staticTopic:browser||snowflake||onionLocation
 readonly property bool peel:topic==="peel-layers"
 readonly property bool address:topic==="onion-address"
 property real progress:0
 property real packetPhase:0
 readonly property bool transfer:topic==="file-transfer"
 NumberAnimation on packetPhase {objectName:"rendezvous-packets";running:root.opened&&root.visible&&root.topic==="onion-meeting"&&root.progress>=1&&!root.reducedMotion;from:0;to:1;duration:2400;loops:Animation.Infinite}
 readonly property string exampleAddress:"pg6mmjiyjmcrsslvykfwnntlaru7p5svn6y2ymmju6nubxndf4pscryd.onion"
 width:Math.min(344,parent.width-24);height:Math.min(body.implicitHeight+2*padding,parent.height-24)
 x:(parent.width-width)/2;y:(parent.height-height)/2
 closePolicy:Popup.CloseOnEscape
 onOpened:{progress=0;if(reducedMotion)progress=1;else if(!peel&&!staticTopic&&!transfer)reveal.restart();header.closeControl.forceActiveFocus()}
 onAboutToHide:reveal.stop()
 onReducedMotionChanged:if(reducedMotion&&visible){reveal.stop();progress=1}
 NumberAnimation {id:reveal;target:root;property:"progress";from:0;to:1;duration:root.address?800:3000}
 // The shell primes focus just after opening its panel.
 Timer {interval:250;running:root.opened;onTriggered:header.closeControl.forceActiveFocus()}
 component Copy:Text {font.family:ThemeDesign.fontFamily;color:root.ink;font.pixelSize:ThemeDesign.px(11);wrapMode:Text.WordWrap}
 contentItem:ScrollView {
  id:explanationScroll;objectName:"explanation-scroll";clip:true;contentWidth:availableWidth
  OverlayBody {id:body;width:parent.width
  OverlayHeader {
   id:header;titleName:"explanation-title";closeName:"explanation-close";ink:root.ink;accent:root.accent;onClosed:root.close()
   title:root.onionLocation?"Onion alternative":root.snowflake?"Discover Snowflake":root.browser?"Browser privacy":root.transfer?"File transfer":root.peel?"Encryption layers":root.address?"Onion addresses":"Rendezvous"
   nextFocus:root.staticTopic?sourceLink:header.closeControl
   previousFocus:root.browser?securityLink:root.staticTopic?sourceLink:header.closeControl
  }
  Column {
   id:staticScroll;objectName:"static-explanation"
   width:parent.width;visible:root.staticTopic
   Column {
    id:staticCopy;width:parent.width;spacing:14
    Copy {objectName:"explanation-copy";width:parent.width;lineHeight:1.25;visible:!root.browser;text:root.onionLocation?"Participating sites offer an onion address for their website. Tor Browser lets you switch to it.":"Volunteers forward encrypted traffic to a Tor bridge, helping people connect when Tor is blocked."}
    Repeater {
     model:root.browser?["Fingerprinting: reduces identifying differences between browsers.","Site isolation: separates site data to limit cross-site tracking.","Canvas and fonts: restricts access used to identify your browser.","Security levels: lets you limit scripts and other web features."]:[]
     Copy {required property string modelData;width:parent.width;text:modelData;lineHeight:1.25}
    }
    Rectangle {
     visible:root.snowflake;width:parent.width;height:snowflakePath.implicitHeight+24
     radius:ThemeDesign.radius(8);color:Qt.alpha(root.accent,.07);border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.2))
     Copy {
      id:snowflakePath;objectName:"snowflake-path";anchors.centerIn:parent;width:parent.width-20
      lineHeight:1.4;color:root.accent
      text:"User → Volunteer → Tor bridge → Tor network"
     }
    }
    Copy {objectName:"snowflake-privacy";visible:root.snowflake;width:parent.width;lineHeight:1.25;text:"Volunteers aren’t exit relays and can’t read the browsing carried inside Tor."}
    OverlayAction {ink:root.ink;accent:root.accent;
     id:sourceLink;objectName:"explanation-source";text:root.onionLocation?"Proton’s official Tor page":root.snowflake?"Visit the Snowflake project":"Fingerprinting protections";width:Math.min(implicitWidth,parent.width)
     Accessible.name:text;flat:true
     onActiveFocusChanged:if(activeFocus)explanationScroll.contentItem.contentY=Math.max(0,Math.min(sourceLink.mapToItem(body,0,0).y+height-explanationScroll.availableHeight,explanationScroll.contentHeight-explanationScroll.availableHeight))
     KeyNavigation.tab:root.browser?securityLink:header.closeControl;KeyNavigation.backtab:header.closeControl
     readonly property string sourceUrl:root.onionLocation?"https://proton.me/tor":root.snowflake?"https://snowflake.torproject.org/":"https://support.torproject.org/tor-browser/features/fingerprinting-protections/"
     onClicked:Qt.openUrlExternally(sourceUrl)
     contentItem:Text {text:sourceLink.text;color:root.accent;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);wrapMode:Text.WordWrap}
    }
    OverlayAction {ink:root.ink;accent:root.accent;
     id:securityLink;objectName:"browser-security-source";visible:root.browser;text:"Security levels";flat:true
     KeyNavigation.tab:header.closeControl;KeyNavigation.backtab:sourceLink
     onClicked:Qt.openUrlExternally("https://support.torproject.org/tor-browser/features/security-levels/")
     contentItem:Text {text:securityLink.text;color:root.accent;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10)}
    }
   }
  }
  PeelLayersIllustration {width:parent.width;visible:root.peel;active:root.opened&&root.visible&&root.peel;reducedMotion:root.reducedMotion;ink:root.ink;surface:root.surface}
  FileTransferIllustration {width:parent.width;height:210;visible:root.transfer;showing:root.opened&&root.visible&&root.transfer;reducedMotion:root.reducedMotion;ink:root.ink;accent:root.accent;surface:root.surface}
  OverlayFooter {width:parent.width;visible:root.transfer;ink:root.ink;text:"Your file travels through a meeting point inside Tor."}
  Column {
   width:parent.width;spacing:16;visible:root.address
   Copy {width:parent.width;lineHeight:1.25;text:"An onion address contains the service’s public key. Tor verifies that the service holds the matching private key."}
   Copy {
    objectName:"example-address";width:parent.width
    text:root.exampleAddress;textFormat:Text.PlainText
    font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);lineHeight:1.3
    wrapMode:Text.WrapAnywhere;color:root.accent
   }
  }
  Column {
   width:parent.width;spacing:8;visible:root.topic==="onion-meeting"
   Copy {width:parent.width;text:"Both sides communicate without revealing their IP addresses to each other."}
   Item {
    id:diagram;objectName:"meeting-diagram";width:parent.width;height:220
    readonly property color clientColor:root.accent
    readonly property color serviceColor:root.ink
    function node(side,index){
     var pts=[Qt.point(.06,.18),Qt.point(.30,.18),Qt.point(.57,.29),Qt.point(.88,.5)]
     var p=pts[index];return Qt.point(p.x*width,(side===0?p.y:1-p.y)*height)
    }
    // Three straight circuit legs, softened around the intermediate relays.
    function point(side,t){
     var scaled=Math.min(t,1)*3,leg=Math.min(2,Math.floor(scaled)),u=scaled-leg
     var a=node(side,leg),b=node(side,leg+1)
     return Qt.point(a.x+(b.x-a.x)*u,a.y+(b.y-a.y)*u)
    }
    function built(side){return Math.max(0,Math.min(1,(root.progress-.05-side*.18)/.5))}
    Canvas {
     id:routes;objectName:"explanation-routes";anchors.fill:parent
     Connections {target:root;enabled:routes.visible;function onProgressChanged(){routes.requestPaint()}function onPacketPhaseChanged(){routes.requestPaint()}function onAccentChanged(){routes.requestPaint()}function onInkChanged(){routes.requestPaint()}}
     onWidthChanged:if(visible)requestPaint()
     onVisibleChanged:if(visible)requestPaint()
     onPaint:{
      if(!visible)return
      var c=getContext("2d");c.reset();c.lineCap=ThemeDesign.definition.diagramRoundLines?"round":"butt";c.lineJoin="round"
      for(var side=0;side<2;side++){
       var color=side===0?diagram.clientColor:diagram.serviceColor,amount=diagram.built(side)
       c.strokeStyle=color;c.globalAlpha=ThemeDesign.definition.diagramHaloOpacity;c.lineWidth=ThemeDesign.definition.diagramHaloWidth;c.beginPath()
       for(var i=0;i<=90*amount;i++){var p=diagram.point(side,i/90);if(i===0)c.moveTo(p.x,p.y);else c.lineTo(p.x,p.y)}c.stroke()
       c.globalAlpha=ThemeDesign.definition.diagramLineOpacity;c.lineWidth=ThemeDesign.definition.diagramLineWidth;c.stroke()
       if(ThemeDesign.definition.diagramDashed){c.setLineDash([4,5]);c.lineWidth=1;c.stroke();c.setLineDash([])}
       for(var j=1;j<=2;j++){
        if(amount<j/3)continue
        var q=diagram.node(side,j);c.globalAlpha=1;c.fillStyle=root.surface;c.beginPath();c.arc(q.x,q.y,5,0,Math.PI*2);c.fill();c.strokeStyle=color;c.lineWidth=1;c.stroke()
        c.globalAlpha=.7;c.fillStyle=color;c.beginPath();c.arc(q.x,q.y,1.5,0,Math.PI*2);c.fill()
       }
      }
      var r=diagram.node(0,3);c.globalAlpha=1;c.fillStyle=root.surface;c.beginPath();c.arc(r.x,r.y,11,0,Math.PI*2);c.fill()
      c.lineWidth=1.5;c.strokeStyle=diagram.clientColor;c.beginPath();c.arc(r.x,r.y,11,Math.PI,2*Math.PI);c.stroke()
      c.strokeStyle=diagram.serviceColor;c.beginPath();c.arc(r.x,r.y,11,0,Math.PI);c.stroke()
      c.fillStyle=root.ink;c.beginPath();c.arc(r.x,r.y,3,0,Math.PI*2);c.fill()
      if(root.progress>=1&&!root.reducedMotion){
       for(var direction=0;direction<2;direction++){
        var travel=(root.packetPhase+direction*.5)%1
        var side=travel<.5?direction:1-direction
        var pulse=diagram.point(side,travel<.5?travel*2:2-travel*2)
        c.fillStyle=direction===0?diagram.clientColor:diagram.serviceColor;c.shadowColor=c.fillStyle;c.shadowBlur=ThemeDesign.definition.diagramGlow?8:0;c.beginPath();c.arc(pulse.x,pulse.y,3,0,Math.PI*2);c.fill()
       }
      }
     }
    }
    Repeater {
     model:2
     Item {
      id:circuit;required property int index
      readonly property color circuitColor:index===0?diagram.clientColor:diagram.serviceColor
      anchors.fill:parent
      Copy {x:0;y:circuit.index===0?0:parent.height-14;text:circuit.index===0?"Your circuit":"Service circuit";font.pixelSize:ThemeDesign.px(11);color:circuit.circuitColor;opacity:ThemeDesign.textOpacity(.85)}
      Repeater {
       model:2
       Copy {
        required property int index
        readonly property point pos:diagram.node(circuit.index,index+1)
        x:pos.x-width/2;y:pos.y+(circuit.index===0?-25:14)
        text:index===0?"Guard":"Middle";font.pixelSize:ThemeDesign.px(10);opacity:diagram.built(circuit.index)>(index+1)/3?ThemeDesign.textOpacity(.5):0
       }
      }
      Item {
       x:diagram.node(circuit.index,0).x-9;y:diagram.node(circuit.index,0).y-10;width:18;height:20
       Rectangle {visible:circuit.index===0;width:16;height:11;radius:ThemeDesign.radius(1);anchors.centerIn:parent;color:root.surface;border.color:circuit.circuitColor;border.width:1
        Rectangle {width:8;height:1;anchors.top:parent.bottom;anchors.topMargin:3;anchors.horizontalCenter:parent.horizontalCenter;color:circuit.circuitColor}
       }
       OnionEmblem {visible:circuit.index===1;anchors.fill:parent;accent:circuit.circuitColor;secondary:circuit.circuitColor}
      }
     }
    }
    Copy {anchors.right:parent.right;y:diagram.height/2+23;text:"Rendezvous";font.pixelSize:ThemeDesign.px(11);opacity:ThemeDesign.textOpacity(.8)}
   }
  }
 }
}
}
