import ".."
import QtQuick
import QtQuick.Controls
OverlayPanel {
 id:root;objectName:"tor-options"
 property var update:({})
 property bool updateBusy:false
 property bool resumeSharing:false
 property bool resumeNeedsRestart:false
 signal resumeSharingChangedByUser(bool enabled)
 property bool diagnosticsEnabled:false
 property bool diagnosticsHud:true
 property var monitor:null
 property var shortcuts:({})
 property bool shortcutBusy:false
 signal updateRequested()
 signal updateCheckRequested()
 signal shortcutsRequested()
 signal shortcutChanged(string action,string key)
 signal diagnosticsChanged(bool value)
 signal hudChanged(bool value)
 height:Math.min(parent.height-24,body.implicitHeight+2*padding)
 onOpened:shortcutsRequested()
 contentItem:ScrollView {
  clip:true;contentWidth:availableWidth
  OverlayBody {
   id:body;width:parent.width
   OverlayHeader {id:header;title:"Options";closeName:"";ink:root.ink;accent:root.accent;onClosed:root.close()}
   ShortcutRow {bindings:root.shortcuts.bindings||{};busy:root.shortcutBusy;ink:root.ink;accent:root.accent;onChanged:(action,key)=>root.shortcutChanged(action,key)}
   Text {width:parent.width;visible:!!text;text:root.shortcuts.error||"";wrapMode:Text.WordWrap;color:root.accent;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(11)}
   OverlayToggle {
    objectName:"options-resume-sharing";width:parent.width;height:40;text:"Resume sharing with Tor";checked:root.resumeSharing;ink:root.ink;accent:root.accent
    onClicked:root.resumeSharingChangedByUser(checked)
    ToolTip.visible:hovered;ToolTip.text:root.resumeNeedsRestart?"Restart older active shares once to enable resume.":"Resume files with new links after Tor reconnects. Off by default."
   }
   OverlayToggle {text:"Performance diagnostics";checked:root.diagnosticsEnabled;ink:root.ink;accent:root.accent;onClicked:root.diagnosticsChanged(checked)}
   OverlayToggle {visible:root.diagnosticsEnabled;text:"Show FPS overlay";checked:root.diagnosticsHud;ink:root.ink;accent:root.accent;onClicked:root.hudChanged(checked)}
   ActionCardRow {
    ActionCard {objectName:"update-action";visible:root.update.available===true;kind:"refresh";text:"Update";ink:root.ink;accent:root.accent;onClicked:root.updateRequested()}
    ActionCard {visible:!!root.update.error&&!root.update.available;kind:"refresh";text:"Retry check";enabled:!root.updateBusy;ink:root.ink;accent:root.accent;onClicked:root.updateCheckRequested()}
    ActionCard {visible:root.diagnosticsEnabled;kind:"record";text:root.monitor&&root.monitor.recording?"Recording…":"Capture 60s";enabled:root.monitor&&!!root.monitor.probe&&!root.monitor.recording;ink:root.ink;accent:root.accent;onClicked:{root.monitor.capture(60);root.close()}}
   }
   Text {visible:root.diagnosticsEnabled;width:parent.width;wrapMode:Text.WrapAnywhere;color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);text:root.monitor&&root.monitor.probe?(root.monitor.probe.error||root.monitor.probe.lastCapture||""):"Frame probe unavailable."}
  }
 }
}
