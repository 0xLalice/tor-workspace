"""Readiness and the actual Quickshell bootstrap, without installed native modules."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from package_test import ROOT, artifact, module

SHELL_ROOT = Path(os.environ.get("OMARCHY_TEST_SHELL_ROOT", "/usr/share/omarchy/shell"))

readiness=module('readiness',ROOT/'install/setup_status.py')

class InstallationTests(unittest.TestCase):
    def test_tor_version_requires_fixed_stable_release(self):
        for version, supported in [('0.4.9.11',False),('0.4.9.13',False),('0.4.9.14',True),('0.4.10.1',True)]:
            with self.subTest(version=version),patch.object(readiness.subprocess,'check_output',return_value='Tor version '+version+'.\nTor is running on Linux.'):
                actual, issue=readiness.tor_version_status()
                self.assertEqual(actual,version);self.assertEqual(not issue,supported)
        for output in ('', 'Tor version 0.4.9.14-alpha.', 'unrecognized output'):
            with self.subTest(output=output),patch.object(readiness.subprocess,'check_output',return_value=output):
                self.assertTrue(readiness.tor_version_status()[1])
        with patch.object(readiness.subprocess,'check_output',side_effect=subprocess.TimeoutExpired('tor',5)):
            self.assertTrue(readiness.tor_version_status()[1])

    def test_old_tor_is_reported_as_unfinished_setup(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(readiness.shutil,'which',return_value='/usr/bin/tool'),patch.object(readiness,'native_issues',return_value=[]),patch.object(readiness.subprocess,'check_output',return_value='Tor version 0.4.9.11.'),patch.object(readiness.subprocess,'run',return_value=subprocess.CompletedProcess([],0)):
            state=readiness.status(Path(folder),Path(folder),Path(folder),1001)
        self.assertFalse(state['ready'])
        self.assertEqual(state['torVersion'],'0.4.9.11')
        self.assertTrue(any('Update Tor to 0.4.9.14' in issue for issue in state['issues']))

    def test_clean_machine_check_does_not_mutate(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            with patch.object(readiness.shutil,'which',return_value=None),patch.object(readiness.subprocess,'run',return_value=subprocess.CompletedProcess([],3)),patch.object(readiness.subprocess,'check_output',return_value='qt6-base 6.11.2-1'):
                state=readiness.status(root,root,root,1001)
            self.assertFalse(state['ready']);self.assertFalse(state['nativeReady'])
            self.assertIn('tor',state['missing'])
            self.assertEqual(list(root.iterdir()),[])

    def test_qt_and_architecture_changes_require_rebuild(self):
        with tempfile.TemporaryDirectory() as folder:
            root=artifact(Path(folder)/'plugin');digest=readiness.native_source_hash(root)
            for name,binary in readiness.MODULES.items():
                directory=root/'build/qml'/name;directory.mkdir(parents=True)
                (directory/binary).write_bytes(b'fixture')
                (directory/'build-info.json').write_text(json.dumps(dict(api=1,qt='6.11.2',architecture='x86_64',sources=digest)))
            self.assertEqual(readiness.native_issues(root,'6.11.3','x86_64'),[])
            self.assertEqual(len(readiness.native_issues(root,'6.12.0','x86_64')),3)
            self.assertEqual(len(readiness.native_issues(root,'6.11.2','aarch64')),3)

    def test_old_workspace_include_migrates_without_duplicates(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=artifact(root/'source');config=root/'config'
            hypr=config/'hypr/hyprland.lua';hypr.parent.mkdir(parents=True)
            hypr.write_text('dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/tor.workspace/workspace.lua")\n')
            installer=module('migration_installer',source/'install/install-user.py')
            installer.install(source,config,False)
            self.assertNotIn('tor.workspace/workspace.lua',hypr.read_text())
            self.assertEqual(hypr.read_text().count('integration/workspace.lua'),1)
            self.assertIn('if tor_file then',hypr.read_text())

class BootstrapTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('WAYLAND_DISPLAY') and shutil.which('quickshell') and (SHELL_ROOT/'Ui').is_dir(),'Requires Omarchy Wayland; the harness shows no windows')
    def test_unbuilt_dashboard_and_agent_prompt(self):
        self.run_handoff("installation")

    @unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and shutil.which("quickshell"), "Requires Omarchy Wayland")
    def test_update_starts_dispatcher_in_independent_service(self):
        self.run_handoff("update")

    def run_handoff(self, purpose):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=artifact(root/'plugin');harness=root/'harness';harness.mkdir()
            self.assertFalse(list(source.rglob('*.so')))
            config=root/'config';publication=config/'omarchy/tor-workspace/published.json'
            publication.parent.mkdir(parents=True)
            theme=json.loads((source/'assets/themes/original.json').read_text())
            theme['name']='Saved layout';theme['interface']['layout']=11
            publication.write_text(json.dumps(theme))
            for name in ('Ui','Commons'):(harness/name).symlink_to(SHELL_ROOT/name)
            binaries=root/'bin';binaries.mkdir();capture=root/'args.json'
            mock=binaries/'omarchy'
            mock.write_text('#!/usr/bin/python3\nimport json,sys,os\nfrom pathlib import Path\nPath('+repr(str(capture))+').write_text(json.dumps(dict(args=sys.argv[1:],cwd=os.getcwd())))\n');mock.chmod(0o755)
            service=binaries/'systemd-run'
            service.write_text('#!/bin/bash\nwhile [[ $1 == --* ]]; do shift; done\nexec "$@"\n');service.chmod(0o755)
            if purpose == 'update':
                service.write_text('#!/usr/bin/python3\nimport json,os,sys\nfrom pathlib import Path\nPath('+repr(str(capture))+').write_text(json.dumps(dict(args=sys.argv[1:],cwd=os.getcwd())))\n')
            (harness/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
 Loader {id:widget;source:%s}
 Timer {interval:2000;running:true;onTriggered:{
  if(!widget.item||!widget.item.dashboardLoaded){console.log("BOOTSTRAP_FAILED");Qt.quit();return}
  // Match the host bar's writable property injection on a fresh clone.
  widget.item.moduleName="tor.workspace";widget.item.settings={};
  var runtime=widget.item.children[0].item
  function named(item,name){if(item.objectName===name)return item;for(var child of item.children||[]){var hit=named(child,name);if(hit)return hit}return null}
  var launcher=named(runtime,"tor-workspace-marker");if(launcher)launcher.serviceRunning=false;
  var onion=named(runtime,"tor-workspace-onion");
  if(!launcher||launcher.width!==runtime.width||launcher.height!==runtime.height){console.log("BAR_GEOMETRY_FAILED");Qt.quit();return}
  if(launcher.componentSourceBounds!==undefined &&
     (launcher.componentSourceBounds.width<=0||launcher.componentSourceBounds.height<=0||
      Math.abs(launcher.opticalCenterErrorX)>.1||Math.abs(launcher.opticalCenterErrorY)>.1)){
    console.log("BAR_GEOMETRY_FAILED");Qt.quit();return
  }
  if(!onion||onion.circuitReady||onion.opacity<.65||onion.idleOpacity!==1){console.log("BAR_LAUNCHER_FAILED");Qt.quit();return}
  if(runtime.setupStatus.ready||runtime.appliedTheme.name!=="Osaka Classic"||runtime.appliedTheme.interface.layout!==11){console.log("SAVED_LAYOUT_FAILED");Qt.quit();return}
  runtime.connectionCheckedAt=101;runtime.clockNow=102;
  runtime.connection={api:3,running:true,state:"ready",serviceReady:true,policyReady:true,exitCountry:"US",appliedCountry:"US",verifiedCountry:"US",heartbeat:101,route:[]};
  if(!runtime.serviceAvailable){console.log("READY_POLICY_FAILED");Qt.quit();return}
  runtime.connection=Object.assign({},runtime.connection,{state:"starting",policyReady:false,circuitId:"",route:[]});
  if(!runtime.serviceAvailable){console.log("IDLE_AVAILABILITY_FAILED");Qt.quit();return}
  runtime.clockNow=103;
  if(!runtime.serviceAvailable){console.log("FRESH_REOPEN_FAILED");Qt.quit();return}
  runtime.clockNow=112;
  if(runtime.serviceAvailable){console.log("STALE_STATUS_FAILED");Qt.quit();return}
  runtime.clockNow=102;runtime.connection=Object.assign({},runtime.connection,{appliedCountry:"JP"});
  if(runtime.serviceAvailable){console.log("POLICY_MISMATCH_FAILED");Qt.quit();return}
  runtime.connection=Object.assign({},runtime.connection,{appliedCountry:"US",heartbeat:0});
  if(runtime.serviceAvailable){console.log("STALE_HEARTBEAT_FAILED");Qt.quit();return}
  console.log("BOOTSTRAP_READY");%s;finish.start()
 }}
 Timer {id:finish;interval:800;onTriggered:Qt.quit()}
}
''' % (json.dumps((source/'ui/shell/BarWidget.qml').as_uri()), 'runtime.updateStatus={canUpdate:true,revision:"reviewed-revision"};runtime.applyUpdate()' if purpose=="update" else "widget.item.installWithAgent()"))
            result=subprocess.run(['quickshell','--path',str(harness)],env=dict(os.environ,QT_QPA_PLATFORM='wayland',XDG_CONFIG_HOME=str(config),PATH=str(binaries)+':'+os.environ['PATH']),capture_output=True,text=True,timeout=15)
            log=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,log);self.assertIn('BOOTSTRAP_READY',log);self.assertNotIn('BAR_LAUNCHER_FAILED',log);self.assertNotIn('BAR_GEOMETRY_FAILED',log)
            for error in ('unavailable','No such file','ReferenceError','TypeError'):self.assertNotIn(error,log)
            captured=json.loads(capture.read_text());args=captured['args']
            self.assertEqual(Path(captured['cwd']),source)
            if purpose == "update":
                self.assertEqual(args[-5:-1], ['python3','-B',str(source/'install/update-session.py'),'reviewed-revision'])
                self.assertIn('reviewed-revision', args[-1])
                self.assertNotIn('tui', args)
                return
            self.assertEqual(args[:2],['launch','tui'])
            self.assertEqual(args[3],str(source/'install/agent-session.sh'))
            self.assertIn('docs/INSTALL.md',args[4]);self.assertIn(str(source),args[4])
            expected=next(line[2:] for line in (ROOT/'README.md').read_text().splitlines() if line.startswith('> I just installed')).replace('<path>',str(source)+'/')
            self.assertEqual(args[4],expected)
