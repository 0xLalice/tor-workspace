"""The runtime reads one published configuration, never the builder draft library."""
import json
import os
import re
from pathlib import Path
import time
from preset_schema import validate

ACTIVE = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'omarchy/tor-workspace/published.json'
BUILTINS = Path(__file__).resolve().parents[1]/'assets/themes'
DEFAULT = Path(__file__).resolve().parents[1]/'assets/themes/original.json'


def validate_publication(value):
    if 'themes' not in value:
        return [validate(value)]
    entries=value['themes']
    if not isinstance(entries,list) or not entries:raise ValueError('Publish at least one theme')
    entries=[validate(entry) for entry in entries]
    if len({entry['id'] for entry in entries})!=len(entries):raise ValueError('Duplicate theme ids')
    return entries


def builtins():
    names=json.loads((BUILTINS.parent/'theme-catalog.json').read_text())
    if not names or any(not isinstance(name,str) or not re.fullmatch(r'[a-zA-Z0-9_-]+',name) for name in names): raise ValueError('Invalid theme catalog')
    paths=[BUILTINS/(name+'.json') for name in names]
    return validate_publication({'themes':[json.loads(path.read_text()) for path in paths]})

def merge_entries(entries):
    saved={entry['id']:entry for entry in entries}
    bundled=builtins()
    # Retain publications on disk, but retire the old built-in light design.
    saved.pop('porcelain', None)
    return [dict(saved.pop(entry['id'],entry), name=entry['name']) for entry in bundled]+list(saved.values())

class PublishedTheme:
    def __init__(self, path=ACTIVE):
        self.path = Path(path)
        self.entries = builtins()
        self.last_good = self.entries[0]
        self.active_id = ''
        self.activation = ''

    def read(self):
        error = ''
        try:
            value=json.loads((self.path if self.path.exists() else DEFAULT).read_text())
            self.entries = merge_entries(validate_publication(value))
            self.active_id=value.get('activeId','')
            if self.active_id == 'porcelain': self.active_id = 'meridian'
            self.activation=value.get('activation','')
            first_id=validate_publication(value)[0]['id']
            if first_id == 'porcelain': first_id = 'meridian'
            self.last_good = next((entry for entry in self.entries if entry['id']==(self.active_id or first_id)), self.entries[0])
        except (ValueError, OSError, TypeError, AttributeError) as exc:
            error = str(exc)
        return dict(preset=self.last_good, entries=self.entries, error=error,activeId=self.active_id,activation=self.activation)


if __name__ == '__main__':
    store = PublishedTheme()
    previous = None
    while True:
        value = json.dumps(store.read(), sort_keys=True)
        if value != previous:
            print(value, flush=True)
            previous = value
        time.sleep(.5)
