#!/usr/bin/python3
"""Unprivileged, socket-activated application launcher inside the Tor namespace."""
import array
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import pwd
import select
import signal
import socket
import struct
import subprocess
import sys
import termios
import time

LIMIT = 65536


def validate(request, descriptors, uid):
    if not isinstance(request,dict) or request.get('action') not in ('start','run','browser'):
        raise ValueError('Unsupported session request')
    if request['action'] == 'start':
        if descriptors:
            raise ValueError('Unexpected file descriptors')
        return
    if len(descriptors) != 1 or not os.isatty(descriptors[0]):
        raise ValueError('Exactly one PTY is required; network descriptors are forbidden')
    argv = request.get('argv')
    if not isinstance(argv,list) or not argv or not all(isinstance(v,str) and '\0' not in v for v in argv):
        raise ValueError('Invalid application arguments')
    env = request.get('env')
    if not isinstance(env,dict) or not all(isinstance(k,str) and isinstance(v,str) and '=' not in k and '\0' not in k+v for k,v in env.items()):
        raise ValueError('Invalid environment')
    if not isinstance(request.get('cwd'),str) or not request['cwd'].startswith('/'):
        raise ValueError('Invalid working directory')
    if os.getuid() != uid or os.geteuid() == 0:
        raise RuntimeError('Refusing privileged application execution')


def handle(connection):
    descriptors=[]
    try:
        _, uid, _ = struct.unpack('3i',connection.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
        if uid != os.getuid():
            raise PermissionError('Session belongs to a different user')
        connection.settimeout(10)
        data, ancillary, flags, _ = connection.recvmsg(LIMIT,socket.CMSG_SPACE(16*4))
        for level,kind,raw in ancillary:
            if level == socket.SOL_SOCKET and kind == socket.SCM_RIGHTS:
                values=array.array('i');values.frombytes(raw[:len(raw)//values.itemsize*values.itemsize]);descriptors.extend(values)
        if flags & (socket.MSG_TRUNC|socket.MSG_CTRUNC):
            raise ValueError('Request too large')
        request=json.loads(data)
        validate(request,descriptors,uid)
        connection.settimeout(None)
        if request['action']=='start':
            connection.send(json.dumps({'ok':True,'uid':uid,'network':os.readlink('/proc/self/ns/net')}).encode())
            return
        if not controller_ready():
            raise RuntimeError('Tor controller is initializing. Try launching again shortly.')
        account=pwd.getpwuid(uid)
        env=dict(request['env'])
        env.update(HOME=account.pw_dir,USER=account.pw_name,LOGNAME=account.pw_name,
                   SHELL='/bin/bash',TOR_WORKSPACE='omarchy-tor-'+str(uid))
        for key in list(env):
            if key.lower() in ('http_proxy','https_proxy','all_proxy','ftp_proxy','no_proxy') or key.startswith('LISTEN_'):
                env.pop(key,None)
        # Keep the real desktop/session environment. The network namespace and
        # host firewall provide routing; application sandboxes must remain usable.
        def prepare_child():
            os.setsid()
            fcntl.ioctl(0,termios.TIOCSCTTY,0)
        with launch_policy():
            process=subprocess.Popen(request['argv'],env=env,cwd=request['cwd'],
                                     stdin=descriptors[0],stdout=descriptors[0],stderr=descriptors[0],
                                     close_fds=True,preexec_fn=prepare_child)
        os.close(descriptors.pop())
        while process.poll() is None:
            if select.select([connection],[],[],0.2)[0]:
                # Disconnection/cancellation must not leave an unattended launch.
                connection.recv(1)
                os.killpg(process.pid,signal.SIGHUP)
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid,signal.SIGKILL);process.wait()
                return
        connection.send(json.dumps({'ok':True,'exitCode':process.returncode}).encode())
    except Exception as error:
        try: connection.send(json.dumps({'ok':False,'error':str(error)}).encode())
        except OSError: pass
    finally:
        for fd in descriptors:
            os.close(fd)
        connection.close()


def controller_ready():
    # Import only the root-owned installed modules, including under Python -I.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from exit_controller import rpc, ready
    state = rpc()
    return ready(state, state.get('exitCountry'))


@contextmanager
def launch_policy():
    """Serialize the final policy check and spawn against country changes.

    Read the snapshot under the shared lock: RPC while locked could deadlock
    against a controller already waiting for the exclusive policy lock.
    """
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import backend
    from exit_controller import ready, preferences
    with (backend.DATA / 'policy.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_SH)
        state = json.loads((backend.RUNTIME / 'controller-state.json').read_text())
        if (not ready(state, preferences()['country'])
                or state.get('gatewayGeneration') != backend.gateway_generation()
                or not 0 <= time.time() - state.get('heartbeat', 0) <= 5):
            raise RuntimeError('Tor country policy is not ready. Try launching again shortly.')
        yield


def start_controller():
    return subprocess.Popen(['/usr/bin/python3', '-I', str(Path(__file__).with_name('exit_controller.py'))],
                            close_fds=True)


def main():
    if os.getuid()==0:
        raise RuntimeError('The session launcher must run unprivileged')
    if os.environ.get('LISTEN_FDS')!='1' or int(os.environ.get('LISTEN_PID','0'))!=os.getpid():
        raise RuntimeError('Start through the installed systemd socket')
    namespace=Path('/run/netns/omarchy-tor-'+str(os.getuid()))
    if os.stat('/proc/self/ns/net').st_ino!=namespace.stat().st_ino:
        raise RuntimeError('Refusing to launch outside the Tor namespace')
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    controller = start_controller()
    listener=socket.socket(fileno=3)
    children = set()
    while True:
        if controller.poll() is not None:
            time.sleep(1)
            controller = start_controller()
        for child in list(children):
            try:
                if os.waitpid(child, os.WNOHANG)[0]: children.remove(child)
            except ChildProcessError: children.discard(child)
        if not select.select([listener], [], [], 0.25)[0]: continue
        # Acknowledge Start as soon as this isolated service is active. The
        # observer's metadata readiness must not hold the power control hostage.
        # Application requests still check the observer before launching.
        connection,_=listener.accept()
        pid=os.fork()
        if pid==0:
            listener.close()
            signal.signal(signal.SIGCHLD,signal.SIG_DFL)
            handle(connection)
            os._exit(0)
        children.add(pid)
        connection.close()


if __name__=='__main__':
    main()
