import QtQuick
import QtTest
import "../../ui" as Tor
TestCase {
 id:test;name:"NoteSchedule";when:windowShown;visible:true;width:400;height:300
 Tor.RotatingTorNote {id:note;x:40;y:40;width:320;height:120;active:false;reducedMotion:true;initialDelay:80;displayDuration:130;interval:30000}
 function init(){failOnWarning(/.*/);note.active=false;note.visible=true;note.paused=false;note.cyclingEnabled=true;note.reducedMotion=true;note.phraseIndex=0;note.shownOnce=false;note.displayDuration=130;findChild(note,"cycling-note-timer").interval=Qt.binding(()=>note.showing?note.displayDuration:note.firstAppearance?note.initialDelay:note.cycleInterval);mouseMove(test,390,290);note.active=true}
 function cleanup(){note.active=false}
 function test_automatic_appearance_and_quiet(){
  verify(!note.showing);tryCompare(note,"showing",true)
  compare(note.phraseIndex,0);tryCompare(note,"showing",false)
  compare(findChild(note,"cycling-note-presence").opacity,0)
  verify(!findChild(note,"cycling-tor-action").visible)
  verify(!note.lightAnimating);verify(!note.drifting)
  wait(200);verify(!note.showing,"Quiet period between notes")
  // Shorten the same running timer, without waiting a minute in the suite.
  var timer=findChild(note,"cycling-note-timer");timer.interval=Qt.binding(()=>note.showing?note.displayDuration:80);timer.restart()
  tryCompare(note,"showing",true);compare(note.phraseIndex,1)
  tryCompare(note,"showing",false);tryCompare(note,"showing",true);compare(note.phraseIndex,2)
 }
 function test_paused_and_hidden(){
  note.paused=true;wait(200);verify(!note.showing)
  note.paused=false;tryCompare(note,"showing",true)
  note.paused=true;wait(200);verify(note.showing,"Keep the note while its overlay is open")
  note.active=false;verify(!note.showing);verify(!findChild(note,"cycling-note-timer").running)
  var previous=note.phraseIndex
  note.active=true;note.paused=false;tryCompare(note,"showing",true);compare(note.phraseIndex,previous+1)
  note.visible=false;verify(!note.showing);verify(!findChild(note,"cycling-note-timer").running)
 }
 function test_reading_keeps_note_available(){
  note.showNote(false);var action=findChild(note,"cycling-tor-action")
  mouseMove(action,action.width/2,action.height/2);wait(200);verify(note.showing)
  mouseMove(test,390,290);tryCompare(note,"showing",false)
  note.showNote(false);action.forceActiveFocus();wait(200);verify(note.showing)
  action.focus=false;tryCompare(note,"showing",false)
 }
 function test_manual_note_still_expires(){
  note.cyclingEnabled=false;wait(200);verify(!note.showing)
  note.next();verify(note.showing);tryCompare(note,"showing",false)
  verify(!findChild(note,"cycling-note-timer").running)
 }
 function test_fade_and_animation_lifecycle(){
  note.reducedMotion=false;note.paused=true;note.displayDuration=2000;note.paused=false
  tryCompare(note,"showing",true)
  var presence=findChild(note,"cycling-note-presence")
  tryVerify(()=>presence.opacity>0&&presence.opacity<1)
  verify(note.lightAnimating)
  tryCompare(presence,"opacity",1)
  note.hideNote();verify(!note.lightAnimating);verify(!findChild(note,"cycling-tor-action").animating)
  tryCompare(presence,"opacity",0);verify(!presence.visible)
  note.displayDuration=130
 }
}
