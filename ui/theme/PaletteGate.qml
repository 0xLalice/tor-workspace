import QtQuick

QtObject {
 id:root
 property var pending:null
 property var appliedShell:null
 property bool initialized:false
 signal paletteReady(var value)
 function receive(value){pending=value;Qt.callLater(flush)}
 function shellApplied(value){appliedShell=value;Qt.callLater(flush)}
 function matches(value,shell){
  return shell&&["background","foreground","accent"].every(function(key){return String(value[key]).toLowerCase()===String(shell[key]).toLowerCase()})
 }
 function flush(){
  if(!pending)return
  // Startup has no prior visible palette. Subsequent staged files must wait
  // for Omarchy's applied shell colors, whichever notification arrives first.
  if(initialized&&!matches(pending,appliedShell))return
  var next=pending;pending=null;initialized=true;paletteReady(next)
 }
}
