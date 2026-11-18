import QtQuick
import QtTest
import "../../ui" as Tor
import "../../ui/theme/ThemeNames.js" as Names
import "../../ui/theme/BuiltinThemes.js" as Builtins

TestCase {
 name:"ThemeNames";when:windowShown
 property var source:Builtins.entries
 property string selectedId:"meridian"
 readonly property var selected:source.find(theme=>theme.id===selectedId)
 readonly property var named:Names.entries(source,Tor.ThemeColors.themeId)
 readonly property var current:Names.present(selected,Tor.ThemeColors.themeId)
 SignalSpy {id:selectionChanges;target:parent;signalName:"selectedChanged"}
 function test_palette_changes_rename_without_reapplying_or_mutating(){
  var previous=Tor.ThemeColors.palette,saved=JSON.stringify(source),preset=selected
  selectionChanges.clear()
  try {
   for(var palette of ["osaka-jade","jade-horse","catppuccin","tokyo-night","catppuccin-latte","matte-black","flexoki-light","vantablack","nord","kanagawa","gruvbox","everforest","ristretto","rose-pine","ethereal","hackerman","last-horizon","lumon","lupine","miasma","retro-82","solitude","white","custom","","osaka-jade"]){
    Tor.ThemeColors.palette={themeId:palette}
    var expected=(palette==="osaka-jade"||palette==="jade-horse")?["Osaka Classic","Jade Orbit"]:palette==="catppuccin"?["Catppuccin Frost","Mocha Bloom"]:palette==="tokyo-night"?["Tokyo Dusk","Night Ember"]:palette==="catppuccin-latte"?["Latte Cloud","Catppuccin Bloom"]:palette==="matte-black"?["Matte Ember","Black Lantern"]:palette==="flexoki-light"?["Flexoki Ink","Light Orbit"]:palette==="vantablack"?["Vanta Eclipse","Black Orbit"]:palette==="nord"?["Nord Frost","Aurora Orbit"]:palette==="kanagawa"?["Kanagawa Wave","Edo Lantern"]:palette==="gruvbox"?["Gruvbox Copper","Patina Orbit"]:palette==="everforest"?["Everforest Mist","Woodland Haze"]:palette==="ristretto"?["Ristretto Roast","Crema Orbit"]:palette==="rose-pine"?["Rose Nebula","Pine Mist"]:palette==="ethereal"?["Ethereal Starlight","Astral Ember"]:palette==="hackerman"?["Hackerman Signal","Neon Grid"]:palette==="last-horizon"?["Horizon Dusk","Last Light"]:palette==="lumon"?["Lumon Frost","Severed Blue"]:palette==="lupine"?["Lupine Sky","Blossom Drift"]:palette==="miasma"?["Miasma Veil","Stone Reverie"]:palette==="retro-82"?["Retro Groove","Vinyl Drift"]:palette==="solitude"?["Solitude Silver","Quiet Parchment"]:palette==="white"?["White Graphite","Chalk Orbit"]:["default1","default2"]
    compare(named.map(theme=>theme.name).join("|"),expected.join("|"))
    compare(current.name,expected[1]);compare(current.id,"meridian")
    compare(named[0].settings,source[0].settings)
    compare(selected,preset);compare(selectionChanges.count,0)
    compare(JSON.stringify(source),saved)
   }
  } finally {Tor.ThemeColors.palette=previous}
 }
 function test_reviewed_palettes(){compare(Object.keys(Names.reviewed).sort().join(","),"catppuccin,catppuccin-latte,ethereal,everforest,flexoki-light,gruvbox,hackerman,jade-horse,kanagawa,last-horizon,lumon,lupine,matte-black,miasma,nord,osaka-jade,retro-82,ristretto,rose-pine,solitude,tokyo-night,vantablack,white")}
 function test_saved_settings_and_custom_publications_survive(){
  var saved={id:"original",name:"Old saved label",settings:{zoom:1.23},interface:{layout:9}}
  var result=Names.present(saved,"catppuccin")
  compare(result.name,"Catppuccin Frost");compare(result.settings,saved.settings);compare(result.interface,saved.interface)
  compare(saved.name,"Old saved label")
  compare(Names.present({id:"personal",name:"Personal"},"catppuccin").name,"Personal")
 }
}
