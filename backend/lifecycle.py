#!/usr/bin/env python3
"""Explicit, unprivileged gateway controls. Opening the panel never calls these."""
import json
import subprocess
import sys
import time
import backend
from exit_controller import atomic


def start():
    subprocess.run(['python3','-I','/usr/local/lib/omarchy-tor/client.py','start'],check=True,timeout=190)
    return {'state':'starting','running':True,'route':[],'message':'Connecting to Tor…'}


def stop():
    try:
        with backend.Controller() as control:
            backend.prepare()
            marker = backend.RUNTIME / 'stopped-generation'
            marker.write_text(backend.gateway_generation())
            try:
                control.command('SIGNAL HALT')
            except (ConnectionResetError, BrokenPipeError):
                # Tor can close the control stream while acknowledging HALT.
                # Keep the stop marker and verify socket shutdown below.
                pass
            except RuntimeError as error:
                if str(error) != 'Tor control connection closed':
                    marker.unlink(missing_ok=True)
                    raise
            except Exception:
                marker.unlink(missing_ok=True)
                raise
    except (FileNotFoundError,ConnectionRefusedError,ConnectionResetError,BrokenPipeError,RuntimeError):
        pass
    for _ in range(50):
        try:
            with backend.Controller() as control:control.command('GETINFO status/bootstrap-phase')
        except (FileNotFoundError,ConnectionRefusedError):
            backend.prepare();value=backend.offline();atomic(backend.RUNTIME/'controller-state.json', value);return value
        except (ConnectionResetError, BrokenPipeError):
            pass  # A reset is transitional, not proof that Tor has stopped.
        except RuntimeError as error:
            if str(error) != 'Tor control connection closed':
                raise
        time.sleep(.1)
    (backend.RUNTIME / 'stopped-generation').unlink(missing_ok=True)
    raise RuntimeError('Tor did not stop; retry Stop Tor.')


if __name__=='__main__':
    try:
        action=sys.argv[1]
        if action not in ('start','stop'):raise ValueError('Expected start or stop')
        print(json.dumps(start() if action=='start' else stop()))
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:
        try:running=backend.request('cached').get('running',False)
        except (OSError,ValueError,RuntimeError):running=True
        print(json.dumps({'state':'error','running':running,'route':[],'message':str(error),'lifecycleError':True}))
        sys.exit(1)
