import ".."
import QtQuick
import QtQuick.Controls
import "../theme/EffectSettings.js" as Effects
import "ActionCatalog.js" as Actions
import "../theme/DesignDefinitions.js" as Presentation

Item {
 id:root
 property var updateStatus:({})
 property bool updateBusy:false
 property string updateFeedback:""
 readonly property bool updateOpened:updateDialog.opened
 signal updateRequested()
 signal updateCheckRequested()
 function openUpdate(){openOverlay(updateDialog);root.updateCheckRequested()}
 UpdateDialog {
  id:updateDialog;reducedMotion:root.reducedMotion;ink:root.ink;accent:root.accent;surface:root.background
  update:root.updateStatus;busy:root.updateBusy;feedback:root.updateFeedback
  onUpdateRequested:root.updateRequested()
  onCheckRequested:root.updateCheckRequested()
 }
 property bool installationReady:true
 property bool installationBusy:false
 property string installationFeedback:""
 readonly property bool installationOpened:installationDialog.opened
 signal installationRequested()
 signal installationManualRequested()
 function openInstallation(){if(!installationReady)openOverlay(installationDialog)}
 InstallationDialog {
  id:installationDialog;reducedMotion:root.reducedMotion;ink:root.ink;accent:root.accent;surface:root.background
  busy:root.installationBusy;feedback:root.installationFeedback
  onInstallRequested:root.installationRequested()
  onManualRequested:root.installationManualRequested()
 }
 onInstallationReadyChanged:if(installationReady)installationDialog.close()
 Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
  id:installationButton;objectName:"installation-button";z:20
  visible:!root.installationReady
  anchors.centerIn:parent
  text:"Installation";padding:12;hoverEnabled:true
  onClicked:root.openInstallation()
  background:Rectangle {radius:ThemeDesign.radius(5);color:installationButton.hovered?Qt.tint(root.background,Qt.alpha(root.accent,.15)):Qt.alpha(root.background,.92);border.width:1;border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.35))}
  contentItem:Text {text:installationButton.text;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
 }
 property bool diagnosticsEnabled:false
 property bool diagnosticsHud:true
 property alias performance:performanceMonitor
 PerformanceMonitor {
  id:performanceMonitor;z:100;anchors.right:parent.right;anchors.bottom:parent.bottom
  monitoring:root.diagnosticsEnabled;panelActive:root.active;showHud:root.diagnosticsHud
  ink:root.ink;surface:root.background
  context:({appearance:root.appearance,interface:root.interfaceSettings,effects:root.effectSettings,
    torRunning:root.torRunning,state:root.state,routePoints:root.route.length,
    zoom:globeView.zoomLevel,panelWidth:root.width,panelHeight:root.height,
    circuitRenderer:globeView.nativeCircuitRendering?"native":"inactive"})
 }
 property alias antipodeController:antipode
 readonly property bool antipodeShown:antipode.showing
 signal antipodeRequested(bool refresh,int revision)
 function openAntipode(){closeOverlays(antipode);antipode.open(false);root.forceActiveFocus()}
 AntipodeController {
  id:antipode;globe:globeView;origin:root.localOrigin;active:root.active;reducedMotion:root.reducedMotion
  onRequested:(refresh,revision)=>root.antipodeRequested(refresh,revision)
  onClosed:if(root.active)circuitInterface.restoreNoteFocus()
 }
 AntipodePanel {anchors.fill:parent;z:26;controller:antipode;ink:root.ink;accent:root.accent;surface:root.background}

 TapHandler {
  gesturePolicy:TapHandler.DragThreshold
  onTapped:{
   if(!root.relayOpened)return
   var p=point.position
   if(p.x>=relayCard.x&&p.x<=relayCard.x+relayCard.width&&p.y>=relayCard.y&&p.y<=relayCard.y+relayCard.height)return
   var g=globeView.mapFromItem(root,p.x,p.y)
   if(!globeView.relayAt(g.x,g.y))root.closeRelay()
  }
 }
 readonly property int relayVariant:interfaceSettings.relayInspector||0
 onRelayVariantChanged:if(selectedHop){if(relayVariant)globeView.focusRelay(selectedHop,relayVariant);else globeView.leaveRelay()}
 readonly property var relayAnchor:{
  // Read camera properties here so the tether follows every projected frame.
  if(!selectedHop||!root.visible||!root.active)return null
  var pose=[globeView.longitude,globeView.latitude,globeView.sceneRoll,globeView.zoomLevel]
  var p=globeView.relayAnchor(selectedHop.fingerprint)
  return p?globeView.mapToItem(root,p.x,p.y):null
 }
 property var selectedHop:null
 property var relayInfo:({})
 property int relayRevision:0
 readonly property bool relayOpened:selectedHop!==null
 signal relayInfoRequested(string fingerprint,int revision)
 function inspectRelay(hop){
  selectedHop=hop;if(relayVariant)globeView.focusRelay(hop,relayVariant);relayInfo={fingerprint:hop.fingerprint,loading:true};relayRevision++
  relayCard.expanded=false;relayCard.forceActiveFocus();relayInfoRequested(hop.fingerprint,relayRevision)
 }
 function receiveRelayInfo(value,revision){if(selectedHop&&revision===relayRevision&&value.fingerprint===selectedHop.fingerprint)relayInfo=value}
 function closeRelay(){if(!selectedHop)return;globeView.restoreRelayFocus();globeView.leaveRelay();selectedHop=null;relayRevision++}
 onCircuitIdChanged:closeRelay()
 onRouteChanged:{if(selectedHop&&!route.some(h=>h.fingerprint===selectedHop.fingerprint))closeRelay()}
 onCircuitsShownChanged:if(circuitsShown){closeRelay();circuitRemaining=10000;root.forceActiveFocus()}
 onFileShownChanged:if(fileShown)closeRelay()
 RelayCard {
  id:relayCard;visible:root.relayOpened;z:30
  variant:root.relayVariant
  width:root.relayVariant?Math.min(parent.width-40,root.relayVariant===2?310:340):parent.width-32
  x:root.relayVariant===2?parent.width-width-20:root.relayVariant===3?(parent.width-width)/2:root.relayVariant===1?20:16
  y:root.relayVariant?Math.max(86,Math.min(parent.height-height-64,parent.height*.56)):Math.max(64,parent.height-height-68)
  hop:root.selectedHop||({});info:root.relayInfo;ink:root.ink;accent:root.accent;surface:root.background
  onClosed:root.closeRelay()
 }
 Canvas {
  id:relayTether;objectName:"relay-tether";anchors.fill:parent;z:29
  visible:root.relayOpened&&root.relayVariant>0&&root.relayAnchor!==null
  property var anchor:root.relayAnchor
  property real cardY:relayCard.y
  property real cardX:relayCard.x
  property real cardWidth:relayCard.width
  onAnchorChanged:if(visible)requestPaint()
  onCardYChanged:if(visible)requestPaint()
  onCardXChanged:if(visible)requestPaint()
  onCardWidthChanged:if(visible)requestPaint()
  onVisibleChanged:if(visible)requestPaint()
  onPaint:{if(!visible)return;var c=getContext("2d");c.reset();if(!anchor)return
   var endX=root.relayVariant===2?cardX+22:root.relayVariant===3?cardX+cardWidth/2:cardX+cardWidth-24
   c.strokeStyle=Qt.alpha(root.accent,.7);c.lineWidth=1;c.beginPath();c.moveTo(anchor.x,anchor.y)
   if(root.relayVariant===2)c.lineTo(endX,cardY)
   else {c.lineTo(endX,cardY-20);c.lineTo(endX,cardY)}c.stroke()

  }
 }
 property real cornerRadius:18
 // Every entry point, including IPC and picker returns, selects one overlay.
 function closeOverlays(except) {
  var overlays=[updateDialog,installationDialog,shareDialog,chatDialog,hostDialog,
                optionsChooser,themeChooser,darknetDialog,explanation,speedDialog]
  for(var overlay of overlays)if(overlay!==except)overlay.close()
  if(except!==antipode&&antipode.showing)antipode.close()
  closeRelay()
  circuitsShown=false
  footer.countryPicker.opened=false
 }
 function openOverlay(overlay) {
  closeOverlays(overlay)
  overlay.open()
 }
 function closePresentation() {
  closeOverlays(null)
  exitNetworkClock=24
  // Dismiss presentation only; running services and the circuit remain intact.
 }
 property var classicInterfaceSettings:({layout:3,uiScale:1.15})
 onInterfaceSettingsChanged:{var next=interfaceSettings.design||"original";if(next!==ThemeDesign.design)closePresentation();if(Presentation.resolve(next,interfaceSettings.style).actionLayout==="flow")classicInterfaceSettings=interfaceSettings;ThemeDesign.apply(interfaceSettings)}
 property int appearance:0
 property var effectSettings:null
 property bool showLaunchControls:false
 property bool showPowerControls:false
 property var interfaceSettings:Effects.interfaceConfig({})
 readonly property real uiScale:interfaceSettings.uiScale||1
 readonly property real headerScale:ThemeDesign.definition.headerScale
 readonly property color cardDetail:interfaceSettings.cardStyle===0?root.ink:ThemeColors.color("accent")
 readonly property bool orbitLayout:ThemeDesign.definition.actionLayout==="arc"
 readonly property real layoutMix:ThemeColors.orbitMix
 property int interfaceVariation:orbitLayout?1:interfaceSettings.layout
 property bool showCircuitInterface:interfaceVariation===0
 function nextPhrase(){if(root.torRunning&&root.active&&!root.darknetOpened&&!root.antipodeShown&&root.interfaceVariation>0&&!root.speedOpened&&!root.explanationOpened&&!root.circuitsShown&&!root.fileShown&&!root.relayOpened)circuitInterface.nextPhrase()}
 property var shareState:({api:2,shares:[],readyCount:0})
 readonly property bool shareOpened:shareDialog.opened
 property bool shareSubmitting:false
 property var shareSelection:[]
 property bool shareChoosing:false
 property var pendingShareSelection:[]
 function submitPendingShare(){
  if(!networkEnabled||!pendingShareSelection.length)return
  var files=pendingShareSelection;pendingShareSelection=[]
  root.shareStartRequested(files,{background:root.background.toString(),foreground:root.ink.toString(),accent:root.accent.toString()})
 }
 onShareSelectionChanged:{if(shareChoosing){shareChoosing=false;if(!torAvailable)return;pendingShareSelection=shareSelection;openOverlay(shareDialog);submitPendingShare()}}
 signal shareResumeChanged(bool enabled)
 signal shareChooseRequested()
 signal shareStartRequested(var files,var colors)
 signal shareStopRequested(string id)
 signal shareRetryRequested(string id)
 signal shareDismissRequested(string id)
 signal shareStatusRequested()
 function openShare(){if(networkEnabled)openOverlay(shareDialog)}
 ShareDialog {
  id:shareDialog;settings:root.interfaceSettings.fileSharing||({});reducedMotion:root.reducedMotion;shareState:root.shareState;submitting:root.shareSubmitting;torRunning:root.torRunning;routingReady:root.networkEnabled;waiting:root.pendingShareSelection.length>0
  ink:root.ink;accent:root.accent;surface:root.background
  onAboutToHide:root.pendingShareSelection=[]
  onChooseRequested:{root.shareChoosing=true;root.shareChooseRequested()}
  onStopRequested:id=>root.shareStopRequested(id)
  onRetryRequested:id=>root.shareRetryRequested(id)
  onDismissRequested:id=>root.shareDismissRequested(id)
  onStatusRequested:root.shareStatusRequested()
 }
 Timer {interval:1500;repeat:true;triggeredOnStart:true;running:root.active;onTriggered:root.shareStatusRequested()}
 property var chatState:({state:"idle",url:""})
 readonly property bool chatOpened:chatDialog.opened
 readonly property bool chatReady:chatState.state==="ready"&&!!chatState.url
 readonly property string chatActivity:chatReady?"Chat active":chatState.state==="starting"||chatState.state==="preparing"?"Chat starting…":chatState.state==="stopping"?"Chat stopping…":""
 signal chatStartRequested(var colors)
 signal chatStopRequested()
 signal chatOpenRequested()
 signal chatStatusRequested()
 function openChat(){if(networkEnabled)openOverlay(chatDialog)}
 ChatDialog {
  id:chatDialog;reducedMotion:root.reducedMotion;room:root.chatState;torRunning:root.torRunning
  ink:root.ink;accent:root.accent;surface:root.background
  onStartRequested:root.chatStartRequested({background:root.background.toString(),foreground:root.ink.toString(),accent:root.accent.toString()})
  onStopRequested:root.chatStopRequested()
  onOpenRequested:root.chatOpenRequested()
  onStatusRequested:root.chatStatusRequested()
 }
 Timer {interval:1500;repeat:true;triggeredOnStart:true;running:root.active;onTriggered:root.chatStatusRequested()}
 readonly property bool darknetOpened:darknetDialog.opened
 signal launchDarknet()
 function openDarknet(){if(networkEnabled)openOverlay(darknetDialog)}
 DarknetDialog {
  id:darknetDialog;reducedMotion:root.reducedMotion;torRunning:root.torRunning&&!root.powerBusy
  ink:root.ink;accent:root.accent;surface:root.background
  onLaunchRequested:root.launchDarknet()
 }
 property var hostState:({state:"stopped",source:{mode:"folder",folder:"",port:3000},url:""})
 readonly property bool hostOpened:hostDialog.opened
 readonly property bool hostReady:hostState.state==="ready"
 signal hostStartRequested(var source)
 signal hostStopRequested()
 signal hostOpenRequested()
 signal hostStatusRequested()
 signal hostChooseRequested()
 function hostActionAvailable(mode){return !["starting","ready","stopping"].includes(hostState.state)||(hostState.source||{}).mode===mode}
 function openHost(mode){
  var selected=mode||((hostState.source||{}).mode)||"folder"
  if(networkEnabled&&hostActionAvailable(selected)){hostDialog.mode=selected;openOverlay(hostDialog)}
 }
 function openWebsite(){openHost("folder")}
 function openApp(){openHost("app")}
 function selectHostFolder(path){if(torAvailable){closeOverlays(hostDialog);hostDialog.selectFolder(path)}}
 HostDialog {
  id:hostDialog;reducedMotion:root.reducedMotion;host:root.hostState;torRunning:root.torRunning;routingReady:root.networkEnabled
  ink:root.ink;accent:root.accent;surface:root.background
  onStartRequested:source=>root.hostStartRequested(source)
  onStopRequested:root.hostStopRequested()
  onOpenRequested:root.hostOpenRequested()
  onStatusRequested:root.hostStatusRequested()
  onChooseRequested:root.hostChooseRequested()
 }
 Timer {interval:1500;repeat:true;triggeredOnStart:true;running:root.active;onTriggered:root.hostStatusRequested()}
 readonly property bool optionsOpened:optionsChooser.opened
 readonly property bool themesOpened:themeChooser.opened
 function openOptions(){openOverlay(optionsChooser)}
 readonly property bool explanationOpened:explanation.visible
 readonly property bool reducedMotion:interfaceSettings.reducedMotion===true
 ExplanationDialog {
  id:explanation;presentationActive:root.active&&root.visible;ink:root.ink;accent:root.accent;surface:root.background;reducedMotion:root.reducedMotion
  onClosed:if(root.active)circuitInterface.restoreNoteFocus()
 }
 property var localOrigin:({})
 property var localCircuits:({available:false,count:null,circuits:[]})
 property bool circuitsShown:false
 property real circuitRemaining:10000
 readonly property bool circuitHover:globeView.circuitHovered
 FrameAnimation {
  objectName:"built-circuit-countdown"
  running:root.circuitsShown&&root.active&&root.visible&&!root.circuitHover&&!root.explanationOpened&&!root.speedOpened&&!root.optionsOpened&&!root.themesOpened&&!root.shareOpened&&!root.chatOpened&&!root.hostOpened&&!root.darknetOpened&&!root.installationOpened&&!root.updateOpened
  onTriggered:{root.circuitRemaining=Math.max(0,root.circuitRemaining-frameTime*1000);if(root.circuitRemaining<=0)root.closeCircuits(false)}
 }
 readonly property bool fileShown:explanation.visible&&explanation.topic==="file-transfer"
 readonly property bool sharingActive:(shareState.readyCount||0)>0
 property double circuitClock:Date.now()/1000
 readonly property bool circuitsAvailable:torRunning&&localCircuits.available===true&&circuitClock-localCircuits.observedAt<10
 readonly property var builtCount:circuitsAvailable?localCircuits.count:null
 function closeCircuits(restoreFocus){circuitsShown=false;if(active&&restoreFocus!==false)circuitInterface.restoreNoteFocus()}
 Timer {interval:1000;repeat:true;running:root.active;onTriggered:root.circuitClock=Date.now()/1000}
 Keys.onEscapePressed:event=>{if(root.antipodeShown){antipode.close();event.accepted=true}else if(root.relayOpened){root.closeRelay();event.accepted=true}else if(root.fileShown){explanation.close();event.accepted=true}else if(root.circuitsShown){root.closeCircuits();event.accepted=true}else event.accepted=false}
 onTorRunningChanged:if(!torRunning){closeRelay();circuitsShown=false;explanation.close()}
 property bool torRunning:false
 property string originState:""
 property string connectionMessage:""
 Text {
  objectName:"origin-status"
  visible:!root.fileShown&&root.torRunning&&(root.state!=="ready"||!root.route.length&&(root.originState==="checking"||root.originState==="unavailable"))
  anchors.horizontalCenter:parent.horizontalCenter;y:64;z:12
  width:parent.width-32;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap
  text:root.state!=="ready"?(root.connectionMessage||"Waiting for a Tor circuit…"):root.originState==="checking"?"Locating your connection…":"Your location is unavailable"
  color:root.ink;opacity:ThemeDesign.textOpacity(.7);font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)
 }
 property bool powerBusy:false
 signal startTor()
 signal stopTor()
 property bool serviceAvailable:true
 readonly property bool networkEnabled:serviceAvailable&&installationReady&&(!showPowerControls||(torRunning&&!powerBusy))
 // A transient recheck preserves the picker result; stopping Tor cancels it.
 readonly property bool torAvailable:installationReady&&(!showPowerControls||(torRunning&&!powerBusy))
 readonly property var dashboardActions:{
  var context={networkEnabled:root.networkEnabled,chatActivity:root.chatActivity,
   active:{share:root.sharingActive,chat:root.chatReady,website:root.hostReady&&(root.hostState.source||{}).mode==="folder",app:root.hostReady&&(root.hostState.source||{}).mode==="app"},
   blocked:{website:!root.hostActionAvailable("folder"),app:!root.hostActionAvailable("app")}}
  var result={};Actions.entries.forEach(entry=>result[entry.kind]=Actions.resolve(entry,context));return result
 }
 function actionEnabled(kind){return !!dashboardActions[kind]&&dashboardActions[kind].enabled}

 onNetworkEnabledChanged:{if(networkEnabled)submitPendingShare();else{chatDialog.close();hostDialog.close();darknetDialog.close()}}
 onTorAvailableChanged:if(!torAvailable){shareChoosing=false;pendingShareSelection=[];shareDialog.close();chatDialog.close();hostDialog.close()}
 property var exitCountries:[{code:"",name:"Automatic"}]
 property string exitCountry:""
 signal speedStartRequested()
 signal speedCancelRequested()
 function receiveSpeed(value){speedDialog.receive(value)}
 readonly property bool speedOpened:speedDialog.visible
 SpeedCompareDialog {
  id:speedDialog;torRunning:root.torRunning;routingReady:root.networkEnabled;ink:root.ink;accent:root.accent;surface:root.background;reducedMotion:root.reducedMotion
  onStartRequested:root.speedStartRequested()
  onCancelRequested:root.speedCancelRequested()
  onClosed:if(root.active)circuitInterface.restoreNoteFocus()
 }
 property var onionEstimate:null
 property var exitNetwork:({points:[]})
 property bool exitNetworkLoading:false
 property string exitNetworkError:""
 property real exitNetworkClock:24
 readonly property bool exitNetworkPlaying:exitNetworkClock<24
 signal illuminateExitNodes()
 function playExitNetwork(){if(exitNetwork.points&&exitNetwork.points.length)exitNetworkClock=0}
 FrameAnimation {running:root.active&&root.visible&&!root.reducedMotion&&!root.antipodeShown&&root.exitNetworkPlaying;onTriggered:root.exitNetworkClock=Math.min(24,root.exitNetworkClock+Math.min(frameTime,.05))}
 property var availableThemes:[]
 property string currentThemeId:""
 signal themeChosen(string id)
 signal launchTerminal()
 signal launchBrowser()
 signal exitCountryChosen(string code)
 signal countryRestrictionChosen(string code)
 property var presetCamera:null
 function restorePresetCamera() {
  if(!presetCamera||(globeView.circuitOrbit&&globeView.cameraState.initialized))return
  globeView.longitude=presetCamera.longitude
  globeView.latitude=presetCamera.latitude
  globeView.viewRoll=presetCamera.viewRoll||0
  globeView.automaticRotation=!!presetCamera.automaticRotation
  globeView.rememberCamera()
 }
 onPresetCameraChanged:Qt.callLater(restorePresetCamera)

 signal effectsEdited(var settings)
 property color accent:ThemeColors.color("uiAccent")
 property color ink:ThemeColors.color("uiText")
 property color background:ThemeColors.color("background")
 property var route:[]
 property string transitionPreset:effectSettings&&effectSettings.transitionPreset||"ember"
 property string circuitId:""
 property string state:"starting"
 property bool busy:false
 property bool active:false
 property bool canChange:false
 property int cooldown:0
 property string statusDetail:""
 signal newCircuit()
 property alias globe:globeView
 function resetThemeCamera(){globeView.restartCamera()}
 function focusNextControl(direction){
  function focused(item){
   for(var child of item.children){var found=focused(child);if(found)return found}
   return item.activeFocus?item:null
  }
  var current=focused(root)
  if(!current&&root.orbitLayout&&orbitControls.focusFirst(direction<0))return
  var next=(current||root).nextItemInFocusChain(direction>=0)
  for(var i=0;i<200&&next;i++){
   if(next.visible&&next.enabled&&next.activeFocusOnTab){next.forceActiveFocus(Qt.TabFocusReason);return}
   next=next.nextItemInFocusChain(direction>=0)
  }
 }
 readonly property var colors:Effects.colors(effectSettings,appearance)
 readonly property var skyState:({time:sky.animationTime,phase:sky.motionTime,speed:(effectSettings||{}).voidSpeed,animating:sky.animating,layers:sky.effectLayerCount,weights:ThemeColors.voidWeights,travel:[sky.travel(0),sky.travel(2)]})
 VoidBackground {id:sky;active:root.active&&!root.reducedMotion;anchors.fill:parent;anchors.margins:-20;settings:root.effectSettings;globeRadius:globeView.screenRadius*ThemeColors.circuitMix;globeCenter:Qt.vector2d(globeView.x+globeView.width/2,globeView.y+globeView.height/2);radius:root.cornerRadius;z:-1 }
 Item {
  id:heading;width:parent.width;height:30;z:10
  OnionEmblem { id:emblem;objectName:"tor-header-logo";circuitReady:root.serviceAvailable&&root.torRunning&&!root.powerBusy;active:root.active;reducedMotion:root.reducedMotion;lightStyle:root.interfaceSettings.onionLight===undefined?1:root.interfaceSettings.onionLight;width:22*root.headerScale*1.15;height:width*1.2;anchors.verticalCenter:parent.verticalCenter;appearance:root.appearance;accent:root.accent;secondary:root.ink }
  Text {
   anchors.left:emblem.right;anchors.leftMargin:8*root.headerScale;anchors.verticalCenter:parent.verticalCenter
   id:headingText;text:"TOR";color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12*root.headerScale*1.15)
   font.weight:root.appearance===3?Font.DemiBold:Font.Normal
   font.letterSpacing:root.appearance===1?4:2
  }

  Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
   objectName:"tor-logo-next-phrase";anchors.left:emblem.left;anchors.right:headingText.right;anchors.top:parent.top;anchors.bottom:parent.bottom
   enabled:root.torRunning&&root.active&&root.interfaceVariation>0&&!root.darknetOpened&&!root.speedOpened&&!root.explanationOpened&&!root.circuitsShown&&!root.fileShown&&!root.relayOpened
   Accessible.name:"Next phrase";background:Item {}
   contentItem:Item {}
   onClicked:root.nextPhrase()
  }
  Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
   id:versionButton;objectName:"tor-version"
   anchors.left:headingText.right;anchors.leftMargin:8*root.headerScale;anchors.verticalCenter:parent.verticalCenter
   readonly property bool updateAvailable:root.updateStatus.available===true
   text:root.updateStatus.currentVersion?"v"+root.updateStatus.currentVersion:"…"
   leftPadding:6;rightPadding:6;topPadding:4;bottomPadding:4;hoverEnabled:true
   Accessible.name:text+(updateAvailable?", update available. Open changelog":". Open changelog")
   onClicked:root.openUpdate()
   background:Rectangle {
    radius:ThemeDesign.radius(4);color:versionButton.updateAvailable?Qt.alpha(root.accent,.16):versionButton.hovered?Qt.alpha(root.ink,.08):"transparent"
    border.width:versionButton.updateAvailable?1:0;border.color:Qt.alpha(root.accent,ThemeDesign.borderAlpha(.65))
   }
   contentItem:Text {text:versionButton.text+(versionButton.updateAvailable?"  ↑":"");color:versionButton.updateAvailable?root.accent:root.ink;opacity:versionButton.updateAvailable?1:.6;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10*root.headerScale)}
   TorToolTip {visible:versionButton.hovered;below:true;ink:root.ink;accent:root.accent;text:versionButton.updateAvailable?"Update available · v"+root.updateStatus.latestVersion:"Changelog"}
  }
 }
 Row {
  visible:root.interfaceVariation>0;z:12
  anchors.right:parent.right;anchors.rightMargin:46*root.headerScale;anchors.verticalCenter:heading.verticalCenter;spacing:8
  scale:root.headerScale;transformOrigin:Item.Right
  Repeater {
   model:["options","theme"]
   delegate:DashboardAction {
    required property var modelData
    objectName:"tor-card-"+(modelData==="theme"?"themes":modelData)
    descriptor:root.dashboardActions[modelData];width:34;height:34;panelActive:root.active;reducedMotion:root.reducedMotion
    ink:root.ink;accent:root.accent
    onClicked:root.triggerAction(descriptor.kind)
   }
  }
 }

 OrbitControls {
  id:orbitControls;visible:opacity>0&&!root.antipodeShown;opacity:root.layoutMix;enabled:root.orbitLayout;z:12
  x:(root.width-width)/2;y:Math.min(root.height/2,circuitInterface.noteTop-globeRadius-16-64*root.uiScale-8)-height/2
  width:root.width;height:Math.max(150,Math.min(root.width,root.height-224))
  globeRadius:globeView.width*.42*globeView.configuredZoom
  actions:root.showLaunchControls?Actions.networkKinds:[]
  actionModel:root.dashboardActions
  panelActive:root.active;reducedMotion:root.reducedMotion
  ink:root.ink;accent:root.accent
  onTriggered:kind=>root.triggerAction(kind)
 }
 function triggerAction(kind){
  if(!root.actionEnabled(kind))return
  if(kind==="browser")root.launchBrowser()
  else if(kind==="terminal")root.launchTerminal()
  else if(kind==="share")root.openShare()
  else if(kind==="chat")root.openChat()
  else if(kind==="website")root.openWebsite()
  else if(kind==="app")root.openApp()
  else if(kind==="darknet")root.openDarknet()
  else if(kind==="options")root.openOptions()
  else if(kind==="theme")openOverlay(themeChooser)
 }
 property var shortcutStatus:({})
 property bool shortcutBusy:false
 signal shortcutsRequested()
 signal shortcutChanged(string action,string key)
 OptionsDialog {
  id:optionsChooser;parent:root;z:40;ink:root.ink;accent:root.accent;surface:root.background;reducedMotion:root.reducedMotion
  resumeSharing:root.shareState.autoResume===true;resumeNeedsRestart:root.shareState.resumeNeedsRestart===true
  onResumeSharingChangedByUser:enabled=>root.shareResumeChanged(enabled)
  update:root.updateStatus;updateBusy:root.updateBusy;monitor:performanceMonitor
  diagnosticsEnabled:root.diagnosticsEnabled;diagnosticsHud:root.diagnosticsHud
  shortcuts:root.shortcutStatus;shortcutBusy:root.shortcutBusy
  onDiagnosticsChanged:value=>root.diagnosticsEnabled=value
  onHudChanged:value=>root.diagnosticsHud=value
  onUpdateRequested:root.openUpdate()
  onUpdateCheckRequested:root.updateCheckRequested()
  onShortcutsRequested:root.shortcutsRequested()
  onShortcutChanged:(action,key)=>root.shortcutChanged(action,key)
 }

 Flow {
  id:actionCards;objectName:"tor-action-cards";z:10
  readonly property int variation:root.classicInterfaceSettings.layout||0
  readonly property real presentationScale:root.classicInterfaceSettings.uiScale||1
  x:actionCards.variation===14?(root.width-width*actionCards.presentationScale)/2:actionCards.variation===3?root.width-width*actionCards.presentationScale:(actionCards.variation===7||actionCards.variation===11)?0:(root.width-width*actionCards.presentationScale)/2
  y:actionCards.variation===10||actionCards.variation===14?root.height-height*actionCards.presentationScale:actionCards.variation===11?(root.height-height*actionCards.presentationScale)/2:actionCards.variation===2?root.height-height*actionCards.presentationScale:actionCards.variation===3||actionCards.variation===7||actionCards.variation===11?(root.height-height*actionCards.presentationScale)/2:actionCards.variation===6?root.height-height*actionCards.presentationScale-115:actionCards.variation===8?root.height-height*actionCards.presentationScale-80:heading.height+12
  scale:actionCards.presentationScale;transformOrigin:Item.TopLeft
  spacing:actionCards.variation===5?16:8
  readonly property bool vertical:actionCards.variation===3||actionCards.variation===7||actionCards.variation===11
  width:vertical?34:Math.min(root.width/actionCards.presentationScale,actions.length*34+Math.max(0,actions.length-1)*spacing)
  height:childrenRect.height
  readonly property var actions:{
   var kinds=root.showLaunchControls?Actions.networkKinds.slice():[]
   if(actionCards.variation===0){if(root.showPowerControls)kinds.unshift("options");kinds.push("theme")}
   return kinds
  }
  visible:actions.length>0&&opacity>0;opacity:1-root.layoutMix;enabled:!root.orbitLayout
  Repeater {
   model:actionCards.actions
   delegate:DashboardAction {
    required property var modelData
    objectName:modelData==="theme"?"theme-action":"launch-tor-"+modelData
    descriptor:root.dashboardActions[modelData];width:34;height:34;panelActive:root.active;reducedMotion:root.reducedMotion
    ink:root.ink;accent:root.accent
    onClicked:root.triggerAction(descriptor.kind)
   }
  }
 }

 ThemesDialog {
  id:themeChooser;themes:root.availableThemes;currentId:root.currentThemeId
  ink:root.ink;accent:root.accent;surface:root.background;reducedMotion:root.reducedMotion
  onChosen:id=>root.themeChosen(id)
 }

 Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
  id:powerSwitch;objectName:"tor-power-button";visible:root.showPowerControls;z:12
  anchors.right:parent.right;anchors.verticalCenter:heading.verticalCenter
  width:34*root.headerScale*1.15;height:width;padding:0;hoverEnabled:true
  text:root.powerBusy?(root.state==="stopping"?"Stopping…":"Starting…"):root.torRunning?"Stop Tor":"Start Tor"
  enabled:(root.installationReady||root.torRunning)&&!root.powerBusy
  Accessible.name:text
  Accessible.description:root.torRunning?"Tor is on":!root.installationReady?"Installation required":"Tor is off"
  onClicked:root.torRunning?root.stopTor():root.startTor()
  property real illumination:root.torRunning?1:0
  Behavior on illumination {NumberAnimation {duration:350;easing.type:Easing.InOutCubic}}
  property real shimmer:0
  readonly property bool glowing:root.active&&visible&&(hovered||activeFocus||root.powerBusy)
  SequentialAnimation on shimmer {
   running:powerSwitch.glowing;loops:Animation.Infinite
   NumberAnimation {from:0;to:1;duration:1100;easing.type:Easing.InOutSine}
   NumberAnimation {from:1;to:0;duration:1100;easing.type:Easing.InOutSine}
  }
  background:Item {}
  contentItem:Item {
   Canvas {
    id:powerGlyph;anchors.centerIn:parent;width:22*root.headerScale*1.15;height:width
    property real glow:powerSwitch.glowing?.35+.65*powerSwitch.shimmer:0
    onGlowChanged:if(visible)requestPaint()
     onVisibleChanged:if(visible)requestPaint()
    scale:powerSwitch.down?.94:powerSwitch.glowing?1.03+.045*powerSwitch.shimmer:1
    Behavior on scale {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
    opacity:root.torRunning?1:.45
    Behavior on opacity {NumberAnimation {duration:300}}
    onPaint:{
     if(!visible)return
     var c=getContext("2d");c.reset();c.scale(root.headerScale*1.15,root.headerScale*1.15)
     c.strokeStyle=powerSwitch.glowing?root.accent:root.ink;c.shadowColor=c.strokeStyle;c.shadowBlur=5*glow
     c.lineWidth=1.3;c.lineCap="round"
     c.beginPath();c.arc(11,12,7,-Math.PI*.3,Math.PI*1.3);c.stroke()
     c.beginPath();c.moveTo(11,3);c.lineTo(11,10);c.stroke()
    }
    Connections {target:root;enabled:powerGlyph.visible;function onTorRunningChanged(){powerGlyph.requestPaint()}function onAccentChanged(){powerGlyph.requestPaint()}function onInkChanged(){powerGlyph.requestPaint()}function onHeaderScaleChanged(){powerGlyph.requestPaint()}function onCardDetailChanged(){powerGlyph.requestPaint()}}
   }
  }
  TorToolTip {visible:powerSwitch.hovered;below:true;ink:root.ink;accent:root.accent;text:powerSwitch.text;detail:root.torRunning?"Disconnect Tor and stop its isolated applications.":!root.installationReady?"Complete installation to start Tor.":"Connect to Tor. Opening this panel does not start it."}
 }
 // The globe and its arcs share the entire panel, beneath header and footer.
 // Clip at the panel edges, never at the old header/globe boundary.
 Item {
  id:globeStage;objectName:"globe-stage"
  x:-20;y:-20;width:root.width+40;height:root.height+40
  clip:true
 Globe {
  id:globeView
  selectedRelay:root.selectedHop?(root.selectedHop.fingerprint||""):""
  onRelaySelected:hop=>root.inspectRelay(hop)
  onBackgroundClicked:root.closeRelay()
  x:(parent.width-width)/2
  readonly property real classicSize:Math.min(root.width,Math.max(120,parent.height-20))
  readonly property real orbitSize:Math.min(orbitControls.height*.8,(orbitControls.ringRadius-26)/(.42*.7))
  readonly property real classicCenter:parent.height/2
  readonly property real orbitCenter:orbitControls.y+orbitControls.height/2-globeStage.y
  y:classicCenter+(orbitCenter-classicCenter)*root.layoutMix-height/2
  width:classicSize+(orbitSize-classicSize)*root.layoutMix;height:width
  presentationScale:root.appearance===8||root.orbitLayout?.82+.18*root.layoutMix:1
  clipToViewport:false
  active:root.active;animateInitialRoute:root.showPowerControls;appearance:root.appearance;accent:root.accent
  surface:ThemeColors.color("background");secondary:ThemeColors.color("bright_blue")
  localOrigin:root.localOrigin;localCircuitsShown:root.circuitsShown;localCircuits:root.circuitsAvailable?root.localCircuits.circuits:[];reducedMotion:root.reducedMotion
  route:root.route;effectSettings:root.effectSettings||Effects.defaults()
  transitionPreset:root.transitionPreset;circuitId:root.circuitId
  onZoomEdited:function(value){var next=Object.assign({},root.effectSettings||Effects.defaults());next.zoom=value;root.effectsEdited(next)}
 }
 AntipodeDiagram {anchors.fill:globeView;controller:antipode;globe:globeView;ink:root.ink;accent:root.accent}

 ExitLights {
  objectName:"dashboard-exit-lights";opacity:globeView.normalRouteOpacity
  anchors.fill:globeView;points:root.exitNetwork.points||[];clock:root.exitNetworkClock;variant:3
  longitude:globeView.longitude;latitude:globeView.latitude;roll:globeView.sceneRoll;zoom:globeView.zoomLevel
  sphereSize:globeView.width*globeView.presentationScale
 }
 }

 CircuitInterface {
  id:circuitInterface;opacity:root.antipodeShown?0:1;enabled:!root.antipodeShown
  Behavior on opacity {NumberAnimation {duration:root.reducedMotion?0:200}}
  objectName:"theme-circuit-interface";anchors.fill:parent;z:15
  orbitLayout:root.orbitLayout;orbitBottom:orbitControls.y+orbitControls.height/2+globeView.width*.42*globeView.configuredZoom
  cardDetail:root.cardDetail;uiScale:root.uiScale
  variant:root.interfaceVariation;active:root.active;route:root.route;state:root.state
  cyclingEnabled:root.interfaceSettings.cyclingEnabled!==false
  network:root.exitNetwork;illuminating:root.exitNetworkLoading;illuminationRunning:root.exitNetworkPlaying
  torRunning:root.torRunning;busy:root.busy;canChange:root.canChange;cooldown:root.cooldown
  pickerEnabled:root.installationReady&&!root.powerBusy
  countries:root.exitCountries;country:root.exitCountry;ink:root.ink;accent:root.accent
  explanationOpened:root.optionsOpened||root.themesOpened||root.shareOpened||root.chatOpened||root.hostOpened||root.installationOpened||root.updateOpened||root.darknetOpened||root.antipodeShown||root.speedOpened||root.explanationOpened||root.circuitsShown||root.fileShown||root.relayOpened
  sharingActive:root.sharingActive
  reducedMotion:root.reducedMotion
  antipodeOrigin:root.localOrigin;antipodeResult:antipode.result
  onionEstimate:root.onionEstimate
  builtCount:root.builtCount;circuitsShown:root.circuitsShown
  onExplanationRequested:topic=>{if(topic==="antipode")root.openAntipode();else if(topic==="compare-speed")openOverlay(speedDialog);else if(topic==="local-circuits"){root.closeOverlays(null);root.circuitsShown=true;root.forceActiveFocus()}else {explanation.topic=topic;openOverlay(explanation)}}
  onIlluminate:root.illuminateExitNodes()
  onRenew:root.newCircuit()
  onCountryChosen:code=>root.exitCountryChosen(code)
  onCountryPinned:code=>root.countryRestrictionChosen(code)
 }

 CircuitFooter {
  id:footer;objectName:"compact-circuit-footer";z:10;visible:root.showCircuitInterface&&!root.antipodeShown
  pickerLayer:root
  pickerEnabled:root.showCircuitInterface&&root.showLaunchControls&&root.installationReady&&(!root.showPowerControls||(root.torRunning&&!root.powerBusy));exitCountries:root.exitCountries;exitCountry:root.exitCountry
  onExitCountryChosen:function(code){root.exitCountryChosen(code)}
  onExitCountryPinned:code=>root.countryRestrictionChosen(code)
  anchors.bottom:circuitAction.top;anchors.bottomMargin:10;width:parent.width
  appearance:root.appearance;route:root.route
  ink:root.ink;accent:root.colors.atmosphere
  state:root.state;busy:root.busy;canChange:root.canChange;cooldown:root.cooldown;statusDetail:root.statusDetail
  onNewCircuit:root.newCircuit()
 }
 MouseArea {
  anchors.fill:parent;z:19;visible:footer.countryPicker.opened
  onClicked:footer.countryPicker.opened=false
 }
 onActiveChanged:if(!active)closePresentation()
  Button {
   HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
   id:circuitAction;hoverEnabled:true;objectName:"compact-circuit-action"
   visible:root.showCircuitInterface&&!root.antipodeShown&&(!root.showPowerControls||root.torRunning)
   anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:110;height:26;z:10
   enabled:root.canChange&&!root.busy&&root.cooldown<=0
   text:root.state==="starting"?"Building…":root.state==="stopping"?"Stopping…":root.busy&&root.state!=="offline"?"Updating…":"↻  New circuit"
   Accessible.name:circuitAction.text
   onClicked:root.newCircuit()
   background:Rectangle {radius:ThemeDesign.radius(4);color:circuitAction.hovered?Qt.rgba(root.accent.r,root.accent.g,root.accent.b,0.12):"transparent"}
   contentItem:Text {text:circuitAction.text;color:root.ink;opacity:circuitAction.enabled?0.8:0.4;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
   TorToolTip {
    visible:circuitAction.hovered;ink:root.ink;accent:root.accent
    text:circuitAction.text
    detail:root.busy?"Updating your Tor route…":root.cooldown>0?"New circuit temporarily unavailable":"Request fresh circuits. Tor may reuse an exit; existing connections keep their routes."
   }
  }


}
