#!/usr/bin/python3
"""Root-only network setup, invoked solely by the installed systemd unit."""
import importlib.util
import os
from pathlib import Path
import pwd
import sys
sys.dont_write_bytecode = True

if os.geteuid()!=0:
    raise SystemExit('This setup is managed by systemd')
uid=int(sys.argv[1])
account=pwd.getpwuid(uid)
if uid<1000 or not Path('/etc/omarchy-tor/users',str(uid)).is_file():
    raise SystemExit('User is not enrolled for Tor workspace')
spec=importlib.util.spec_from_file_location('native',Path(__file__).with_name('network.py'))
native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
native.UID=uid
native.NS='omarchy-tor-'+str(uid)
native.STATE=Path('/run/omarchy-tor-native')/(str(uid)+'.json')
native.CONFIG=Path('/etc/netns')/native.NS
native.up()
