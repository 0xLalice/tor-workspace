#!/usr/bin/env python3
"""Validate exported JSON themes at the plugin boundary."""
import re
import hashlib
import math
import json
from pathlib import Path

STYLE = json.loads((Path(__file__).resolve().parents[1]/"assets/theme-style.json").read_text())

def validate_style(value):
    if not isinstance(value, dict): raise ValueError("Invalid presentation style")
    for key, item in value.items():
        if key not in STYLE["defaults"]: raise ValueError("Unknown presentation setting: "+key)
        default=STYLE["defaults"][key]
        numeric=type(default) in (int,float)
        if (numeric and (type(item) not in (int,float) or not math.isfinite(item))) or (not numeric and type(item) is not type(default)):
            raise ValueError("Invalid presentation setting: "+key)
        if key in STYLE["enums"] and item not in STYLE["enums"][key]: raise ValueError("Invalid presentation choice: "+key)
        if key in STYLE["ranges"] and not STYLE["ranges"][key][0]<=item<=STYLE["ranges"][key][1]: raise ValueError("Presentation setting out of range: "+key)
        if key in STYLE["integers"] and (not numeric or item != int(item)): raise ValueError("Invalid presentation integer: "+key)
        if key=="paletteProfile" and not re.fullmatch(r"[a-zA-Z0-9_-]+",item): raise ValueError("Invalid palette profile")
    return value



def validate(value):
    if not isinstance(value, dict) or value.get('version') not in (1, 2):
        raise ValueError('Expected preset schema version 1 or 2')
    if not isinstance(value.get('name'), str) or not value['name'].strip():
        raise ValueError('Preset name is required')
    if 'id' not in value:
        value=dict(value,id='legacy-'+hashlib.sha256(value['name'].encode()).hexdigest()[:16])
    elif not isinstance(value['id'],str) or not value['id'].strip():
        raise ValueError('Invalid theme id')
    if type(value.get('appearance')) is not int or not 0 <= value['appearance'] <= 11:
        raise ValueError('Appearance must be an integer from 0 to 11')
    if not isinstance(value.get('settings'), dict):
        raise ValueError('Settings must be an object')
    def walk(item):
        if isinstance(item, float) and not math.isfinite(item):
            raise ValueError('Non-finite numeric setting')
        if isinstance(item, dict):
            for child in item.values(): walk(child)
        elif isinstance(item, list):
            for child in item: walk(child)
    walk(value)
    interface=value.get('interface',{})
    if not isinstance(interface,dict):raise ValueError('interface must be an object')
    if not isinstance(interface.get('design','original'),str) or not re.fullmatch(r'[a-zA-Z0-9_-]+',interface.get('design','original')):raise ValueError('Invalid interface design')
    validate_style(interface.get('style',{}))
    if type(interface.get('cyclingEnabled',True)) is not bool:raise ValueError('Invalid cycling setting')
    if type(interface.get('reducedMotion',False)) is not bool:raise ValueError('Invalid reduced motion setting')
    sharing=interface.get('fileSharing',{})
    if not isinstance(sharing,dict):raise ValueError('Invalid file sharing settings')
    for key,alignment in sharing.items():
        if key not in ('titleAlignment','footerAlignment','addAlignment') or alignment not in ('left','center'):
            raise ValueError('Invalid file sharing alignment')
    light=interface.get("onionLight",1)
    if type(light) is not int or not 0<=light<=3:raise ValueError("Invalid onion lighting")
    note_style=interface.get("noteStyle",0)
    if type(note_style) is not int or not 0<=note_style<=7:raise ValueError("Invalid cycling note style")
    marker=interface.get("activityMarker",1)
    if type(marker) is not int or not 0<=marker<=2:raise ValueError("Invalid activity marker")
    inspector=interface.get("relayInspector",0)
    if type(inspector) is not int or not 0<=inspector<=3:raise ValueError("Invalid relay inspector")
    card_style=interface.get('cardStyle',1)
    if type(card_style) is not int or card_style not in (0,1):raise ValueError('Invalid card style')
    scale=interface.get('uiScale',1)
    if type(scale) not in (int,float) or not .85<=scale<=1.5:raise ValueError('Invalid interface size')
    layout=interface.get('layout',0)
    if type(layout) is not int or not 0<=layout<=14:raise ValueError('Invalid interface layout')
    size=interface.get('sentenceSize',12)
    if type(size) not in (int,float) or not 9<=size<=20:raise ValueError('Invalid sentence size')
    interval=interface.get('sentenceInterval',45000)
    if type(interval) is not int or not 3000<=interval<=60000:raise ValueError('Invalid sentence interval')
    overrides=value.get('colorOverrides',{})
    if not isinstance(overrides,dict):raise ValueError('colorOverrides must be an object')
    for scope,colors in overrides.items():
        if not re.fullmatch(r'\*|[a-zA-Z0-9_-]+',scope) or not isinstance(colors,dict):raise ValueError('Invalid color override scope')
        for key,color in colors.items():
            if not re.fullmatch(r'[a-zA-Z][a-zA-Z0-9_]*|\$\.[a-zA-Z0-9_.]+',key):raise ValueError('Invalid color override key')
            if not isinstance(color,str) or not re.fullmatch(r'#[0-9a-fA-F]{6}|@[a-zA-Z][a-zA-Z0-9_]*',color):raise ValueError('Use #RRGGBB or @role for overrides')
            if color=='@'+key:raise ValueError('Color role cannot reference itself')
        for key in colors:
            seen=set();current=key
            while current in colors and colors[current].startswith('@'):
                if current in seen:raise ValueError('Cyclic color role reference')
                seen.add(current);current=colors[current][1:]
    camera = value.get('camera')
    if camera is not None:
        for key in ('longitude', 'latitude', 'viewRoll'):
            if type(camera.get(key)) not in (float, int):
                raise ValueError('Camera needs numeric ' + key)
        if not -90 <= camera['latitude'] <= 90:
            raise ValueError('Invalid camera latitude')
    return value
