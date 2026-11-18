import ".."
import QtQuick
import "../circuit/RouteGeometry.js" as Geometry
import "../theme/EffectSettings.js" as Effects
import "../theme/CountryIds.js" as Countries
import "../theme/SoftIllumination.js" as Soft

Item {
  id: root
  implicitWidth: 312
  implicitHeight: 312
  property bool animateInitialRoute:false
  property bool active: false
  readonly property bool frameZoomOnOpen:ThemeDesign.definition.frameZoomOnOpen
  function frameOpeningZoom(){
    if(!circuitOrbit||!frameZoomOnOpen)return
    // An inspection return can also be paused when its overlay is dismissed by closing the panel.
    inspectingRelay=false;inspectionReturning=false;inspectionSaved=null;inspectionTo=null
    orbit.frameZoom()
  }
  onActiveChanged:if(active)frameOpeningZoom()
  onVisibleChanged:if(visible)frameOpeningZoom()
  onFrameZoomOnOpenChanged:if(!active||!visible||orbit.clock===0)frameOpeningZoom()
  property bool externalCamera: false
  property bool antipodeShown:false
  property var antipodeSaved:null
  property var antipodeRoute:[]
  function beginAntipode(){
    if(antipodeShown)return
    if(inspectionSaved){longitude=inspectionSaved.longitude;latitude=inspectionSaved.latitude;viewRoll=inspectionSaved.roll;temporaryZoom=inspectionSaved.zoom}
    inspectingRelay=false;inspectionReturning=false;inspectionSaved=null;inspectionTo=null
    antipodeSaved={longitude:longitude,latitude:latitude,roll:viewRoll,zoom:temporaryZoom}
    antipodeRoute=route.slice();antipodeShown=true
  }
  function restoreAntipodePose(){if(!antipodeSaved)return;longitude=antipodeSaved.longitude;latitude=antipodeSaved.latitude;viewRoll=antipodeSaved.roll;temporaryZoom=antipodeSaved.zoom}
  function endAntipode(){restoreAntipodePose();antipodeShown=false;antipodeSaved=null}

  readonly property bool circuitOrbit:!externalCamera&&effectSettings&&effectSettings.cameraPreset==="circuit-orbit"
  readonly property var cameraState:({preset:circuitOrbit?"circuit-orbit":"legacy",baseZoom:configuredZoom,pose:orbit.pose,recovery:orbit.recovery,inspection:inspectionCamera,clock:orbit.clock,initialized:orbit.initialized,input:!!orbit.inputTarget,returning:!!orbit.recovery})
  CircuitOrbitController {
    id:orbit;objectName:"circuit-orbit-controller";enabled:root.circuitOrbit;reducedMotion:root.reducedMotion;route:root.antipodeShown?root.antipodeRoute:root.route;baseZoom:root.configuredZoom
    releaseSettings:ThemeDesign.definition.cameraRelease||{}
    frameInitialZoom:root.frameZoomOnOpen
    initialPose:root.animateInitialRoute?({yaw:root.longitude,pitch:root.latitude,roll:root.viewRoll,tilt:root.axialTilt,zoom:root.zoomLevel}):null
    onPoseChanged:if(enabled&&pose&&!root.antipodeShown&&!root.inspectionCamera){root.longitude=pose.yaw;root.latitude=pose.pitch;root.viewRoll=pose.roll+pose.tilt-root.axialTilt;root.temporaryZoom=pose.zoom}
  }
  property bool inspectingRelay:false
  property bool inspectionReturning:false
  readonly property bool inspectionCamera:inspectingRelay||inspectionReturning
  property var inspectionSaved:null
  property var inspectionFrom:null
  property var inspectionTo:null
  property real inspectionElapsed:0
  function cameraPose(){return {longitude:longitude,latitude:latitude,roll:viewRoll,zoom:zoomLevel}}
  function focusRelay(hop,variant){
    if(!Geometry.vector(hop))return
    if(!inspectionSaved)inspectionSaved=cameraPose()
    inspectingRelay=true;inspectionReturning=false;inspectionFrom=cameraPose();inspectionElapsed=0
    inspectionTo={longitude:-hop.longitude+(variant===2?-14:variant===3?0:13),latitude:Math.max(-75,Math.min(75,hop.latitude-18)),roll:-axialTilt,zoom:variant===2?1.65:variant===3?1.5:1.7}
    if(reducedMotion)advanceInspection(1)
  }
  function leaveRelay(){
    if(!inspectionSaved)return
    inspectingRelay=false;inspectionReturning=true;inspectionFrom=cameraPose();inspectionTo=inspectionSaved;inspectionElapsed=0
    if(reducedMotion)advanceInspection(1)
  }
  function advanceInspection(dt){
    if(!inspectionTo)return
    inspectionElapsed+=dt;var t=Math.min(1,inspectionElapsed/.8),e=t*t*(3-2*t)
    longitude=inspectionFrom.longitude+angleDelta(inspectionFrom.longitude,inspectionTo.longitude)*e
    latitude=inspectionFrom.latitude+(inspectionTo.latitude-inspectionFrom.latitude)*e
    viewRoll=inspectionFrom.roll+angleDelta(inspectionFrom.roll,inspectionTo.roll)*e
    temporaryZoom=inspectionFrom.zoom+(inspectionTo.zoom-inspectionFrom.zoom)*e
    if(t===1){inspectionTo=null;if(inspectionReturning){inspectionReturning=false;inspectionSaved=null}}
  }
  function relayAnchor(fp){
    var points=relayTargets.points
    for(var i=0;i<points.length;i++)if(points[i].hop.fingerprint===fp)return {x:points[i].x,y:points[i].y}
    return null
  }
  signal relaySelected(var hop)
  signal backgroundClicked()
  property string selectedRelay:""
  function relayAt(x,y){return relayTargets.visible&&relayTargets.hit(x,y)>=0}
  function restoreRelayFocus(){relayTargets.restoreFocus()}
  signal zoomEdited(real value)
  property color accent: ThemeColors.color("accent")
  property color secondary: ThemeColors.color("bright_blue")
  property int appearance: 0
  property real time: 0
  property color surface: ThemeColors.color("background")
  property real longitude: -24
  property real latitude: 22
  property bool automaticRotation: true
  property var route: []
  property var localCircuits:[]
  property var localOrigin:({})
  property bool localCircuitsShown:false
  readonly property bool circuitHovered:circuitHover.hovered
  HoverHandler {id:circuitHover;enabled:root.localCircuitsShown}
  property bool reducedMotion:false
  property real normalRouteOpacity:antipodeShown||localCircuitsShown?0:1
  Behavior on normalRouteOpacity {NumberAnimation {duration:root.reducedMotion?0:200}}
  // Preserve the fade, then suspend geometry, Canvas paints and route clocks.
  // Opacity alone does not make a QML item invisible or stop its animations.
  readonly property bool normalRouteVisible:normalRouteOpacity>0
  property string transitionPreset:""
  property string circuitId:""
  readonly property bool circuitDisplayed: route.length === 4 && (!designEnabled||designRoute.established) && (!emberEnabled ||
    (ember.initialized && !ember.retiring && (!ember.transitioning || ember.clock >= ember.revealDuration)))
  readonly property var transitionState: designEnabled?({preset:transitionPreset,initialized:designRoute.accepted.length>1,animating:designRoute.active,transitioning:designRoute.building||designRoute.retiring,clock:designRoute.clock,oldRouteLength:designRoute.outgoing.length,newRouteLength:designRoute.accepted.length,paintCount:designRoute.paintCount,completedPaintCount:designRoute.completedPaintCount,renderer:designRoute.nativeReady?"native":"inactive"}):({preset:transitionPreset,enabled:emberEnabled,initialized:ember.initialized,animating:ember.animating,transitioning:ember.transitioning,clock:ember.clock,circuitId:ember.circuitId,oldRouteLength:ember.oldRoute.length,newRouteLength:ember.newRoute.length,paintCount:ember.paintCount,completedPaintCount:ember.completedPaintCount,renderer:ember.nativeReady?"native":ember.visible?"unavailable":"inactive"})
  readonly property bool designEnabled:appearance===10||appearance===11
  readonly property real circuitStyleMix:ThemeColors.circuitMix
  readonly property var styleTransitionState:({mix:circuitStyleMix,width:width,radius:screenRadius,centerY:y+height/2,classicKey:ember.acceptedKey,designKey:designRoute.acceptedKey,classicOpacity:ember.opacity,designOpacity:designRoute.opacity,classicClock:ember.clock,designClock:designRoute.clock,classicRevealing:ember.transitioning&&ember.clock<ember.revealDuration,designBuilding:designRoute.building,designRetiring:designRoute.retiring})
  // Both presenters track the same accepted circuit, even while one is hidden.
  // A style change only changes their opacity; only a route/id change reveals it.
  property var classicSettings:null
  property var designSettings:({})
  property int classicAppearance:8
  onEffectSettingsChanged:{if(designEnabled)designSettings=effectSettings||{};else classicSettings=effectSettings}
  onAppearanceChanged:if(appearance!==10&&appearance!==11)classicAppearance=appearance
  function clearPresentation(){ember.clearRoute();designRoute.clear();Qt.callLater(function(){ember.synchronize();designRoute.synchronize()})}
  readonly property bool emberInitialized:ember.initialized
  readonly property bool nativeCircuitRendering:designEnabled?designRoute.nativeReady:ember.nativeReady
  readonly property bool emberEnabled:transitionPreset==="ember"&&(route.length>1||ember.initialized)
  property var effectSettings: null
  readonly property bool softSurface:emberEnabled&&effectSettings&&effectSettings.surfacePreset===Soft.id
  readonly property var surfaceOldRoute:designEnabled?designRoute.outgoing:ember.initialized?ember.oldRoute:route
  readonly property var surfaceNewRoute:designEnabled?designRoute.accepted:ember.initialized?(ember.transitioning?ember.newRoute:ember.acceptedRoute):route
  readonly property real surfaceClock:ember.transitioning?Math.max(0,ember.clock-ember.birthStart):0

  readonly property var colors: Effects.colors(effectSettings,appearance)
  readonly property real configuredZoom: effectSettings && effectSettings.zoom !== undefined ? Math.max(0.65,Math.min(1.6,effectSettings.zoom)) : 1
  property real temporaryZoom: NaN
  readonly property real zoomLevel: isFinite(temporaryZoom) ? temporaryZoom : configuredZoom
  property real presentationScale:appearance===8?.82:1
  readonly property real screenRadius:Math.min(width,height)*.42*zoomLevel*presentationScale
  property var homeCamera: null
  property bool cameraDisplaced: false
  property real idleSeconds: 0
  property real returnElapsed: 0
  property var returnStart: null
  property real cameraIdleDelay: 3
  property real cameraReturnDuration: 4
  onConfiguredZoomChanged:if(!circuitOrbit)temporaryZoom=NaN
  function restartCamera(){
    inspectingRelay=false;inspectionReturning=false;inspectionSaved=null;inspectionTo=null
    temporaryZoom=NaN;cameraDisplaced=false;returnStart=null
    if(circuitOrbit)orbit.restart()
  }
  function rememberCamera() {
    if(circuitOrbit)return
    homeCamera={longitude:longitude,latitude:latitude,roll:viewRoll,automaticRotation:automaticRotation}
    cameraDisplaced=false;returnStart=null;idleSeconds=0;if(isFinite(temporaryZoom))temporaryZoom=NaN
  }
  function interactCamera() {
    if(!cameraDisplaced) {
      if(!homeCamera)rememberCamera()
      cameraDisplaced=true
    }
    idleSeconds=0;returnElapsed=0;returnStart=null
  }
  function zoomCamera(value) {
    if(inspectionCamera){inspectionTo=null;temporaryZoom=Math.max(.65,Math.min(2.5,value));return}
    if(circuitOrbit){orbit.beginInput();if(orbit.inputTarget)orbit.inputTarget=Object.assign({},orbit.inputTarget,{zoom:Math.max(.5,Math.min(2.5,value))});orbit.finishInput();return}
    interactCamera()
    temporaryZoom=Math.max(0.65,Math.min(1.6,value))
  }
  function angleDelta(from,to) { return ((to-from+540)%360+360)%360-180 }
  function advanceCamera(dt) {
    if(!cameraDisplaced || dragging)return
    idleSeconds+=dt
    if(idleSeconds<cameraIdleDelay)return
    if(!returnStart)returnStart={longitude:longitude,latitude:latitude,roll:viewRoll,zoom:zoomLevel}
    returnElapsed+=dt
    var t=Math.min(1,returnElapsed/cameraReturnDuration),e=t*t*(3-2*t)
    longitude=returnStart.longitude+angleDelta(returnStart.longitude,homeCamera.longitude)*e
    latitude=returnStart.latitude+(homeCamera.latitude-returnStart.latitude)*e
    viewRoll=returnStart.roll+angleDelta(returnStart.roll,homeCamera.roll)*e
    temporaryZoom=returnStart.zoom+(configuredZoom-returnStart.zoom)*e
    if(t>=1){automaticRotation=homeCamera.automaticRotation;cameraDisplaced=false;returnStart=null;temporaryZoom=NaN}
  }
  readonly property real cameraElevation: effectSettings && effectSettings.elevation !== undefined ? effectSettings.elevation : NaN
  readonly property int cameraReset: effectSettings && effectSettings.viewReset ? effectSettings.viewReset : 0
  property bool clipToViewport: true
  clip: clipToViewport && zoomLevel>1
  onCameraElevationChanged: if(!circuitOrbit&&!externalCamera&&isFinite(cameraElevation)){latitude=cameraElevation;rememberCamera()}
  // Legacy editor reset counters differ between saved designs. They must not
  // impersonate a user reset of the live orbit camera when selecting a theme.
  onCameraResetChanged:if(!circuitOrbit)Qt.callLater(resetView)
  readonly property bool spinEnabled: !effectSettings || effectSettings.spin === undefined ? true : !!effectSettings.spin
  readonly property real spinRate: effectSettings && effectSettings.spinRate !== undefined ? effectSettings.spinRate : 3.6
  readonly property real axialTilt: !effectSettings || effectSettings.earthTilt === undefined || effectSettings.earthTilt ? 23.44 : 0
  property real viewRoll: 0
  readonly property real sceneRoll: axialTilt+viewRoll
  readonly property real spinDirection: effectSettings && effectSettings.reverse ? -1 : 1
  onAxialTiltChanged: {
    if(circuitOrbit||externalCamera)return
    var center=Geometry.camera(route)
    latitude=isFinite(cameraElevation) ? cameraElevation : axialTilt ? 0 : center ? center.latitude : 22
    rememberCamera()
  }
  readonly property bool dragging: pointer.pressed
  readonly property int renderStatus: sphere.status
  readonly property bool mapReady: mapTexture.status === Image.Ready

  Accessible.role: Accessible.Pane
  Accessible.name: "Rotatable globe"
  Accessible.description: "Ten globe styles with country-level routes. Drag to rotate. Double-click to reset. Arrow keys rotate when focused."

  function resetVisualState() {
    time=0
    for(var i=0;i<effectLayers.count;i++) effectLayers.itemAt(i).phaseTime=0
    resetView()
  }
  function rippleAnchor(index) {
    var v = Geometry.vector(route[index])
    if (!v) return Qt.vector4d(0,0,0,0)
    for (var k=0;k<index;k++) {
      var other=Geometry.vector(route[k])
      if (other && Geometry.dot(v,other)>0.999999) return Qt.vector4d(0,0,0,0)
    }
    return Qt.vector4d(v[0],v[1],v[2],0)
  }
  function dragView(x1,y1,x2,y2) {
    if(inspectionCamera){inspectionTo=null;var r=Math.max(1,sphere.width*.42*zoomLevel);var p=Geometry.dragOrientation(longitude,latitude,sceneRoll,(x1-width/2)/r,(y1-height/2)/r,(x2-width/2)/r,(y2-height/2)/r);longitude=p.longitude;latitude=p.latitude;viewRoll=p.roll-axialTilt;return}
    if(circuitOrbit){var r=Math.max(1,sphere.width*.42*zoomLevel);orbit.drag((x1-width/2)/r,(y1-height/2)/r,(x2-width/2)/r,(y2-height/2)/r);return}
    var radius=Math.max(1,sphere.width*0.42*zoomLevel)
    var next=Geometry.dragOrientation(longitude,latitude,sceneRoll,
        (x1-width/2)/radius,(y1-height/2)/radius,
        (x2-width/2)/radius,(y2-height/2)/radius)
    interactCamera()
    longitude=next.longitude;latitude=next.latitude;viewRoll=next.roll-axialTilt
  }
  function rotate(dx, dy) {
    if(antipodeShown)return
    if(inspectionCamera){inspectionTo=null;longitude+=dx;latitude=Math.max(-80,Math.min(80,latitude+dy));return}
    if(circuitOrbit){orbit.beginInput();if(orbit.inputTarget)orbit.inputTarget=Object.assign({},orbit.inputTarget,{yaw:orbit.inputTarget.yaw+dx,pitch:Math.max(-80,Math.min(80,orbit.inputTarget.pitch+dy))});orbit.finishInput();return}
    interactCamera()
    longitude = ((longitude + dx + 180) % 360 + 360) % 360 - 180
    latitude = Math.max(-75, Math.min(75, latitude + dy))
  }
  function resetView() {
    if(antipodeShown)return
    if(circuitOrbit){orbit.reset();return}
    viewRoll=0
    var center = Geometry.camera(route)
    longitude = center ? center.longitude : -24
    latitude = isFinite(cameraElevation) ? cameraElevation : axialTilt ? 0 : center ? center.latitude : 22
    automaticRotation = !center
    rememberCamera()
  }
  onRouteChanged: if(!antipodeShown&&!animateInitialRoute&&!circuitOrbit&&!externalCamera&&(!emberEnabled||!ember.initialized))resetView()

  Keys.onLeftPressed: rotate(-6, 0)
  Keys.onRightPressed: rotate(6, 0)
  Keys.onUpPressed: rotate(0, -6)
  Keys.onDownPressed: rotate(0, 6)

  // This offline map is uploaded once; rotation only updates shader uniforms.
  // Red stores land, green stores borders. GeoJSON remains available separately
  // for future country selection without parsing it on every popup opening.
  Image {
    id: mapTexture
    source: Qt.resolvedUrl("../../assets/maps/country-map.png")
    visible: false
    smooth: true
    mipmap: true
    onStatusChanged: if (status === Image.Error) console.warn("Tor globe: country map could not be loaded")
  }

  Image {
    id: countryIndex
    source: Qt.resolvedUrl("../../assets/maps/country-index.png")
    visible: false; smooth: false; mipmap: false
  }
  Image {
    id: groundLights
    source: Qt.resolvedUrl(root.appearance === 6 ? "../../assets/images/firefly-lights.png" : "../../assets/images/nightwatch-lights.png")
    visible: false; smooth: true; mipmap: true
  }
  // Project the actual geographic poles through the same camera and scene roll.
  // Two outward rays only. The far-side ray is occluded until it clears the globe.
  Canvas {
    id: polarAxis
    anchors.fill: parent
    z: 2
    visible: root.axialTilt !== 0
    readonly property var north: visible?Geometry.project([0,1,0],root.longitude,root.latitude,sphere.width):null
    readonly property var south: visible?Geometry.project([0,-1,0],root.longitude,root.latitude,sphere.width):null
    property color axisColor: root.colors.borders
    onAxisColorChanged: if(visible)requestPaint()
    property real roll: root.sceneRoll
    property real zoom: root.zoomLevel
    onNorthChanged: if(visible)requestPaint()
    onSouthChanged: if(visible)requestPaint()
    onRollChanged: if(visible)requestPaint()
    onZoomChanged: if(visible)requestPaint()
    onWidthChanged: if(visible)requestPaint()
    onHeightChanged: if(visible)requestPaint()
    onVisibleChanged: if(visible)requestPaint()
    onPaint: {
      if(!visible)return
      var c=getContext("2d");c.reset()
      var dx=(south.x-north.x)*zoom,dy=(south.y-north.y)*zoom
      var length=Math.sqrt(dx*dx+dy*dy)
      if(length<0.01)return // Looking directly along the axis: no projected line.
      var angle=roll*Math.PI/180
      var ux=(dx*Math.cos(angle)-dy*Math.sin(angle))/length
      var uy=(dx*Math.sin(angle)+dy*Math.cos(angle))/length
      var reach=Math.sqrt(width*width+height*height)
      c.strokeStyle=Qt.rgba(axisColor.r,axisColor.g,axisColor.b,0.18)
      c.lineWidth=0.5
      var radius=sphere.width*0.42*zoom
      var northStart=north.z>=0 ? length/2 : radius
      var southStart=south.z>=0 ? length/2 : radius
      c.beginPath()
      c.moveTo(width/2-ux*northStart,height/2-uy*northStart)
      c.lineTo(width/2-ux*reach,height/2-uy*reach)
      c.moveTo(width/2+ux*southStart,height/2+uy*southStart)
      c.lineTo(width/2+ux*reach,height/2+uy*reach)
      c.stroke()
    }
  }
  // Roll the entire geographic scene together: globe, route and wavefronts.
  // With an equatorial camera this shows the spin axis 23.44° from vertical.
  Item {
    id: geographicScene
    anchors.fill: parent
    rotation: root.sceneRoll
    scale: root.zoomLevel
    transformOrigin: Item.Center
  ShaderEffect {
    id: sphere
    objectName:"globe-sphere"
    anchors.centerIn: parent
    width: Math.min(parent.width, parent.height) * root.presentationScale
    height: width
    property real longitude: root.longitude
    property real latitude: root.latitude
    property color accent: root.colors.land
    property color secondary: root.colors.borders
    property color surface: root.colors.ocean
    property color atmosphere: root.colors.atmosphere
    property color lamps: root.colors.lamps
    property vector4d treatment: Qt.vector4d(root.colors.detail,root.colors.atmosphereStrength,root.colors.groundLight,root.colors.grid)
    property color waterTint: root.colors.waterColor
    property color skyTint: root.colors.skyColor
    property color cloudTint: root.colors.cloudColor
    property vector4d waterOptions: Qt.vector4d(root.colors.waterMode,root.colors.waterStrength,root.colors.waterScale,root.colors.waterSpeed)
    property vector4d waterSurface: Qt.vector4d(root.colors.waterRoughness,root.colors.waveHeight,root.colors.waterReflection,0)
    property vector4d skyOptions: Qt.vector4d(root.colors.atmosphereWidth,root.colors.haze,root.colors.layeredAtmosphere?1:0,root.colors.clouds?root.colors.cloudOpacity:0)
    property vector4d skyMotion: Qt.vector4d(root.colors.cloudCoverage,root.colors.cloudSpeed,root.colors.sunAzimuth,root.colors.sunElevation)
    property vector2d borderOptions: Qt.vector2d(root.colors.borderWidth,root.colors.borderLight)
    property real lighting: root.colors.brightness
    property real appearance: root.appearance
    property real time: root.time
    property vector4d relay0: root.rippleAnchor(0)
    property vector4d relay1: root.rippleAnchor(1)
    property vector4d relay2: root.rippleAnchor(2)
    property vector4d relay3: root.rippleAnchor(3)
    property var countryMap: mapTexture
    property var countryIds: countryIndex
    property var groundLightMap: groundLights
    readonly property var surfaceRoute:root.softSurface||root.designEnabled?root.surfaceNewRoute:root.route
    property vector4d mappedCountries:Qt.vector4d(Countries.id((surfaceRoute[0]||{}).country),Countries.id((surfaceRoute[1]||{}).country),Countries.id((surfaceRoute[2]||{}).country),Countries.id((surfaceRoute[3]||{}).country))
    property vector4d departingCountries:Qt.vector4d(Countries.id((root.surfaceOldRoute[0]||{}).country),Countries.id((root.surfaceOldRoute[1]||{}).country),Countries.id((root.surfaceOldRoute[2]||{}).country),Countries.id((root.surfaceOldRoute[3]||{}).country))
    property vector4d surfaceOptions:root.designEnabled?Qt.vector4d(1,designRoute.building?Math.min(1,designRoute.elapsed/designRoute.buildDuration):1,designRoute.retiring?Math.min(1,designRoute.elapsed/designRoute.retireDuration):1,0):Qt.vector4d(root.softSurface?1:0,Soft.progress(root.surfaceClock,true),Soft.progress(root.surfaceClock,false),Soft.config.country.blend)
    property color retiringTint:ThemeColors.color("retiringCountry")
    property real surfaceGlow:root.softSurface?Soft.config.country.glow:0
    readonly property var mapping: root.effectSettings || {}
    readonly property vector4d normalMapOptions: root.softSurface?Qt.vector4d(1,Soft.config.country.fill*5,Soft.config.country.width,Soft.config.country.brightness):Qt.vector4d(mapping.mapBorders ? 1 : 0,mapping.mapFill ? 1 : 0,mapping.mapWidth === undefined ? 1 : mapping.mapWidth,mapping.mapIntensity === undefined ? 0.6 : mapping.mapIntensity)
    property vector4d mapOptions:Qt.vector4d(normalMapOptions.x,normalMapOptions.y,normalMapOptions.z,normalMapOptions.w*root.normalRouteOpacity)
    property color mapTint: mapping.mapColor || (root.softSurface?root.colors.borders:Effects.effectColor({palette:mapping.mapPalette},root.colors.effect))
    property color mapFillTint: mapping.mapFillColor || (root.softSurface?root.colors.land:mapTint)
    property vector2d mapMotion: Qt.vector2d(!root.softSurface&&mapping.mapPulse ? 1 : 0,mapping.mapSpeed === undefined ? 1 : mapping.mapSpeed)
    property real roseAtmosphere:mapping.roseAtmosphere||0
    property color roseTint:ThemeColors.color("roseInk")
    property vector4d clayMaterial:Qt.vector4d((mapping.clayMaterial||[0,1,0,0])[0],(mapping.clayMaterial||[0,1,0,0])[1],(mapping.clayMaterial||[0,1,0,0])[2],(mapping.clayMaterial||[0,1,0,0])[3])
    property vector4d clayShading:Qt.vector4d((mapping.clayShading||[.94,.06,1,0])[0],(mapping.clayShading||[.94,.06,1,0])[1],(mapping.clayShading||[.94,.06,1,0])[2],0)
    fragmentShader: Qt.resolvedUrl(root.appearance===11?"../../assets/shaders/porcelain-globe.frag.qsb":"../../assets/shaders/globe.frag.qsb")
    onStatusChanged: if (status === ShaderEffect.Error) console.warn("Tor globe shader:", log)
  }

  AnimatedRoute {
    opacity:root.normalRouteOpacity
    anchors.centerIn: sphere
    width: sphere.width * (root.appearance >= 8 ? 1.65 : 1)
    height: width
    globeSize: sphere.width
    accent: root.accent
    ink: root.secondary
    visible: root.normalRouteVisible && root.appearance >= 4 && !root.effectSettings
    route: root.route
    longitude: root.longitude; latitude: root.latitude
    appearance: root.appearance
    time: root.time
  }

  EmberRoutes {
    id:ember;objectName:"ember-transition";opacity:root.normalRouteOpacity*(1-root.circuitStyleMix)
    animateInitialRoute:root.animateInitialRoute
    anchors.centerIn:sphere
    renderResolution:Math.min(1,1000/(root.width*1.65))
    width:root.width*1.65*renderResolution;height:width;scale:1/renderResolution
    globeSize:sphere.width;settings:root.classicSettings;appearance:root.classicAppearance
    verifiedRoute:root.route;circuitId:root.circuitId
    visible:(root.emberEnabled||root.circuitStyleMix>0)&&root.circuitStyleMix<1&&root.normalRouteVisible;animating:root.active&&root.visible&&visible&&!root.antipodeShown&&!root.reducedMotion
    longitude:root.longitude;latitude:root.latitude;smoothMotion:root.dragging
  }

  DesignRoutes {
    id:designRoute;objectName:"design-route";anchors.centerIn:sphere;width:root.width*1.65;height:width
    route:root.route;settings:root.designSettings;circuitId:root.circuitId;longitude:root.longitude;latitude:root.latitude;globeSize:sphere.width
    active:root.active&&root.visible&&!root.antipodeShown;visible:root.circuitStyleMix>0&&root.normalRouteVisible;reducedMotion:root.reducedMotion;opacity:root.normalRouteOpacity*root.circuitStyleMix
  }
  Repeater {
    id: effectLayers
    model: [{key:"arcs",mode:8},{key:"packets",mode:9},{key:"ribbon",mode:10},{key:"tunnel",mode:11},{key:"particles",mode:6},{key:"ripples",mode:12}]
    delegate: AnimatedRoute {
      required property var modelData
      opacity:root.normalRouteOpacity
      objectName: "effect-" + modelData.key
      interacting: root.dragging
      readonly property var mix: Object.assign({speed:1,intensity:1,thickness:1,glow:0,palette:0},root.effectSettings || {})
      readonly property var params: Effects.layer(root.effectSettings,modelData.key)
      readonly property var trajectory: Effects.trajectory(root.effectSettings)
      property real phaseTime: 0
      function advance(dt) { if(visible) phaseTime+=dt*params.speed }
      anchors.centerIn: sphere
      width: sphere.width*1.65; height: width
      globeSize: sphere.width
      route: root.route; longitude: root.longitude; latitude: root.latitude
      appearance: modelData.mode
      visible: root.normalRouteVisible && !root.designEnabled && !root.emberEnabled && root.effectSettings !== null && !!mix[modelData.key]
      time: phaseTime
      accent: params.guideColor || root.colors.atmosphere
      ink: params.highlightColor || root.colors.borders
      customColor: Effects.effectColor(params,root.colors.effect)
      colorMix: params.multicolor ? params.colorMix||[] : []
      colorDistribution: params.colorDistribution||"interleaved"
      strength: params.intensity
      strokeScale: params.width
      glowAmount: params.glow
      trajectoryHeight: trajectory.height
      trajectoryProfile: trajectory.profile
      effectCount: Math.max(1,Math.round(params.count))
      segmentLength: params.length
      particleSpread: params.spread
      rippleRadius: params.radius
      tunnelRails: params.rails
      tunnelRings: params.rings
      tunnelCore: params.core
      tunnelStream: params.stream
      tunnelRailCount: Math.max(1,Math.round(params.railCount))
      tunnelRadius: params.tubeRadius
      tunnelStreamCount: Math.max(1,Math.round(params.streamCount))
      tunnelStreamSpeed: params.streamSpeed
      tunnelStreamLength: params.streamLength
      drawLinks: modelData.key !== "ripples"
      drawRipples: modelData.key === "ripples"
    }
  }

  Item {
    id: mapMarkers
    objectName: "map-markers"
    anchors.centerIn: sphere
    width: sphere.width; height: width
    visible: root.normalRouteVisible && !root.softSurface && !!(root.effectSettings && root.effectSettings.mapMarkers)
    readonly property var options: root.effectSettings || {}
    readonly property real markerSize: options.markerSize === undefined ? 3 : options.markerSize
    readonly property color markerColor: options.markerColor || options.mapColor || root.colors.effect
    opacity: root.normalRouteOpacity*(options.markerIntensity === undefined ? 0.8 : options.markerIntensity)
    Repeater {
      model: mapMarkers.visible ? Geometry.markers(root.route,root.longitude,root.latitude,mapMarkers.width) : []
      delegate: Rectangle {
        required property var modelData
        x: modelData.anchorX-width/2; y: modelData.anchorY-height/2
        width: mapMarkers.markerSize; height: width; radius: width/2
        color: mapMarkers.markerColor
        Rectangle {
          anchors.centerIn: parent
          visible: !!mapMarkers.options.markerHalo
          width: parent.width*3; height: width; radius: width/2
          color: mapMarkers.markerColor; opacity: 0.12
        }
      }
    }
  }

  RouteOverlay {
    opacity:root.normalRouteOpacity
    visible: root.normalRouteVisible && root.appearance < 4 && !root.effectSettings
    anchors.centerIn: parent
    width: sphere.width; height: width
    route: root.route
    longitude: root.longitude; latitude: root.latitude
    active: root.active
    appearance: root.appearance
    accent: root.accent
    secondary: root.secondary
    time: root.time
  }

  LocalCircuits {
    anchors.centerIn:sphere;width:sphere.width;height:width
    origin:root.localOrigin;circuits:root.localCircuits;showing:root.localCircuitsShown;reducedMotion:root.reducedMotion
    longitude:root.longitude;latitude:root.latitude;accent:root.accent;secondary:ThemeColors.color("uiText")
  }
  } // geographicScene


  SurfaceMarkers {
    id:surfaceMarkers
    opacity:root.normalRouteOpacity
    objectName:"soft-surface-markers";anchors.fill:parent;visible:root.softSurface&&root.normalRouteVisible
    config:Object.keys(ThemeColors.displayedAuxiliary).length?ThemeColors.displayedAuxiliary:ThemeColors.resolveData(Soft.config);settings:root.effectSettings||{};routeA:root.surfaceOldRoute;routeB:root.surfaceNewRoute;clock:root.surfaceClock
    pose:({yaw:root.longitude,pitch:root.latitude,roll:root.viewRoll,tilt:root.axialTilt,zoom:root.zoomLevel});sphereSize:sphere.width
  }

  FrameAnimation {
    running: root.active && root.visible && !root.antipodeShown && !root.reducedMotion
    onTriggered: {
      var dt=Math.min(frameTime,0.05)
      root.time=(root.time+dt)%3600
      if(ember.visible)ember.advance(dt)
      for(var i=0;i<effectLayers.count;i++) effectLayers.itemAt(i).advance(dt)
      if(root.inspectionCamera){root.advanceInspection(dt);return}
      if(root.circuitOrbit)orbit.tick(dt)
      if(!root.circuitOrbit&&!root.externalCamera&&root.cameraDisplaced)root.advanceCamera(dt)
      // Pointer movement owns orientation during a drag; effects keep advancing.
      if(!root.circuitOrbit && !root.externalCamera && !root.dragging && (root.spinEnabled || root.automaticRotation)) {
        var spinStep=dt*root.spinRate*root.spinDirection
        root.longitude=((root.longitude+spinStep+180)%360+360)%360-180
        // Keep the return target moving with the planet while the user explores.
        if(root.homeCamera)root.homeCamera.longitude+=spinStep
        if(root.returnStart)root.returnStart.longitude+=spinStep
      }
    }
  }

  RelayTargets {
    id:relayTargets;objectName:"relay-targets";anchors.fill:parent
    visible:root.active&&!root.antipodeShown&&!root.localCircuitsShown
    trajectoryHeight:Effects.trajectory(root.effectSettings).height;trajectoryProfile:Effects.trajectory(root.effectSettings).profile
    animatedRows:root.softSurface?surfaceMarkers.rows:null
    route:root.route;longitude:root.longitude;latitude:root.latitude;roll:root.sceneRoll;zoom:root.zoomLevel;sphereSize:sphere.width
    selected:root.selectedRelay;accent:root.accent
    onSelectedHop:hop=>root.relaySelected(hop)
  }
  MouseArea {
    id: pointer
    anchors.fill: parent
    objectName:"globe-pointer"
    enabled: root.active&&!root.antipodeShown&&!root.externalCamera
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: relayTargets.hovered>=0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    property bool routeHovered:false
    CircuitToolTip {route:root.route;hovered:pointer.containsMouse&&!pointer.pressed&&(relayTargets.hovered>=0||pointer.routeHovered);ink:ThemeColors.color("uiText");accent:root.accent}
    property real startX:0
    property real startY:0
    property bool moved:false
    property string pressedFingerprint:""
    property real previousX: 0
    property real previousY: 0
    onPressed: function(mouse) {
      startX=mouse.x;startY=mouse.y;moved=false
      var hit=relayTargets.visible?relayTargets.hit(mouse.x,mouse.y):-1
      pressedFingerprint=hit>=0?relayTargets.points[hit].hop.fingerprint:""
      previousX = mouse.x
      previousY = mouse.y
      if(!root.inspectionCamera){if(root.circuitOrbit)orbit.beginInput();else root.interactCamera()}
      root.forceActiveFocus()
    }
    onPositionChanged: function(mouse) {
      relayTargets.hovered=relayTargets.visible?relayTargets.hit(mouse.x,mouse.y):-1
      routeHovered=relayTargets.visible&&relayTargets.hitRoute(mouse.x,mouse.y)
      if (!pressed) return
      if(!moved&&Math.hypot(mouse.x-startX,mouse.y-startY)<Qt.styleHints.startDragDistance)return
      moved=true
      root.dragView(previousX,previousY,mouse.x,mouse.y)
      previousX = mouse.x
      previousY = mouse.y
    }
    onWheel: function(wheel) {
      var steps=wheel.angleDelta.y!==0 ? wheel.angleDelta.y/120 : wheel.pixelDelta.y/40
      if(steps!==0){if(root.inspectionCamera)root.zoomCamera(root.zoomLevel*Math.pow(1.1,steps));else if(root.circuitOrbit)orbit.wheel(steps,pointer.pressed);else root.zoomCamera(root.zoomLevel*Math.pow(1.1,steps))}
      wheel.accepted=true
    }
    onExited:relayTargets.hovered=-1
    onReleased:mouse=>{root.idleSeconds=0;if(root.circuitOrbit&&!root.inspectionCamera)orbit.finishInput()
      if(!moved){var hit=relayTargets.visible?relayTargets.hit(mouse.x,mouse.y):-1
        if(hit>=0&&relayTargets.points[hit].hop.fingerprint===pressedFingerprint)relayTargets.activate(hit)
        else if(hit<0)root.backgroundClicked()
      }
    }
    onCanceled:{root.idleSeconds=0;if(root.circuitOrbit&&!root.inspectionCamera)orbit.finishInput()}
    onDoubleClicked: root.resetView()
  }
}
