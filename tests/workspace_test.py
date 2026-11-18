"""Execute the shipped Lua integration against a minimal compositor API."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from package_test import ROOT


@unittest.skipUnless(shutil.which('lua'), 'Requires Lua')
class WorkspaceTests(unittest.TestCase):
    def run_lua(self, config, migrate=False):
        fixture = '''
local rules,moves,timers = {},{},{}
local windows={{address="abc",workspace={id=6,name="6"}},
               {address="def",workspace={id=2,name="2"}}}
hl={
 get_windows=function() return windows end,
 get_active_workspace=function() return {id=6,name="6"} end,
 workspace_rule=function(rule) table.insert(rules,rule) end,
 timer=function(callback) table.insert(timers,callback) end,
 dispatch=function(action) table.insert(moves,action) end,
 dsp={window={move=function(args) return args end},focus=function(args) return args end}
}
o={window=function(pattern,rule) assert(rule.workspace=="name:Tor") end}
'''
        checks = '''
assert(rules[1].workspace=="name:Tor" and rules[1].persistent)
for _,callback in ipairs(timers) do callback() end
'''
        if migrate:
            checks += '''
assert(#rules==2 and rules[2].workspace=="6" and rules[2].persistent==false)
assert(#moves==2 and moves[1].window=="address:abc")
assert(moves[1].workspace=="name:Tor" and moves[1].follow==false)
assert(moves[2].workspace=="name:Tor")
'''
        else:
            checks += 'assert(#rules==1 and #moves==0 and #timers==0)\n'
        result = subprocess.run(['lua','-'],input=fixture+'\ndofile('+repr(str(ROOT/'integration/workspace.lua'))+')\n'+checks,
                                text=True,capture_output=True,env=dict(os.environ,XDG_CONFIG_HOME=str(config)))
        self.assertEqual(result.returncode,0,result.stderr)

    def test_numbered_workspace_migrates_once_without_touching_other_windows(self):
        with tempfile.TemporaryDirectory() as folder:
            config=Path(folder);(config/'omarchy').mkdir()
            state=config/'omarchy/tor-workspace-number';state.write_text('6\n')
            self.run_lua(config,migrate=True)
            self.assertFalse(state.exists())
            self.run_lua(config)

    def test_fresh_install_has_no_numbered_slot_or_move_handlers(self):
        with tempfile.TemporaryDirectory() as folder:
            config=Path(folder);(config/'omarchy').mkdir()
            self.run_lua(config)
            self.assertEqual(list((config/'omarchy').iterdir()),[])

    def test_invalid_saved_number_is_retired_without_moving_windows(self):
        with tempfile.TemporaryDirectory() as folder:
            config=Path(folder);(config/'omarchy').mkdir()
            state=config/'omarchy/tor-workspace-number';state.write_text('-2')
            self.run_lua(config)
            self.assertFalse(state.exists())
