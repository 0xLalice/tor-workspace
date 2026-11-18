"""Real Quickshell process queues; replace external commands, show no windows."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from package_test import artifact


@unittest.skipUnless(os.environ.get('WAYLAND_DISPLAY') and shutil.which('quickshell') and Path('/usr/share/omarchy/shell/Ui').is_dir(), 'Requires Omarchy Wayland; no windows are shown')
class RuntimeServicesTests(unittest.TestCase):
    def run_runtime(self, scenario, checks="", available=True, palette=False, service_ready=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = artifact(root / 'plugin')
            harness = root / 'harness'
            harness.mkdir()
            for name in ('Ui', 'Commons'):
                (harness / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
            binaries = root / 'bin'
            binaries.mkdir()
            calls = root / 'calls.jsonl'
            python = binaries / 'python3'
            python.write_text('''#!/usr/bin/python3
import json,sys,time
from pathlib import Path
args=[a for a in sys.argv[1:] if a!='-B']
with Path(%s).open('a') as out:out.write(json.dumps(args)+'\\n')
time.sleep(.15)
print(json.dumps({'ready':False,'pythonAvailable':True,'state':'offline','running':False,'shares':[]}))
''' % repr(str(calls)))
            if service_ready:
                script = python.read_text().replace(
                    "print(json.dumps({'ready':False", """if args[0].endswith('/backend.py'):
 print(json.dumps(dict(state='ready',running=True,serviceReady=True,heartbeat=time.time(),exitCountry='',appliedCountry='',route=[])))
 sys.exit()
print(json.dumps({'ready':False""")
                python.write_text(script)
            if palette:
                script = python.read_text()
                script = script.replace("time.sleep(.15)", """if args[0].endswith('/palette.py'):
 print(json.dumps(dict(themeId='old',background='#111111',foreground='#eeeeee',accent='#aabbcc')),flush=True)
 time.sleep(.5)
 print(json.dumps(dict(themeId='next',background='#eeeeee',foreground='#111111',accent='#112233')),flush=True)
 time.sleep(10)
 sys.exit()
time.sleep(.15)""")
                python.write_text(script)
            python.chmod(0o755)
            (harness / 'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.Commons as Omarchy
import %s as Tor
ShellRoot {
 Loader {id:widget;source:%s}
 Timer {interval:2000;running:true;onTriggered:{
  if(!widget.item||!widget.item.dashboardLoaded){console.log("BOOTSTRAP_FAILED");Qt.quit();return}
  widget.item.installation={ready:false,pythonAvailable:%s,nativeReady:false}
  var runtime=widget.item.children[0].item
  runtime.connection={state:"offline",running:false,route:[]}
  %s
  finish.start()
 }}
 Timer {id:finish;interval:1200;onTriggered:{
  var runtime=widget.item.children[0].item
  %s
  stopped.start()
 }}
 Timer {id:stopped;interval:500;onTriggered:Qt.quit()}
}
''' % (json.dumps((source / "ui").as_uri()), json.dumps((source / 'ui/shell/BarWidget.qml').as_uri()), str(available).lower(), scenario, checks))
            result = subprocess.run(['quickshell', '--path', str(harness)], env=dict(
                os.environ, QT_QPA_PLATFORM='wayland', XDG_CONFIG_HOME=str(root / 'config'),
                XDG_STATE_HOME=str(root / 'state'), PATH=str(binaries) + ':' + os.environ['PATH']),
                capture_output=True, text=True, timeout=15)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertNotIn('FAILED', log)
            for error in ('ReferenceError', 'TypeError'):
                self.assertNotIn(error, log)
            commands = [json.loads(line) for line in calls.read_text().splitlines()]
            return commands, log

    def test_rejected_queued_starts_do_not_strand_stop(self):
        commands, _ = self.run_runtime("""
          for(var service of ['share','chat','host']){
            runtime[service+'Command']('status')
            runtime[service+'Command']('start',{})
            runtime[service+'Command']('stop',{})
          }
        """)
        for service in ('share', 'chat', 'host'):
            actions = [args[1] for args in commands if args and args[0].endswith('/' + service + '.py')]
            self.assertEqual(actions, ['status', 'stop'], (service, commands))

    def test_incomplete_setup_blocks_tor_start_but_allows_stop(self):
        commands, _ = self.run_runtime(
            "runtime.controlTor('start');runtime.controlTor('stop')")
        actions = [args[1] for args in commands
                   if args and args[0].endswith('/lifecycle.py')]
        self.assertEqual(actions, ['stop'], commands)

    def test_fresh_status_response_does_not_drop_availability(self):
        self.run_runtime("""
          widget.item.installation={ready:true,pythonAvailable:true,nativeReady:false}
          var now=Date.now()/1000
          runtime.clockNow=now
          runtime.connectionCheckedAt=now-1
          runtime.connection={state:'ready',running:true,serviceReady:true,
            heartbeat:now-1,exitCountry:'',appliedCountry:'',route:[]}
          if(!runtime.serviceAvailable)console.log('FAILED initial availability')
          runtime.serviceAvailableChanged.connect(function(){
            if(!runtime.serviceAvailable)console.log('FAILED fresh response disabled actions')
          })
          runtime.refresh('status')
        """, """
          if(!runtime.serviceAvailable)console.log('FAILED response availability')
        """, service_ready=True)

    def test_missing_python_is_reported_for_every_command(self):
        _, log = self.run_runtime("""
          runtime.shareCommand('stop');runtime.chatCommand('status');runtime.hostCommand('start')
        """, """
          for(var service of ['share','chat','host']){
            if(!runtime[service+'State'].error)console.log('FAILED missing executable error: '+service)
          }
        """, available=False)

    def test_actual_shell_signal_releases_staged_palette(self):
        self.run_runtime("""
          if(Tor.ThemeColors.themeId!=='old')console.log('FAILED staged palette applied early: '+Tor.ThemeColors.themeId)
          Omarchy.Color.loadColors('background = "#eeeeee"\\nforeground = "#111111"\\naccent = "#112233"')
          Omarchy.Color.loadShell('')
        """, """
          if(Tor.ThemeColors.themeId!=='next')console.log('FAILED shell palette was not applied: '+Tor.ThemeColors.themeId)
        """, palette=True)
