#!/usr/bin/python3
"""Password-free client; no root commands and no direct-network fallback."""
import array
import fcntl
import json
import os
import pty
from pathlib import Path
import select
import signal
import socket
import sys
import termios
import tty


def request(action,argv=None):
    if action!='start':
        gateway=Path('/run/omarchy-tor-native')/(str(os.getuid())+'-io')/'control'
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as probe:
            probe.settimeout(2)
            try:probe.connect(str(gateway))
            except OSError as error:raise RuntimeError('Tor is off. Choose Start Tor in the plugin first.') from error
    connection=socket.socket(socket.AF_UNIX,socket.SOCK_SEQPACKET)
    connection.settimeout(190)
    try:
        connection.connect('/run/omarchy-tor-session-'+str(os.getuid())+'/launch.sock')
    except OSError as error:
        raise RuntimeError('Tor session is not installed or available. Complete first-time setup; no ordinary app was launched.') from error
    if action=='start':
        connection.send(json.dumps({'action':'start'}).encode())
        result=json.loads(connection.recv(65536));connection.close()
        if not result.get('ok'): raise RuntimeError(result.get('error','Tor startup failed'))
        return 0
    master,slave=pty.openpty()
    payload=json.dumps({'action':action,'argv':argv,'env':dict(os.environ),'cwd':os.getcwd()}).encode()
    if len(payload)>65536: raise RuntimeError('Launch environment is too large')
    connection.sendmsg([payload],[(socket.SOL_SOCKET,socket.SCM_RIGHTS,array.array('i',[slave]))])
    os.close(slave)
    original=termios.tcgetattr(0) if os.isatty(0) else None
    def resize(*_):
        if original:
            size=fcntl.ioctl(0,termios.TIOCGWINSZ,b'\0'*8)
            fcntl.ioctl(master,termios.TIOCSWINSZ,size)
    previous=signal.signal(signal.SIGWINCH,resize)
    resize()
    if original: tty.setraw(0)
    try:
        readers=[connection,master,0]
        while True:
            readable,_,_=select.select(readers,[],[])
            if master in readable:
                try: output=os.read(master,65536)
                except OSError: output=b''
                if output: os.write(1,output)
                else: readers.remove(master)
            if 0 in readable:
                data=os.read(0,65536)
                if data: os.write(master,data)
                else: readers.remove(0)
            if connection in readable:
                data=connection.recv(65536)
                if not data: raise RuntimeError('Tor session disconnected')
                result=json.loads(data)
                if not result.get('ok'): raise RuntimeError(result.get('error','Launch failed'))
                return result.get('exitCode',1)
    finally:
        if original: termios.tcsetattr(0,termios.TCSADRAIN,original)
        signal.signal(signal.SIGWINCH,previous)
        os.close(master);connection.close()


if __name__=='__main__':
    try:
        action=sys.argv[1]
        args=['/bin/bash','-i'] if action=='shell' else sys.argv[2:]
        sys.exit(request('run' if action=='shell' else action,args))
    except (OSError,ValueError,RuntimeError) as error:
        print('Tor workspace: '+str(error),file=sys.stderr)
        sys.exit(1)
