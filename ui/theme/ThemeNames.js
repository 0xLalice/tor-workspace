.pragma library

// Only user-reviewed palettes receive names. Design IDs and saved presets stay
// stable; adding a reviewed palette here changes presentation only.
var reviewed = {
    "white": {original: "White Graphite", meridian: "Chalk Orbit"},
    "solitude": {original: "Solitude Silver", meridian: "Quiet Parchment"},
    "retro-82": {original: "Retro Groove", meridian: "Vinyl Drift"},
    "miasma": {original: "Miasma Veil", meridian: "Stone Reverie"},
    "lupine": {original: "Lupine Sky", meridian: "Blossom Drift"},
    "lumon": {original: "Lumon Frost", meridian: "Severed Blue"},
    "last-horizon": {original: "Horizon Dusk", meridian: "Last Light"},
    "hackerman": {original: "Hackerman Signal", meridian: "Neon Grid"},
    "ethereal": {original: "Ethereal Starlight", meridian: "Astral Ember"},
    "rose-pine": {original: "Rose Nebula", meridian: "Pine Mist"},
    "ristretto": {original: "Ristretto Roast", meridian: "Crema Orbit"},
    "everforest": {original: "Everforest Mist", meridian: "Woodland Haze"},
    "gruvbox": {original: "Gruvbox Copper", meridian: "Patina Orbit"},
    "kanagawa": {original: "Kanagawa Wave", meridian: "Edo Lantern"},
    "nord": {original: "Nord Frost", meridian: "Aurora Orbit"},
    "osaka-jade": {original: "Osaka Classic", meridian: "Jade Orbit"},
    "catppuccin": {original: "Catppuccin Frost", meridian: "Mocha Bloom"},
    "catppuccin-latte": {original: "Latte Cloud", meridian: "Catppuccin Bloom"},
    "flexoki-light": {original: "Flexoki Ink", meridian: "Light Orbit"},
    "matte-black": {original: "Matte Ember", meridian: "Black Lantern"},
    "vantablack": {original: "Vanta Eclipse", meridian: "Black Orbit"},
    "tokyo-night": {original: "Tokyo Dusk", meridian: "Night Ember"}
};
// The successor stock palette shares the requested Osaka design names. Keep
// the legacy ID intact for Omarchy 4.0 and standalone Osaka Jade installs.
reviewed["jade-horse"] = reviewed["osaka-jade"];
var defaults = {original: "default1", meridian: "default2"};

function present(theme, paletteId) {
    var names = reviewed[paletteId] || defaults;
    return Object.assign({}, theme, {name: names[theme.id] || theme.name});
}

function entries(themes, paletteId) {
    return themes.map(function(theme) { return present(theme, paletteId); });
}
