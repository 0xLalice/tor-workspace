import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"NativeModules";when:windowShown;visible:true;width:500;height:600
 Tor.EmberTransition {id:circuit;width:400;height:400;globeSize:300;animating:false;newRoute:[{longitude:101,latitude:15},{longitude:10,latitude:51},{longitude:2,latitude:47},{longitude:-77,latitude:39}]}
 Tor.ExitLights {id:lights;width:400;height:400;points:[{id:"one",country:"DE",longitude:10,latitude:51,phase:0}]}
 Tor.PerformanceMonitor {id:performance;monitoring:true;panelActive:true;showHud:false}
 function cleanup(){Tor.RenderCapabilities.nativeReady=false}
 function test_modules_load_only_after_readiness(){
  failOnWarning(/.*/)
  verify(!circuit.nativeReady);verify(!lights.rendererLoaded);compare(performance.probe,null)
  Tor.RenderCapabilities.nativeReady=true
  tryCompare(circuit,"nativeReady",true)
  tryCompare(lights,"rendererLoaded",true)
  tryVerify(()=>performance.probe!==null)
  wait(100)
  verify(lights.geometryUploads>0)
  Tor.RenderCapabilities.nativeReady=false
  tryCompare(circuit,"nativeReady",false);tryCompare(lights,"rendererLoaded",false);compare(performance.probe,null)
 }
}
