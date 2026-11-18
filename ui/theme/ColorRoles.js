.pragma library
// Channel gains relative to the palette's own roles. These reproduce the
// approved Osaka colors exactly, without pinning other palettes to those colors.
// Encryption labels also pass through the surface contrast check.
var derived = {
  encryptionKey1: {base:"bright_blue", gain:[87/172, 158/212, 232/207], contrast:4.5},
  encryptionKey2: {base:"magenta", gain:[181/210, 138/104, 232/156], contrast:4.5},
  encryptionKey3: {base:"bright_yellow", gain:[214/229, 161/199, 68/54], contrast:4.5},
  modalScrim: {base:"darker_background", gain:[5/9, 9/15, 7/13], alpha:136/255}
};
var jade = {
  "mode": "dark",
  "accent": "#509475",
  "selection": "#32473B",
  "muted": "#53685B",
  "background": "#111c18",
  "dark_background": "#0c1512",
  "darker_background": "#090f0d",
  "lighter_background": "#23372B",
  "foreground": "#C1C497",
  "dark_foreground": "#81B8A8",
  "light_foreground": "#D6D5BC",
  "bright_foreground": "#F7E8B2",
  "red": "#FF5345",
  "yellow": "#459451",
  "orange": "#a2734b",
  "green": "#549e6a",
  "cyan": "#2DD5B7",
  "blue": "#509475",
  "magenta": "#D2689C",
  "brown": "#513925",
  "bright_red": "#db9f9c",
  "bright_yellow": "#E5C736",
  "bright_green": "#63b07a",
  "bright_cyan": "#8CD3CB",
  "bright_blue": "#ACD4CF",
  "bright_magenta": "#75bbb3"
};
var roles = {
  "#509475": "accent",
  "#32473b": "selection",
  "#53685b": "muted",
  "#111c18": "background",
  "#0c1512": "dark_background",
  "#090f0d": "darker_background",
  "#23372b": "lighter_background",
  "#c1c497": "foreground",
  "#81b8a8": "dark_foreground",
  "#d6d5bc": "light_foreground",
  "#f7e8b2": "bright_foreground",
  "#ff5345": "red",
  "#459451": "yellow",
  "#a2734b": "orange",
  "#549e6a": "green",
  "#2dd5b7": "cyan",
  "#d2689c": "magenta",
  "#513925": "brown",
  "#db9f9c": "bright_red",
  "#e5c736": "bright_yellow",
  "#63b07a": "bright_green",
  "#8cd3cb": "bright_cyan",
  "#acd4cf": "bright_blue",
  "#75bbb3": "bright_magenta",
  "#8fb9aa": "exitLight",
  "#101916": "tooltipSurface",
  "#d99c62": "retiringCountry",
  "#f3dc85": "transitionLight",
  "#09120f": "markerLabelSurface",
  "#8bb0a4": "originRoute",
  "#31513a": "nightwatchBorder",
  "#18171e": "popupSurface",
  "#183728": "routeSurface",
  "#7edac4": "enteringRoute",
  "#a6b5ae": "retiringRoute",
  "#010302": "nightwatchFrameSurface11",
  "#020503": "nightwatchFrameSurface12",
  "#040b07": "nightwatchFrameSurface13",
  "#050807": "nightwatchFrameSurface14",
  "#070e0a": "nightwatchFrameSurface15",
  "#080e0b": "nightwatchFrameSurface16",
  "#0b140e": "nightwatchFrameSurface17",
  "#111a17": "nightwatchFrameSurface18",
  "#111b16": "nightwatchFrameSurface19",
  "#24342b": "nightwatchFrameSurface20",
  "#2d3b32": "nightwatchFrameSurface21",
  "#314a39": "nightwatchFrameSurface22",
  "#34433b": "nightwatchFrameSurface23",
  "#345540": "nightwatchFrameSurface24",
  "#415d48": "nightwatchFrameSurface25",
  "#4b5c50": "nightwatchFrameSurface26",
  "#536257": "nightwatchFrameSurface27"
};
var extensions = {
  "routeBorder": [
    "#95dbaa",
    "bright_green"
  ],
  "routeStroke": [
    "#b9e4c6",
    "bright_foreground"
  ],
  "routeLabelSurface": [
    "#08130e",
    "dark_background"
  ],
  "exitLight": [
    "#8fb9aa",
    "dark_foreground"
  ],
  "tooltipSurface": [
    "#101916",
    "dark_background"
  ],
  "retiringCountry": [
    "#d99c62",
    "orange"
  ],
  "transitionLight": [
    "#f3dc85",
    "bright_yellow"
  ],
  "markerLabelSurface": [
    "#09120f",
    "darker_background"
  ],
  "originRoute": [
    "#8bb0a4",
    "dark_foreground"
  ],
  "nightwatchBorder": [
    "#31513a",
    "selection"
  ],
  "popupSurface": [
    "#18171e",
    "background"
  ],
  "routeSurface": [
    "#183728",
    "selection"
  ],
  "enteringRoute": [
    "#7edac4",
    "bright_cyan"
  ],
  "retiringRoute": [
    "#a6b5ae",
    "muted"
  ],
  "nightwatchFrameSurface11": [
    "#010302",
    "background"
  ],
  "nightwatchFrameSurface12": [
    "#020503",
    "background"
  ],
  "nightwatchFrameSurface13": [
    "#040b07",
    "background"
  ],
  "nightwatchFrameSurface14": [
    "#050807",
    "background"
  ],
  "nightwatchFrameSurface15": [
    "#070e0a",
    "background"
  ],
  "nightwatchFrameSurface16": [
    "#080e0b",
    "background"
  ],
  "nightwatchFrameSurface17": [
    "#0b140e",
    "background"
  ],
  "nightwatchFrameSurface18": [
    "#111a17",
    "background"
  ],
  "nightwatchFrameSurface19": [
    "#111b16",
    "background"
  ],
  "nightwatchFrameSurface20": [
    "#24342b",
    "background"
  ],
  "nightwatchFrameSurface21": [
    "#2d3b32",
    "background"
  ],
  "nightwatchFrameSurface22": [
    "#314a39",
    "background"
  ],
  "nightwatchFrameSurface23": [
    "#34433b",
    "background"
  ],
  "nightwatchFrameSurface24": [
    "#345540",
    "background"
  ],
  "nightwatchFrameSurface25": [
    "#415d48",
    "background"
  ],
  "nightwatchFrameSurface26": [
    "#4b5c50",
    "background"
  ],
  "nightwatchFrameSurface27": [
    "#536257",
    "background"
  ],
  "retirementWarm": [
    [
      0.91,
      0.63,
      0.3
    ],
    "orange"
  ],
  "retirementMuted": [
    [
      0.51,
      0.57,
      0.54
    ],
    "muted"
  ],
  "arrivalWarm": [
    [
      1,
      0.65,
      0.18
    ],
    "bright_yellow"
  ]
};
