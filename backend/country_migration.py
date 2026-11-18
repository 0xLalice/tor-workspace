"""One-time preference migration. Never selects relays or performs routing recovery.

Caller holds policy.lock. With a live gateway, commit only after authenticated
SETCONF succeeds. A failed or interrupted migration is safe to retry.
"""
import json
import backend


def migrate(control=None):
    from exit_controller import API, atomic, preferences
    target = backend.DATA / 'country-policy.json'
    if target.exists():
        prefs = preferences()
        if not any(path.exists() for path in (backend.DATA/'exit-policy.json', backend.DATA/'exit-country.json', backend.RUNTIME/'recovery.json')):
            return prefs
    else:
        old = backend.DATA / 'exit-policy.json'
        older = backend.DATA / 'exit-country.json'
        if old.exists():
            country = json.loads(old.read_text()).get('country', '')
        elif older.exists():
            country = json.loads(older.read_text())
        else:
            country = ''
        prefs = dict(api=API, country=backend.validate_country(country))
    if control is not None:
        restriction = '{' + prefs['country'].lower() + '}' if prefs['country'] else '""'
        control.command('SETCONF ExitNodes=' + restriction + ' StrictNodes=1')
    atomic(target, prefs)
    for path in (backend.DATA / 'exit-policy.json', backend.DATA / 'exit-country.json',
                 backend.DATA / 'panel-state.json', backend.RUNTIME / 'recovery.json',
                 backend.RUNTIME / 'state.json', backend.RUNTIME / 'controller-state.json'):
        path.unlink(missing_ok=True)
    return prefs
