import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 name:"FileShare";when:windowShown;visible:true;width:500;height:700
 Tor.TorDashboard {id:panel;anchors.fill:parent;showLaunchControls:true;showPowerControls:true;state:"ready";route:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:46},{country:"US",longitude:-100,latitude:40}];torRunning:true}
 SignalSpy {id:resume;target:panel;signalName:"shareResumeChanged"}
 SignalSpy {id:starts;target:panel;signalName:"shareStartRequested"}
 SignalSpy {id:retries;target:panel;signalName:"shareRetryRequested"}
 SignalSpy {id:dismisses;target:panel;signalName:"shareDismissRequested"}
 SignalSpy {id:stops;target:panel;signalName:"shareStopRequested"}
 function test_dialog(){
  panel.openShare();var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true)
  panel.shareChoosing=true;panel.shareSelection=["/tmp/100% ready.txt"]
  compare(starts.count,1);compare(starts.signalArguments[0][0][0],"/tmp/100% ready.txt")
  panel.shareState={api:2,shares:[{id:"a",name:"100% ready.txt",size:123,state:"ready",url:"http://example.onion"},{id:"b",name:"Preparing.txt",state:"starting",message:"Publishing onion link…",url:""}],readyCount:1}
  wait(60)
  verify(findChild(panel,"share-active-dot").visible)
  var list=findChild(dialog,"share-list");compare(list.count,2)
  compare(findChild(list.contentItem,"share-progress-b").text,"Publishing onion link…")
  var copy=findChild(list.contentItem,"share-copy-a");verify(copy.enabled)
  verify(!findChild(list.contentItem,"share-copy-b").enabled)
  mouseClick(copy);compare(copy.text,"Copied")
  dialog.close();compare(stops.count,0)
  panel.openShare();tryCompare(dialog,"opened",true);waitForRendering(panel)
  mouseClick(findChild(list.contentItem,"share-stop-a"));compare(stops.count,1);compare(stops.signalArguments[0][0],"a")
  panel.shareState={api:2,shares:[],readyCount:0};tryCompare(list,"count",0);panel.torRunning=false
  verify(!findChild(panel,"share-active-dot").visible)
  verify(!findChild(dialog,"share-choose").enabled)
  dialog.close()
 }
 function test_failed_rows_scroll_and_palettes(){
  panel.torRunning=true;panel.interfaceVariation=0
  var entries=[]
  for(var i=0;i<12;i++)entries.push({id:"file"+i,name:i===0?"A very long <filename> with spaces and unicode — final report.pdf":"Document "+i+".txt",size:12345,state:i===0?"error":"ready",message:"Sharing ended unexpectedly. Retry.",url:"http://example.onion"})
  panel.shareState={api:2,shares:entries,readyCount:11};panel.openShare()
  var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true);wait(80)
  var list=findChild(dialog,"share-list");verify(list.contentHeight>list.height)
  compare(findChild(list.contentItem,"share-progress-file0").text,"Sharing ended unexpectedly. Retry.")
  mouseClick(findChild(list.contentItem,"share-retry-file0"));compare(retries.count,1)
  mouseClick(findChild(list.contentItem,"share-stop-file0"));compare(dismisses.count,1)
  var bg=panel.background,ink=panel.ink,accent=panel.accent
  panel.background="#101713";panel.ink="#e1e4d0";panel.accent="#c0bd83";wait(40)
  grabImage(this).save("/tmp/tor-share-list-dark.png")
  panel.background="#f6f4ee";panel.ink="#202721";panel.accent="#336b50";wait(40)
  grabImage(this).save("/tmp/tor-share-list-light.png")
  list.positionViewAtEnd();verify(list.contentY>0)
  panel.background=bg;panel.ink=ink;panel.accent=accent;dialog.close()
 }
 function test_picker_survives_connection_recheck(){
  starts.clear();panel.torRunning=true;panel.serviceAvailable=true
  panel.shareState={api:2,shares:[],readyCount:0};panel.openShare()
  var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true)
  mouseClick(findChild(dialog,"share-choose"));verify(panel.shareChoosing)
  panel.serviceAvailable=false
  verify(panel.shareChoosing,"A connection check cannot cancel an external file picker")
  panel.shareSubmitting=true;panel.shareSelection=["/tmp/selected during recheck.txt"]
  tryCompare(dialog,"opened",true);compare(starts.count,0)
  compare(findChild(dialog,"share-status").text,"Waiting for a Tor circuit…")
  verify(!findChild(dialog,"share-choose").enabled)
  panel.serviceAvailable=true;verify(dialog.opened);compare(starts.count,1)
  compare(starts.signalArguments[0][0][0],"/tmp/selected during recheck.txt")
  panel.shareSubmitting=false;dialog.close();starts.clear()
 }
 function test_waiting_selection_is_cancelled_on_close_or_power_off(){
  var dialog=findChild(panel,"file-share-dialog")
  for(var stop of [false,true]){
   starts.clear();panel.torRunning=true;panel.serviceAvailable=true;panel.shareChoosing=true
   panel.serviceAvailable=false;panel.shareSelection=["/tmp/not-yet-shared.txt"]
   tryCompare(dialog,"opened",true);compare(starts.count,0)
   if(stop)panel.torRunning=false;else dialog.close()
   compare(panel.pendingShareSelection.length,0)
   panel.torRunning=true;panel.serviceAvailable=true
   compare(starts.count,0,"Restoring Tor must not publish a cancelled selection")
   tryCompare(dialog,"visible",false)
  }
 }
 function test_theme_alignment_and_add(){
  panel.torRunning=true;panel.shareState={api:2,shares:[],readyCount:0};panel.openShare()
  var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true)
  var header=findChild(dialog,"share-header"),footer=findChild(dialog,"share-footer"),group=findChild(dialog,"share-add-group"),card=findChild(dialog,"share-choose")
  verify(header.centered);compare(footer.horizontalAlignment,Text.AlignHCenter);waitForPolish(group)
  verify(Math.abs(card.x+(card.width/2)-(group.width/2))<1);compare(findChild(card,"action-card-surface").width,40);compare(findChild(card,"action-card-surface").height,40)
  panel.interfaceSettings=Object.assign({},panel.interfaceSettings,{fileSharing:{titleAlignment:"left",footerAlignment:"left",addAlignment:"left"}})
  verify(!header.centered);compare(footer.horizontalAlignment,Text.AlignLeft);compare(card.x,0)
  panel.interfaceSettings=Object.assign({},panel.interfaceSettings,{fileSharing:{titleAlignment:"center",footerAlignment:"center",addAlignment:"center"}})
  mouseClick(card);tryCompare(dialog,"visible",false);verify(panel.shareChoosing)
  panel.shareChoosing=false
 }
 function test_resume_option_and_distinct_actions(){
  panel.torRunning=true;panel.serviceAvailable=true;panel.shareState={api:2,autoResume:false,shares:[{id:"active",name:"Shared.txt",state:"ready",size:20,url:"http://example.onion"},{id:"paused",name:"Waiting.txt",state:"paused",message:"Waiting for Tor · resumes automatically",url:""}],readyCount:1}
  panel.openShare();var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true);wait(50)
  compare(findChild(dialog,"share-auto-resume"),null)
  var list=findChild(dialog,"share-list"),copy=findChild(list.contentItem,"share-copy-active"),stop=findChild(list.contentItem,"share-stop-active")
  compare(copy.kind,"copy");compare(stop.kind,"stop");verify(copy.width>=40&&stop.height>=40)
  verify(findChild(list.contentItem,"share-progress-active").text.indexOf("Sharing")===0)
  verify(!findChild(list.contentItem,"share-copy-paused").enabled)
  verify(findChild(list.contentItem,"share-progress-active").color!==findChild(list.contentItem,"share-progress-paused").color)
  dialog.close();tryCompare(dialog,"visible",false)
  panel.openOptions();var options=findChild(panel,"tor-options");tryCompare(options,"opened",true)
  var option=findChild(options,"options-resume-sharing");compare(option.checked,false);mouseClick(option);compare(resume.count,1);compare(resume.signalArguments[0][0],true)
  options.close()
 }
 function test_layouts(){for(var i=0;i<15;i++){panel.interfaceVariation=i;verify(findChild(panel,"launch-tor-share")!==null)}}
 function test_failed_stop_can_be_retried(){
  stops.clear();panel.torRunning=true;panel.serviceAvailable=true
  panel.shareState={api:2,shares:[{id:"failedstop",name:"File.txt",state:"stopping",stopFailed:true,message:"Could not stop sharing. Retry Stop.",url:""}],readyCount:0}
  panel.openShare();var dialog=findChild(panel,"file-share-dialog");tryCompare(dialog,"opened",true);wait(60)
  var button=findChild(findChild(dialog,"share-list").contentItem,"share-stop-failedstop")
  verify(button.enabled);mouseClick(button);compare(stops.count,1);dialog.close()
 }
}
