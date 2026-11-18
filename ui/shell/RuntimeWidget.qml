import ".."
import QtQuick
import "../theme/EffectSettings.js" as Effects
import "InstallationPrompt.js" as InstallPrompt
import "UpdatePrompt.js" as UpdatePrompt
import "PanelSizing.js" as PanelSizing
import "TorAvailability.js" as Availability
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

Panel {
  id: root
  Binding {target:ThemeDesign;property:"fontFamily";value:Style.font.family}
  Binding {target:ThemeDesign;property:"fontScale";value:Style.fontScale}
  Binding {target:ThemeDesign;property:"fontSizes";value:({10:Style.font.caption,11:Style.font.bodySmall,12:Style.font.body,13:Style.font.subtitle,14:Style.font.title,16:Style.font.heading,24:Style.font.display})}
  moduleName: "tor.workspace"
  ipcTarget: "tor.workspace"
  manageIpc: false
  readonly property bool inWorkspace: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.name === "Tor"
  readonly property color ink: ThemeColors.color("uiText")
  readonly property color accent: ThemeColors.color("uiAccent")
  AppearanceSync {
    id:appearanceSync
    pluginPath:root.pluginPath
    pythonAvailable:root.setupStatus.pythonAvailable===true
    animate:root.opened&&dashboard.visible&&!dashboard.reducedMotion
    onThemeChanging:dashboard.closePresentation()
  }
  readonly property string themeError:appearanceSync.error
  readonly property var publishedThemes:appearanceSync.publishedThemes
  readonly property var namedThemes:appearanceSync.namedThemes
  readonly property var namedTheme:appearanceSync.namedTheme
  readonly property var appliedTheme:appearanceSync.appliedTheme
  property alias baseSessionSettings:appearanceSync.baseSessionSettings
  readonly property var sessionSettings:appearanceSync.sessionSettings
  property var pendingAntipode:null
  function startAntipodeRequest(){
    if(!setupStatus.ready)return

    if(!pendingAntipode||antipodeRequest.running)return
    var next=pendingAntipode;pendingAntipode=null;antipodeRequest.revision=next.revision
    antipodeRequest.command=["python3","-B",Qt.resolvedUrl("../../backend/antipode.py").toString().replace(/^file:\/\//,"")].concat(next.refresh?["--refresh"]:[])
    antipodeRequest.running=true
  }
  Process {
    id:antipodeRequest;property int revision:0
    stdout:StdioCollector {onStreamFinished:{try{dashboard.antipodeController.receive(JSON.parse(text),antipodeRequest.revision)}catch(e){dashboard.antipodeController.receive({error:"Exit countries unavailable."},antipodeRequest.revision)}}}
    onExited:(code,status)=>{if(code!==0)dashboard.antipodeController.receive({error:"Could not read the local Tor exit directory. Connect Tor and retry."},revision);Qt.callLater(root.startAntipodeRequest)}
  }
  property var pendingRelay:null
  function requestRelay(fp,revision) {
    if(!setupStatus.ready)return
    pendingRelay={fp:fp,revision:revision}
    if(!relayRequest.running)startRelayRequest()
  }
  function startRelayRequest() {
    if(!pendingRelay)return
    var next=pendingRelay
    pendingRelay=null
    relayRequest.revision=next.revision
    relayRequest.command=["python3","-B",pluginPath+"backend/relay_info.py",next.fp]
    relayRequest.running=true
  }
  Process {
    id:relayRequest;property int revision:0
    stdout:SplitParser {onRead:data=>{try{dashboard.receiveRelayInfo(JSON.parse(data),relayRequest.revision)}catch(e){}}}
    onExited:(code,status)=>{if(code!==0)dashboard.receiveRelayInfo({fingerprint:command[command.length-1],loading:false,unavailable:true},revision);Qt.callLater(root.startRelayRequest)}
  }
  property var shortcutStatus:({})
  function shortcuts(command,action,key){
    if(shortcutWorker.running)return
    shortcutWorker.command=["python3","-B",decodeURIComponent(Qt.resolvedUrl("../../backend/shortcuts.py").toString().replace(/^file:\/\//,"")),command||"status"]
    if(command==="set")shortcutWorker.command=shortcutWorker.command.concat([action,key])
    shortcutWorker.running=true
  }
  Timer {interval:800;running:root.setupStatus.pythonAvailable===true;onTriggered:root.shortcuts("sync")}
  Process {
    id:shortcutWorker
    stdout:StdioCollector {onStreamFinished:{try{var value=JSON.parse(text);root.shortcutStatus=value.bindings?value:Object.assign({},root.shortcutStatus,{error:value.error||"Shortcut update failed."})}catch(e){root.shortcutStatus=Object.assign({},root.shortcutStatus,{error:"Could not read shortcuts."})}}}
  }
  property string installationFeedback:""
  readonly property string pluginPath:decodeURIComponent(Qt.resolvedUrl("../../").toString().replace(/^file:\/\//,""))
  property bool installationAgentAvailable:false
  function checkInstallationAgent(){if(!agentProbe.running)agentProbe.running=true}
  Process {
    id:agentProbe
    command:["bash",root.pluginPath+"install/agent-status.sh"]
    stdout:StdioCollector {onStreamFinished:{try{root.installationAgentAvailable=JSON.parse(text).available===true}catch(e){root.installationAgentAvailable=false}}}
    onExited:code=>{if(code!==0)root.installationAgentAvailable=false}
  }
  AgentHandoff {
    id:agentHandoff
    pluginPath:root.pluginPath
    onDeparting:{dashboard.closePresentation();root.close()}
    onFailed:purpose=>root.agentFailed(purpose)
  }
  function agentFailed(purpose) {
    root.open()
    if(purpose==="update") {
      updateFeedback="Could not complete update handoff. Check the terminal, then check for updates again."
      Qt.callLater(dashboard.openUpdate)
    } else {
      installationFeedback="Could not open setup. Check your default agent or use Manual instructions."
      Qt.callLater(dashboard.openInstallation)
    }
  }
  function installationAction(command) {
    installationFeedback=""
    agentHandoff.launch(command,"installation")
  }
  function configureInstallationAgent(){installationAction(["omarchy","menu","summon","setup.default.agent"])}
  function installationManual(){installationAction(["omarchy","launch","editor",pluginPath+"docs/INSTALL.md"])}
  property var updateStatus:({})
  property string updateFeedback:""
  function checkUpdates(force) {
    if(updateCheck.running || !setupStatus.pythonAvailable)return
    updateCheck.command=["python3","-B",decodeURIComponent(Qt.resolvedUrl("../../backend/updates.py").toString().replace(/^file:\/\//,""))].concat(force?["--force"]:[])
    updateCheck.running=true
  }
  Process {
    id:updateCheck
    stdout:SplitParser {onRead:data=>{try{
      var value=JSON.parse(data)
      if(!value.local || !root.updateStatus.currentVersion)root.updateStatus=value
    }catch(e){root.updateStatus=Object.assign({},root.updateStatus,{error:"Could not read update status."})}}}
    onExited:code=>{if(code!==0)root.updateStatus=Object.assign({},root.updateStatus,{error:"Could not check for updates."})}
  }
  Timer {interval:3600000;repeat:true;triggeredOnStart:true;running:root.setupStatus.ready;onTriggered:root.checkUpdates(false)}
  function updateWithAgent() {
    if(agentHandoff.busy || updateStatus.canUpdate!==true)return
    updateFeedback="Continue in your agent terminal."
    agentHandoff.launch(["omarchy","launch","tui","python3","-B",
      pluginPath+"install/update-session.py",updateStatus.revision,
      UpdatePrompt.text(pluginPath,updateStatus.revision)],"update")
  }
  function installWithAgent() {
    installationAction(["omarchy","launch","tui","bash",pluginPath+"install/agent-session.sh",InstallPrompt.text(pluginPath)])
  }
  property var installationHost: null
  readonly property var setupStatus: installationHost ? installationHost.installation : ({ready:false})
  onSetupStatusChanged: {if(setupStatus.ready)refresh("cached")}
  function checkSetup() { if(installationHost)installationHost.checkInstallation() }
  property var shareSelection:[]
  Process {
    id:sharePicker
    command:["python3",Qt.resolvedUrl("../../backend/file_picker.py").toString().replace(/^file:\/\//,"")]
    stdout:StdioCollector {onStreamFinished:{try{root.open();root.shareSelection=JSON.parse(text).files}catch(e){root.shareState=Object.assign({},root.shareState,{error:"File chooser failed. Try again."});root.open();Qt.callLater(dashboard.openShare)}}}
  }
  property var shareState:({api:2,shares:[],readyCount:0})
  function shareCommand(action, payload) { shareTransport.send(action, payload) }
  ServiceTransport {
    id: shareTransport
    script: root.pluginPath + "backend/share.py"
    executableAvailable: root.setupStatus.pythonAvailable === true
    startAllowed: root.setupStatus.ready && dashboard.networkEnabled
    startActions: ["start", "retry"]
    failureMessage: "Could not read sharing status."
    onReceived: value => {
      if (JSON.stringify(value) !== JSON.stringify(root.shareState)) root.shareState = value
    }
    onFailed: message => root.shareState = Object.assign({}, root.shareState, {error: message})
  }
  property var chatState:({state:"idle",url:""})
  function chatCommand(action, payload) { chatTransport.send(action, payload) }
  ServiceTransport {
    id: chatTransport
    script: root.pluginPath + "backend/chat.py"
    executableAvailable: root.setupStatus.pythonAvailable === true
    startAllowed: root.setupStatus.ready && dashboard.networkEnabled
    startActions: ["start"]
    failureMessage: "Room unavailable."
    onReceived: value => {
      if (JSON.stringify(value) !== JSON.stringify(root.chatState)) root.chatState = value
    }
    onFailed: message => root.chatState = Object.assign({}, root.chatState, {error: message})
  }
  property var hostState:({state:"idle",url:""})
  function hostCommand(action, payload) { hostTransport.send(action, payload) }
  ServiceTransport {
    id: hostTransport
    script: root.pluginPath + "backend/host.py"
    executableAvailable: root.setupStatus.pythonAvailable === true
    startAllowed: root.setupStatus.ready && dashboard.networkEnabled
    startActions: ["start"]
    failureMessage: "Hosting unavailable."
    onReceived: value => {
      if (JSON.stringify(value) !== JSON.stringify(root.hostState)) root.hostState = value
    }
    onFailed: message => root.hostState = Object.assign({}, root.hostState, {error: message})
  }
  Process {
    id:hostPicker
    command:["python3",Qt.resolvedUrl("../../backend/file_picker.py").toString().replace(/^file:\/\//,""),"--folder"]
    stdout:StdioCollector {onStreamFinished:{root.open();try{dashboard.selectHostFolder(JSON.parse(text).folder)}catch(e){root.hostState=Object.assign({},root.hostState,{error:"Folder chooser failed. Try again."});dashboard.openHost()}}}
  }
  property var connection: ({state:"offline",running:false,route:[]})
  readonly property bool gatewayRunning:connection.running===true
  property double connectionCheckedAt:0
  readonly property bool serviceAvailable:Availability.available(connection,connectionCheckedAt,clockNow)
    &&!countryChangePending&&!(request.running&&action==="set-country")
  property bool stoppingTor:false
  property string action: "status"
  property string selectedCountry: ""
  property bool countryChangePending: false
  property string countryAction:"new-circuits"
  property int presentationRevision:0
  function chooseCountry(code) {
    if(!setupStatus.ready)return

    // Removing a restriction does not invalidate an existing illustration.
    if(code!==selectedCountry&&(code!==""||!route.length)){
      renewal.finish()
      displayedCircuit.beginReplacement(code);renewal.begin();presentationRevision++
    }
    countryAction="set-country"
    selectedCountry=code;countryChangePending=true
    applyPendingCountry()
  }
  function applyPendingCountry() {
    if (!countryChangePending || request.running || lifecycle.running) return
    countryChangePending=false
    refresh(countryAction)
  }
  Timer { interval:250;repeat:true;running:root.opened && root.inWorkspace && root.countryChangePending;onTriggered:root.applyPendingCountry() }
  property var countries: [{code:"", name:"Automatic"}]
  function launchApp(kind) {
    if(!setupStatus.ready||!dashboard.networkEnabled||lifecycle.running)return
    Quickshell.execDetached(["python3", "-B", Qt.resolvedUrl("../../backend/launch.py").toString().replace(/^file:\/\//, ""), kind])
    root.close()
  }
  Process {
    id: countryRequest
    command: ["python3", "-B", Qt.resolvedUrl("../../backend/backend.py").toString().replace(/^file:\/\//, ""), "countries"]
    running: root.setupStatus.ready
    stdout: StdioCollector { onStreamFinished: { try { root.countries=JSON.parse(text) } catch(e) {} } }
  }
  Process {
    id:speedWorker;stdinEnabled:true
    command:["python3","-B",Qt.resolvedUrl("../../backend/speed_compare.py").toString().replace(/^file:\/\//,"")]
    stdout:SplitParser {onRead:data=>{try{dashboard.receiveSpeed(JSON.parse(data))}catch(e){}}}
    onExited:function(code,status){if(code!==0)dashboard.receiveSpeed({running:false,error:"Comparison stopped unexpectedly."})}
  }
  property var onionEstimate:null
  Process {
    id:estimateRead
    command:["python3","-B",Qt.resolvedUrl("../../backend/onion_estimate.py").toString().replace(/^file:\/\//,""),"--cached"]
    stdout:StdioCollector {onStreamFinished:{try{root.onionEstimate=JSON.parse(text)}catch(e){}}}
    onExited:{if(!estimateRefresh.running)estimateRefresh.running=true}
  }
  Process {
    id:estimateRefresh
    command:["python3","-B",Qt.resolvedUrl("../../backend/onion_estimate.py").toString().replace(/^file:\/\//,"")]
    stdout:StdioCollector {onStreamFinished:{try{var value=JSON.parse(text);if(value)root.onionEstimate=value}catch(e){}}}
  }
  Timer {interval:3600000;repeat:true;running:root.opened&&root.setupStatus.ready;triggeredOnStart:true;onTriggered:if(!estimateRead.running&&!estimateRefresh.running)estimateRead.running=true}
  property var exitNetwork:({points:[]})
  property string exitNetworkError:""
  property bool playRequested:false
  function illuminateExitNodes() {
    if(root.exitNetwork.points&&root.exitNetwork.points.length){dashboard.playExitNetwork();return}
    loadExitNetwork(true)
  }
  function loadExitNetwork(playback) {
    if(!gatewayRunning)return
    if(playback)playRequested=true
    if(exitRequest.running)return
    exitNetworkError=""
    exitRequest.running=true
  }
  Process {
    id:exitRequest
    command:["python3","-B",Qt.resolvedUrl("../../backend/exit_network.py").toString().replace(/^file:\/\//, "")]
    stdout:StdioCollector {onStreamFinished:{
      try {
        var data=JSON.parse(text)
        if(data.error||!data.points||!data.points.length)throw new Error(data.error||"No exit locations available")
        if(root.gatewayRunning){root.exitNetwork=data;if(root.playRequested)dashboard.playExitNetwork()}
        root.playRequested=false
      } catch(e){root.exitNetworkError=String(e)}
    }}
    onExited:function(code,status){if(code!==0)root.exitNetworkError="Could not read the Tor exit directory. Try again."}
  }
  Timer {interval:60000;running:root.opened&&root.gatewayRunning;repeat:true;triggeredOnStart:true;onTriggered:root.loadExitNetwork(false)}
  onGatewayRunningChanged:if(!gatewayRunning){exitNetwork=({points:[]});playRequested=false;dashboard.exitNetworkClock=24}
  property double clockNow: Date.now() / 1000
  readonly property int cooldown: Math.max(0, Math.ceil((connection.nextChangeAt || 0) - clockNow))
  readonly property bool busy: (request.running && action !== "status" && action !== "cached") || lifecycle.running
  readonly property string connectionLabel: !setupStatus.ready ? "Installation required" : busy ? (action === "new-circuits" ? "Requesting fresh circuits…" : "Checking Tor connection…")
    : serviceAvailable ? "Tor is on"
    : connection.state === "starting" ? (connection.progress !== undefined && connection.progress < 100 ? "Connecting to Tor · " + connection.progress + "%" : connection.message || "Waiting for a Tor circuit…")
    : connection.state === "busy" ? "Tor request in progress"
    : connection.message || "Connection check unavailable"
  CircuitRenewal {
    id:renewal;connection:root.connection;automaticObservation:false
    onPendingChanged:if(!pending&&displayedCircuit.replacementPending)displayedCircuit.failReplacement()
  }
  DisplayedCircuit {id:displayedCircuit;connection:root.connection;onReplacementReady:renewal.finish()}
  readonly property var route:displayedCircuit.route
  // Routine spare-circuit expiry is invisible; explicit renewal keeps its feedback.
  readonly property string presentationState:renewal.pending?"starting":serviceAvailable?"ready":connection.state||"offline"
  readonly property bool canChange: gatewayRunning && !busy && !renewal.pending && (serviceAvailable || route.length===4 || displayedCircuit.failed || connection.state === "ready" || connection.state === "error" || connection.state === "unavailable") && cooldown === 0
  readonly property string changeHint: renewal.pending ? "Waiting for a new Tor circuit…" : renewal.message ? renewal.message : busy ? connectionLabel
    : cooldown > 0 ? "Request fresh circuits · wait " + cooldown + "s"
    : route.length === 4 ? "Request fresh circuits"
    : connection.state === "starting" ? connectionLabel
    : (connection.message ? connection.message + "\n" : "") + "Request fresh circuits"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function activate() {
    if (!root.setupStatus.ready || root.inWorkspace) root.open()
    else Hyprland.dispatch("hl.dsp.focus({workspace=\"name:Tor\"})")
  }
  function refresh(nextAction) {
    if (!setupStatus.ready || lifecycle.running) return
    if(nextAction==="new-circuits"&&!renewal.pending){
      displayedCircuit.beginReplacement();renewal.begin();presentationRevision++
    }
    if (request.running) {
      if (nextAction !== "new-circuits" || root.action === "new-circuits") return
      countryAction="new-circuits";countryChangePending=true
      return
    }
    root.action = nextAction || "status"
    request.presentationRevision=root.presentationRevision
    if(root.action==="new-circuits")displayedCircuit.excludeCurrent()
    request.command = ["python3", "-B", Qt.resolvedUrl("../../backend/backend.py").toString().replace(/^file:\/\//, ""), root.action]
    if (root.action === "set-country") request.command = request.command.concat([root.selectedCountry])
    request.running = true
  }
  function controlTor(action){
    if(lifecycle.running||(action!=="stop"&&!setupStatus.ready))return
    request.running=false
    renewal.finish();displayedCircuit.reset();presentationRevision++
    stoppingTor=action==="stop"
    root.connection={state:stoppingTor?"stopping":"starting",running:!stoppingTor,route:[],message:stoppingTor?"Stopping Tor…":"Starting Tor…"}
    root.exitNetwork={points:[]};dashboard.exitNetworkClock=24
    lifecycle.command=["python3","-B",Qt.resolvedUrl("../../backend/lifecycle.py").toString().replace(/^file:\/\//,""),action]
    lifecycle.running=true
  }
  Process {
    id:lifecycle
    stdout:StdioCollector{id:lifecycleReply;waitForEnd:true}
    onExited:function(code,status){
      root.stoppingTor=false
      button.refreshStatus()
      try{var value=JSON.parse(lifecycleReply.text);root.connection=value;
        if(code!==0)root.connection.message=value.message
      }catch(e){root.connection={state:"error",running:true,route:[],message:"Tor command failed. Retry Stop Tor or refresh."}}
      if(code===0&&root.gatewayRunning)root.refresh("status")
    }
  }
  onInWorkspaceChanged: if(setupStatus.ready&&!inWorkspace)root.close()
  Component.onCompleted:refresh("cached")
  onOpenedChanged: {
    if (opened && setupStatus.ready && !inWorkspace) { root.close(); return }
    if (opened) {
      checkSetup()
      if (setupStatus.ready && !countryRequest.running) countryRequest.running=true
      clockNow = Date.now() / 1000
      refresh("status")
    }
  }
  Timer { interval: 1000; running: root.opened; repeat: true; onTriggered: root.clockNow = Date.now() / 1000 }
  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: { if (setupStatus.ready && !countryRequest.running) countryRequest.running=true } }
  Timer {
    interval: 3000
    running: root.setupStatus.ready && (root.opened || button.torRunning) && !root.busy
    repeat: true
    onTriggered: root.refresh(root.opened?"status":"cached")
  }
  Process {
    id: request
    property int presentationRevision:0
    stdout: StdioCollector { id: response; waitForEnd: true }
    stderr: StdioCollector {}
    onExited: function(code, status) {
      if(lifecycle.running||root.stoppingTor)return
      try {
        var next=JSON.parse(response.text)
        // Advance the clock before publishing newer observations. Bindings run
        // between assignments: a future checkedAt/heartbeat would briefly revoke
        // availability and dismiss an open service overlay on every status poll.
        var observedAt = Date.now() / 1000
        root.clockNow = observedAt
        if (next.state !== "busy" && code === 0)
          root.connectionCheckedAt = observedAt
        // A competing read is not a circuit change. Keep the verified display.
        if (next.state !== "busy" && JSON.stringify(next) !== JSON.stringify(root.connection))
          root.connection=next
        if(request.presentationRevision===root.presentationRevision){
          if(root.action==="new-circuits"||root.action==="set-country")displayedCircuit.acknowledgeReplacement()
          if(next.state!=="ready"||renewal.generation&&next.gatewayGeneration&&renewal.generation!==String(next.gatewayGeneration))renewal.observe()
        }
        if(!root.countryChangePending)root.selectedCountry=root.connection.exitCountry || ""
      }
      catch (e) { if(request.presentationRevision===root.presentationRevision)renewal.fail();root.connection = Object.assign({}, root.connection, {
        state:"error",route:[], message: "Could not read the Tor connection. Request a new circuit to retry."}) }
      root.clockNow = Date.now() / 1000
      root.applyPendingCountry()
    }
  }

  TorWorkspaceButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    reducedMotion:dashboard.reducedMotion
    active: root.inWorkspace
    activeColor: ThemeColors.color("trayLight")
    tooltipText: !root.setupStatus.ready ? "Tor Workspace · Installation required" : (torRunning?"Tor is on":"Tor is off") + (root.inWorkspace?" · Connection controls":" · Go to Tor workspace")
    onPressed: function(mouseButton) { if (mouseButton === Qt.LeftButton) root.activate() }
    Rectangle {
      objectName:"tor-workspace-underline"
      anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(18); height: Style.space(2); radius: height / 2
      color: ThemeColors.color("trayLight"); visible: root.inWorkspace
    }
  }

  TorPopup {
    id: popup
    anchorItem: button
    // Coordinate the actual panel, not the outer bar-entry wrapper. The bar
    // then leaves popup marking to our single workspace underline.
    owner: root
    bar: root.bar
    open: root.opened && (root.inWorkspace || !root.setupStatus.ready)
    focusTarget: keys
    panelBackground: Effects.surfacePalette(dashboard.effectSettings).panel
    panelRadius: ThemeDesign.radius(Style.cornerRadius)
    borderSpec: Border.flat(dashboard.appearance === 3 ? ThemeColors.color("nightwatchBorder") : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3), ThemeDesign.definition.outline)
    gap: 12
    padding: 22
    readonly property var fittedSize:PanelSizing.fit(screenH,availableCardWidth,availableCardHeight)
    contentWidth: fittedSize.width
    contentHeight: fittedSize.height
    PanelKeyCatcher {
      id: keys
      blocked:dashboard.optionsOpened||dashboard.themesOpened||dashboard.darknetOpened||dashboard.updateOpened||dashboard.installationOpened||dashboard.antipodeShown||dashboard.shareOpened||dashboard.chatOpened||dashboard.hostOpened||dashboard.speedOpened||dashboard.explanationOpened||dashboard.circuitsShown||dashboard.fileShown
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested:direction=>dashboard.focusNextControl(direction)
      onMoveRequested: function(dx, dy) { dashboard.globe.rotate(dx * 6, dy * 6) }
      TorDashboard {
        id: dashboard
        onAntipodeRequested:(refresh,revision)=>{root.pendingAntipode={refresh:refresh,revision:revision};root.startAntipodeRequest()}
        localOrigin:root.connection.origin||({})
        localCircuits:root.connection.localCircuits||({available:false})
        originState:root.connection.originState||""
        cornerRadius: ThemeDesign.radius(Style.cornerRadius)
        anchors.fill: parent
        appearance: root.appliedTheme.appearance
        interfaceSettings:Effects.interfaceConfig(root.appliedTheme.interface)
        onSpeedStartRequested:{if(!dashboard.networkEnabled)dashboard.receiveSpeed({running:false,error:"Tor is not available. Start Tor and retry."});else if(!speedWorker.running)speedWorker.running=true;else dashboard.receiveSpeed({running:false,error:"Previous comparison is stopping. Try again."})}
        onSpeedCancelRequested:if(speedWorker.running)speedWorker.signal(15)
        onionEstimate:root.onionEstimate
        exitNetwork:root.exitNetwork
        exitNetworkLoading:exitRequest.running
        exitNetworkError:root.exitNetworkError
        onIlluminateExitNodes:root.illuminateExitNodes()
        availableThemes:root.namedThemes
        currentThemeId:root.appliedTheme.id
        onThemeChosen:id=>appearanceSync.selectedId=id
        showLaunchControls: true
        installationReady:root.setupStatus.ready
        installationBusy:agentHandoff.busy
        installationFeedback:root.installationFeedback
        installationAgentAvailable:root.installationAgentAvailable
        onInstallationCheckRequested:root.checkInstallationAgent()
        onInstallationConfigureRequested:root.configureInstallationAgent()
        onInstallationManualRequested:root.installationManual()
        onInstallationRequested:root.installWithAgent()
        updateStatus:root.updateStatus
        updateBusy:updateCheck.running||agentHandoff.busy
        updateFeedback:root.updateFeedback
        onUpdateRequested:root.updateWithAgent()
        onUpdateCheckRequested:root.checkUpdates(true)
        shortcutStatus:root.shortcutStatus;shortcutBusy:shortcutWorker.running
        onShortcutsRequested:root.shortcuts("status")
        onShortcutChanged:(action,key)=>root.shortcuts("set",action,key)
        exitCountries: root.countries
        exitCountry: root.selectedCountry
        onExitCountryChosen: function(code) { root.chooseCountry(code) }
        onCountryRestrictionChosen:code=>root.chooseCountry(code)
        shareSelection:root.shareSelection
        onShareChooseRequested:{root.close();sharePicker.running=true}
        hostState:root.hostState
        onHostStartRequested:source=>root.hostCommand("start",source)
        onHostStopRequested:root.hostCommand("stop")
        onHostStatusRequested:root.hostCommand("status")
        onHostOpenRequested:root.launchApp("host-browser")
        onLaunchDarknet:root.launchApp("darknet-browser")
        onHostChooseRequested:{root.close();hostPicker.running=true}
        chatState:root.chatState
        onChatStartRequested:colors=>root.chatCommand("start",{colors:colors})
        onChatStopRequested:root.chatCommand("stop")
        onChatStatusRequested:root.chatCommand("status")
        onChatOpenRequested:root.launchApp("chat-browser")
        shareSubmitting:shareTransport.starting
        shareState:root.shareState
        onShareResumeChanged:enabled=>root.shareCommand("resume-option",{enabled:enabled})
        onShareStartRequested:(files,colors)=>root.shareCommand("start",{files:files,colors:colors})
        onShareStopRequested:id=>root.shareCommand("stop",{id:id})
        onShareRetryRequested:id=>root.shareCommand("retry",{id:id})
        onShareDismissRequested:id=>root.shareCommand("dismiss",{id:id})
        onShareStatusRequested:root.shareCommand("status")
        onLaunchTerminal: root.launchApp("terminal")
        onLaunchBrowser: root.launchApp("browser")
        presetCamera: root.appliedTheme.camera || null
        effectSettings: root.sessionSettings
        onEffectsEdited: function(value) { root.baseSessionSettings=Object.assign({},root.baseSessionSettings,{zoom:value.zoom}) }
        accent: root.accent; ink: root.ink; background: Effects.surfacePalette(dashboard.effectSettings).panel
        transitionPreset:root.sessionSettings.transitionPreset||"ember"
        onRelayInfoRequested:(fp,revision)=>root.requestRelay(fp,revision)
        circuitId:displayedCircuit.circuitId
        showPowerControls:true;torRunning:root.setupStatus.ready?root.gatewayRunning:button.torRunning;powerBusy:lifecycle.running
        onStartTor:root.controlTor("start")
        onStopTor:root.controlTor("stop")
        serviceAvailable:root.serviceAvailable
        route: root.route; state: root.presentationState; connectionMessage:root.connectionLabel
        busy: root.busy||renewal.pending; active: root.opened && (root.inWorkspace || !root.setupStatus.ready)
        canChange: root.canChange; cooldown: root.cooldown; statusDetail: root.changeHint
        onNewCircuit: if (root.canChange) root.refresh("new-circuits")
      }
    }
  }

  IpcHandler {
    target: "tor.workspace"
    function activate(): void { root.activate() }
    function open(): void { if (!root.setupStatus.ready || root.inWorkspace) root.open() }
    function close(): void { root.close() }
    function antipode(): void { if(root.inWorkspace){root.open();Qt.callLater(dashboard.openAntipode)} }
    function share(): void { root.open();Qt.callLater(dashboard.openShare) }
    function host(): void { if(root.inWorkspace){root.open();Qt.callLater(dashboard.openHost)} }
    function website(): void { if(root.inWorkspace){root.open();Qt.callLater(dashboard.openWebsite)} }
    function app(): void { if(root.inWorkspace){root.open();Qt.callLater(dashboard.openApp)} }
    function chat(): void { root.open();Qt.callLater(dashboard.openChat) }
    function installation(): void {root.open();Qt.callLater(dashboard.openInstallation)}
    function installationFailed(): void {root.installationFeedback="Could not run your agent. Check its terminal setup or use Manual instructions.";root.open();Qt.callLater(dashboard.openInstallation)}
    function updateFailed(): void {root.agentFailed("update")}
    function options(): void { root.open();Qt.callLater(dashboard.openOptions) }
    function updates(): string { return JSON.stringify(root.updateStatus) }
    function refresh(): void { if (root.canChange) root.refresh("new-circuits") }
    function startTor(): void { root.controlTor("start") }
    function stopTor(): void { root.controlTor("stop") }
    function terminal(): void { root.launchApp("terminal") }
    function browser(): void { root.launchApp("browser") }
    function illuminateExitNodes(): void { root.illuminateExitNodes() }
    function diagnostics(enabled: bool): void {dashboard.diagnosticsEnabled=enabled}
    function performanceHud(enabled: bool): void {dashboard.diagnosticsHud=enabled}
    function performance(): string {return JSON.stringify(dashboard.performance.snapshot())}
    function capturePerformance(seconds: int): bool {return dashboard.performance.capture(seconds)}
    function themes(): string {return JSON.stringify(root.namedThemes.map(function(theme){return {id:theme.id,name:theme.name,design:theme.interface&&theme.interface.design||"original"}}))}
    function selectTheme(id: string): bool {if(!root.publishedThemes.some(function(theme){return theme.id===id}))return false;appearanceSync.selectedId=id;return true}
    function appliedConfiguration(): string { return JSON.stringify({preset:root.namedTheme,settings:root.sessionSettings}) }
    function paletteStatus(): string {return JSON.stringify({theme:ThemeColors.themeId,pending:appearanceSync.pendingPalette?appearanceSync.pendingPalette.themeId:null,shell:appearanceSync.appliedShell,enabled:ThemeColors.animationEnabled,running:ThemeColors.transitioning,progress:ThemeColors.transitionProgress,duration:ThemeColors.transition.duration,background:String(ThemeColors.color("background")),accent:String(ThemeColors.color("uiAccent")),visible:dashboard.visible,reducedMotion:dashboard.reducedMotion,panel:{width:popup.contentWidth,height:popup.contentHeight,contentWidth:dashboard.width,contentHeight:dashboard.height},sky:dashboard.skyState})}
    function status(): string { return JSON.stringify({serviceAvailable:root.serviceAvailable,networkEnabled:dashboard.networkEnabled,presentationState:root.presentationState,displayedCircuitId:displayedCircuit.circuitId,installation:root.setupStatus,installationOpened:dashboard.installationOpened,antipode:{showing:dashboard.antipodeShown,loading:dashboard.antipodeController.loading,error:dashboard.antipodeController.error,result:dashboard.antipodeController.result},exitNetwork:{count:root.exitNetwork.count||0,countries:root.exitNetwork.countries||0,loading:exitRequest.running,error:root.exitNetworkError,clock:dashboard.exitNetworkClock,playing:dashboard.exitNetworkPlaying},workspace: root.inWorkspace, opened: root.opened, busy: root.busy||renewal.pending, circuitPending:renewal.pending, connection: root.connection,
      theme: {name:root.namedTheme.name,id:root.appliedTheme.id,palette:ThemeColors.themeId,font:ThemeDesign.fontFamily,fontScale:ThemeDesign.fontScale}, globe: {appearance: dashboard.globe.appearance, zoom:dashboard.globe.zoomLevel, longitude: dashboard.globe.longitude, latitude: dashboard.globe.latitude, automaticRotation: dashboard.globe.automaticRotation, active: dashboard.globe.active, renderStatus: dashboard.globe.renderStatus, mapReady: dashboard.globe.mapReady, camera:dashboard.globe.cameraState, styleTransition:dashboard.globe.styleTransitionState, transition: dashboard.globe.transitionState}}) }
  }
}
