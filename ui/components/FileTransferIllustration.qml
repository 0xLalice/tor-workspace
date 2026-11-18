import ".."
import QtQuick

Item {
 id:root;objectName:"file-transfer-illustration"
 property bool showing:false
 property bool reducedMotion:false
 property color accent:ThemeColors.color("accent")
 property color ink:ThemeColors.color("uiText")
 property color surface:ThemeColors.color("background")
 property real progress:0
 readonly property bool complete:progress>=1
 readonly property bool recipientHasFile:progress>=.96
 readonly property real travel:Math.max(0,Math.min(1,(progress-.24)/.72))
 function node(side,index){var pts=[[.16,.77],[.20,.47],[.35,.25],[.5,.18]];var p=pts[index];return Qt.point((side===0?p[0]:1-p[0])*width,p[1]*height)}
 function position(side,t){var leg=Math.min(2,Math.floor(t*3)),u=t*3-leg,a=node(side,leg),b=node(side,leg+1);return Qt.point(a.x+(b.x-a.x)*u,a.y+(b.y-a.y)*u)}
 readonly property point client:visible?(node(0,0)):Qt.point(0,0)
 readonly property point recipient:visible?(node(1,0)):Qt.point(0,0)
 readonly property point rendezvous:visible?(node(0,3)):Qt.point(0,0)
 readonly property point documentPosition:visible?(travel<.5?position(0,travel*2):position(1,(1-travel)*2)):Qt.point(0,0)
 opacity:showing?1:0
 visible:showing||opacity>0
 Behavior on opacity {NumberAnimation {duration:root.reducedMotion?0:180}}
 onShowingChanged:{animation.stop();if(showing){progress=reducedMotion?1:0;if(!reducedMotion)animation.restart()}}
 onReducedMotionChanged:if(reducedMotion&&showing){animation.stop();progress=1}
 NumberAnimation {id:animation;target:root;property:"progress";from:0;to:1;duration:5000}
 Canvas {
  id:drawing;objectName:"file-transfer-canvas";anchors.fill:parent
  onWidthChanged:if(visible)requestPaint()
  onHeightChanged:if(visible)requestPaint()
  onVisibleChanged:if(visible)requestPaint()
  Connections {
   target:root;enabled:drawing.visible
   function onProgressChanged(){drawing.requestPaint()}
   function onAccentChanged(){drawing.requestPaint()}
   function onInkChanged(){drawing.requestPaint()}
   function onSurfaceChanged(){drawing.requestPaint()}
  }
  function document(c,p,size,glow){
   c.save();c.translate(p.x-size*.35,p.y-size*.5)
   c.globalAlpha=1;c.shadowColor=root.ink;c.shadowBlur=ThemeDesign.definition.diagramGlow?(glow?12:3):0
   c.fillStyle=root.surface;c.strokeStyle=root.ink;c.lineWidth=1.7
   var w=size*.7,h=size,fold=size*.23
   c.beginPath();c.moveTo(0,0);c.lineTo(w-fold,0);c.lineTo(w,fold);c.lineTo(w,h);c.lineTo(0,h);c.closePath();c.fill();c.stroke()
   c.shadowBlur=0;c.beginPath();c.moveTo(w-fold,0);c.lineTo(w-fold,fold);c.lineTo(w,fold);c.stroke()
   c.lineWidth=1.2
   for(var i=0;i<3;i++){var y=h*.48+i*h*.15;c.beginPath();c.moveTo(w*.2,y);c.lineTo(w*.78,y);c.stroke()}
   c.restore()
  }
  onPaint:{
   if(!visible)return // A previously queued paint can outlive the fade-out.
   var c=getContext("2d");c.reset();c.lineCap=ThemeDesign.definition.diagramRoundLines?"round":"butt"
   for(var side=0;side<2;side++){
    var color=side===0?root.accent:root.ink,amount=Math.max(0,Math.min(1,(root.progress-.04-side*.06)/.14))
    c.strokeStyle=color;c.lineWidth=ThemeDesign.definition.fileLineWidth;c.globalAlpha=ThemeDesign.definition.fileLineOpacity;c.beginPath()
    for(var i=0;i<=120*amount;i++){var p=root.position(side,i/120);if(i===0)c.moveTo(p.x,p.y);else c.lineTo(p.x,p.y)}c.stroke()
    if(ThemeDesign.definition.diagramDashed){c.setLineDash([3,5]);c.lineWidth=4;c.globalAlpha=.4;c.stroke();c.setLineDash([])}
    for(var j=1;j<3;j++){
     if(amount<j/3)continue
     var q=root.node(side,j);c.globalAlpha=1;c.fillStyle=root.surface;c.beginPath();c.arc(q.x,q.y,4,0,Math.PI*2);c.fill();c.strokeStyle=color;c.lineWidth=1;c.stroke()
    }
   }
   var rv=root.rendezvous
   c.globalAlpha=1;c.shadowColor=root.accent;c.shadowBlur=ThemeDesign.definition.diagramGlow?16:0;c.fillStyle=root.accent
   c.beginPath();c.arc(rv.x,rv.y,5,0,Math.PI*2);c.fill();c.shadowBlur=0
   c.strokeStyle=root.accent;c.globalAlpha=.35;c.beginPath();c.arc(rv.x,rv.y,10,0,Math.PI*2);c.stroke();c.globalAlpha=1
   // The source file stays put. Only the second document travels.
   document(c,root.client,24,false)
   if(root.progress>=.24)document(c,root.documentPosition,root.recipientHasFile?26:30,true)
   if(!root.recipientHasFile){var dst=root.recipient;c.globalAlpha=.5;c.strokeStyle=root.ink;c.beginPath();c.arc(dst.x,dst.y,4,0,Math.PI*2);c.stroke()}
  }
 }
 component Label:Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11);horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap}
 Label {x:Math.max(0,root.client.x-width/2);y:root.client.y+23;width:96;text:"Your computer"}
 Label {x:Math.min(root.width-width,root.recipient.x-width/2);y:root.recipient.y+23;width:96;text:"Recipient"}
 Label {x:root.rendezvous.x-width/2;y:root.rendezvous.y-30;width:96;text:"Rendezvous";color:root.accent}
 Accessible.role:Accessible.Graphic
 Accessible.name:"Illustration: a copy of your file travels through a rendezvous to an example recipient."
}
