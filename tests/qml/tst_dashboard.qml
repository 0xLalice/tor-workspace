import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
  name: "TorDashboard"; when: windowShown; visible: true; width: 400; height: 668
  Rectangle { anchors.fill: parent; color: "#09110d" }
  Tor.TorDashboard {
    id: dashboard
    x: 22; y: 22; width: 356; height: 624
    active: true; state: "ready"; canChange: true
    route: [
      {role:"You",country:"TH",countryName:"Thailand",longitude:101,latitude:15},
      {role:"Guard",country:"DE",countryName:"Germany",longitude:10,latitude:51},
      {role:"Middle",country:"DE",countryName:"Germany",longitude:10,latitude:51},
      {role:"Exit",country:"CH",countryName:"Switzerland",longitude:8,latitude:47}]
  }
  SignalSpy { id: changes; target: dashboard; signalName: "newCircuit" }
  function test_publishedThemeChooser() {
    verify(findChild(dashboard,"theme-action")!==null)
    mouseClick(findChild(dashboard,"theme-action"))
    tryCompare(findChild(dashboard,"published-theme-chooser"),"opened",true)
    findChild(dashboard,"published-theme-chooser").close()
  }
  function test_layouts_data() { return [{tag:"eclipse",style:0},{tag:"orbital",style:1},{tag:"bloom",style:2},{tag:"nightwatch",style:3}] }
  function test_layouts(data) {
    dashboard.appearance=data.style
    wait(180)
    compare(dashboard.globe.mapReady,true)
    compare(dashboard.globe.renderStatus,ShaderEffect.Compiled)
    grabImage(this).save("/tmp/tor-dashboard-"+data.tag+".png")
  }
  function test_actionGuard() {
    changes.clear()
    dashboard.canChange=false
    mouseClick(findChild(dashboard,"compact-circuit-action"))
    compare(changes.count,0)
    dashboard.canChange=true
    mouseClick(findChild(dashboard,"compact-circuit-action"))
    compare(changes.count,1)
  }
}
