import ".."
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Commons as Omarchy
import "../theme/EffectSettings.js" as Effects
import "../theme/BuiltinThemes.js" as Builtins
import "../theme/ThemeNames.js" as ThemeNames
import "../theme/SoftIllumination.js" as Soft

Item {
  id:root
  visible:false
  required property string pluginPath
  property bool pythonAvailable:false
  property bool animate:false
  property string error:""
  property alias selectedId:themeSelection.selectedId
  readonly property var pendingPalette:paletteGate.pending
  readonly property var appliedShell:paletteGate.appliedShell
  signal themeChanging()
  Settings {
    id:themeSelection
    location:"file://"+(Quickshell.env("XDG_CONFIG_HOME")||Quickshell.env("HOME")+"/.config")+"/omarchy/tor-workspace.ini"
    category:"PublishedThemes"
    property string selectedId:""
    property string appliedActivation:""
  }
  property var publishedThemes:Builtins.entries
  readonly property var namedThemes:ThemeNames.entries(publishedThemes,ThemeColors.themeId)
  readonly property var namedTheme:ThemeNames.present(appliedTheme,ThemeColors.themeId)
  property var appliedTheme: {
    var selected = themeSelection.selectedId === "porcelain" ? "meridian" : themeSelection.selectedId
    for (var theme of publishedThemes) {
      if (theme.id === selected) return Effects.snapshot(theme)
    }
    return Effects.snapshot(publishedThemes[0])
  }
  Process {
    id:themeWatcher
    command:["python3","-B",root.pluginPath+"backend/published_theme.py"]
    running:root.pythonAvailable
    stdout:SplitParser {
      onRead:data=>{
        try {
          var value=JSON.parse(data)
          root.error=value.error||""
          if(value.entries&&value.entries.length)root.publishedThemes=value.entries
          if(value.activeId&&value.activation&&value.activation!==themeSelection.appliedActivation) {
            themeSelection.selectedId=value.activeId
            themeSelection.appliedActivation=value.activation
          }
        } catch(e) {
          root.error=String(e)
        }
      }
    }
  }
  onAppliedThemeChanged: {
    themeChanging()
    ThemeDesign.apply(appliedTheme.interface||{})
    baseSessionSettings=ThemeDesign.definition.softIllumination?Soft.adopt(appliedTheme.settings):appliedTheme.settings
    ThemeColors.overrides=appliedTheme.colorOverrides||{}
  }
  property var baseSessionSettings: ThemeDesign.definition.softIllumination?Soft.adopt(appliedTheme.settings):appliedTheme.settings
  Binding {target:ThemeColors;property:"settingsSource";value:root.baseSessionSettings}
  Binding {target:ThemeColors;property:"auxiliarySource";value:Soft.config}
  Binding {target:ThemeColors;property:"animationEnabled";value:root.animate}
  readonly property var sessionSettings: ThemeColors.displayedSettings
  // Files are staged before Omarchy applies its shell colors. Keep them pending
  // until Omarchy.Color.loadShell has committed the matching palette; never drive or
  // delay the shell's own theme/background machinery.
  PaletteGate {id:paletteGate;onPaletteReady:value=>ThemeColors.receivePalette(value)}
  function shellPaletteApplied(){
    paletteGate.shellApplied({background:String(Omarchy.Color.background),foreground:String(Omarchy.Color.foreground),accent:String(Omarchy.Color.accent)})
  }
  Connections {
    target:Omarchy.Color
    function onShellValuesChanged(){root.shellPaletteApplied()}
  }
  Process {
    id: paletteWatcher
    command: ["python3", "-B", root.pluginPath+"backend/palette.py", "--watch"]
    running: root.pythonAvailable
    stdout: SplitParser { onRead: data => { try { paletteGate.receive(JSON.parse(data)) } catch(e) {} } }
  }
  Component.onCompleted:shellPaletteApplied()
}
