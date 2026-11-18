"""Exercise real process failures, payloads and FIFO recovery without a desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Requires Quickshell')
class ServiceTransportTests(unittest.TestCase):
    def run_transport(self, executable, commands, expected, allowed=True):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shutil.copy2(ROOT/'ui/shell/ServiceTransport.qml', root/'ServiceTransport.qml')
            worker = root/'worker.py'
            worker.write_text('''import json,sys,time
payload=json.loads(sys.stdin.readline())
action=sys.argv[1]
time.sleep(.05)
if action=='malformed': print('invalid')
elif action=='empty': pass
elif action=='failed': print(json.dumps({'state':'error','error':'Backend rejected request'}));sys.exit(7)
else: print(json.dumps({'action':action,'payload':payload}))
''')
            (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import %s as Runtime
ShellRoot {
 property var results:[]
 Runtime.ServiceTransport {
  id:transport;script:%s;executable:%s;startAllowed:%s
  onReceived:value=>results=results.concat([value])
  onFailed:message=>results=results.concat([{error:message}])
 }
 Component.onCompleted:{%s}
 Timer {interval:900;running:true;onTriggered:{console.log("RESULT "+JSON.stringify(results));Qt.quit()}}
}
''' % (json.dumps('.'), json.dumps(str(worker)), json.dumps(executable),
       str(allowed).lower(), commands))
            result = subprocess.run(['quickshell', '--path', str(root)], capture_output=True,
                                    text=True, timeout=10, env=dict(os.environ, QT_QPA_PLATFORM='offscreen'))
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertNotIn('TypeError', log)
            line = next((line.split('RESULT ', 1)[1] for line in log.splitlines() if 'RESULT ' in line), None)
            self.assertIsNotNone(line, log)
            values = json.loads(line)
            self.assertEqual(len(values), len(expected), log)
            for actual, wanted in zip(values, expected):
                if wanted == 'error':
                    self.assertTrue(actual.get('error'), actual)
                else:
                    self.assertEqual(actual, wanted)

    def test_bad_responses_do_not_strand_commands_or_lose_payload(self):
        self.run_transport('/usr/bin/python3', """
          transport.send('malformed');transport.send('empty');transport.send('failed');
          transport.send('stop',{id:'quoted " id',files:['ü file']});
        """, ['error', 'error', {'state':'error','error':'Backend rejected request'},
              {'action':'stop','payload':{'id':'quoted " id','files':['ü file']}}])

    def test_missing_executable_drains_requests_with_errors(self):
        self.run_transport('/missing/tor-test-python', "transport.send('start');transport.send('stop')",
                           ['error', 'error'])

    def test_start_is_rechecked_when_dequeued_and_status_does_not_queue(self):
        self.run_transport('/usr/bin/python3', """
          transport.send('status');transport.send('status');transport.send('start');
          transport.send('stop');transport.startAllowed=false;
        """, [{'action':'status','payload':{}}, 'error', {'action':'stop','payload':{}}])
