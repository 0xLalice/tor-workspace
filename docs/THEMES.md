# Presentation themes

A theme supplies graphics and layout data to the shared application. It does not
supply feature implementations, action labels, explanatory text, network state,
or launch/availability rules. Switching themes must not start requests, recreate
services, or replace the displayed route.

## Add a theme

1. Copy a preset from `assets/themes/` to a new JSON file. Give it a unique `id`,
   `name`, and `interface.design` (a letter/digit/underscore/hyphen identifier).
2. Adjust `appearance`, graphics `settings`, optional `colorOverrides`, and
   `interface.style`. Retain the exported camera and graphics settings you want.
3. Add the filename stem to `assets/theme-catalog.json`. Order is display order;
   keep `original` first as the startup fallback.
4. Run `python3 -B tools/sync_themes.py`. This validates the presets and generates
   QML bootstrap data. Never edit `BuiltinThemes.js` or
   `DesignDefinitions.js` by hand.
5. Run the Python and QML checks described in [CONTRIBUTING](../CONTRIBUTING.md),
   then refresh the package inventory after reviewing the changes.

A saved publication can also contain a new preset without adding it to the
bundled catalog. Existing publications, settings, and selected IDs are preserved.
Legacy presets without `interface.style` receive compatibility defaults.

## Presentation contract

`assets/theme-style.json` defines defaults, permitted choices, and ranges.
Python and QML validate the same contract. Unknown style keys are rejected.

- `actionLayout`: `flow` (the existing interface layout variants) or `arc` (above
  and beside the globe). Both arrange the same `DashboardAction` controls.
- `paletteProfile`: an existing calibrated palette treatment, or a new profile
  name with desktop-color fallbacks. It is independent of the theme ID.
- `colorModel`: `calibrated`, `spectral`, or `paper`; `colorOverrides` and graphics
  settings refine the result using desktop color roles.
- `voidMode`, `spaceStyle`, `appearance`, and graphics settings select the shared
  background/globe renderers. `circuitRenderer`, `circuitMaterial`, `build`, and
  `retire` select circuit graphics and motion.
- Spacing, radii, outlines, text opacity, diagram drawing, hover effects, activity
  markers, and optional camera-release settings control presentation only.
- `frameZoomOnOpen` starts and reopens the globe at its normal zoom. It is enabled
  for the arc layout preset so a paused user zoom cannot obscure the surrounding
  controls. Rotation and zoom share one recovery event, delay, and easing curve.
  `cameraZoomBlend` remains accepted for legacy publications but is ignored;
  `cameraBlend` and `cameraMaxRate` govern the complete camera return. A style
  switch retargets an ongoing return from the displayed pose at the new speed,
  without restarting the orbit clock or adding another idle pause.

Existing presets explicitly declare their style settings. Adding a preset that
combines existing rendering options needs no QML or feature-code changes.
A genuinely new renderer or layout algorithm belongs in a reusable component;
expose its presentation settings through the contract, rather than branching on
the new theme's name.

## Shared content and behavior

`ui/dashboard/ActionCatalog.js` owns action names, help, and status descriptions.
`TorDashboard` resolves one action model from live state and dispatches operations.
`DashboardAction` renders that model for both layouts and the header. Stable
kind-based delegates keep focus and controls intact when statuses change.

`RotatingTorNote` owns one set of phrases and actions. Its dashboard presentation
uses one responsive width, font size, icon size, halo treatment, and schedule.
It inherits the Omarchy font. Themes may change its colors; they do not rewrite
phrases or change their typography and timing. Legacy `noteStyle`, `sentenceSize`,
and `sentenceInterval` values remain accepted on import for compatibility but do
not override this shared dashboard presentation.

`tests/qml/tst_theme_contract.qml` exercises an additional preset combining an arc
layout with Classic graphics, ten further identities, action/state parity, stable
controls, identical cycling content/geometry, and rejection of invalid settings.
The Python contract tests check JSON catalog extension and last-valid recovery.
The existing renderer, palette, layout, and feature suites cover both shipped
presets.

## Palette integration and calibrated graphics

Palette changes use Linux filesystem notifications with a 150 ms stabilization
window. An incomplete replacement retains the last valid palette. Staged files
wait for Omarchy's applied shell palette before being displayed: the plugin listens
to the shell's color update and does not change or delay its theme mechanism.
Visible panels resolve their old and new appearances once and share one 3-second eased clock for
colors, lighting and overlays. Rapid changes retarget from the displayed colors;
hidden panels and reduced motion apply the new appearance immediately. Route
geometry, Tor state and the camera stay in place. Only the void shader layer
crossfades modes, retaining at most two instances and releasing the extra one at
completion. The previous displayed appearance is retained until interpolation
starts, preventing a flash of the new endpoint. Text/control contrast is guarded
during dark–light transitions.

Two designs are built into the plugin with stable IDs `original` and `meridian`.
They are always available. Selection lives
in the plugin’s settings and does not change Tor state. The old builder is retired;
its drafts and settings are preserved locally and are not read by this plugin.

The plugin reads `$XDG_CONFIG_HOME/omarchy/tor-workspace/published.json`
(default `~/.config/omarchy/tor-workspace/published.json`). It never writes that
file. A publication can be one validated theme or a collection:

```json
{
  "themes": ["each entry is a complete theme object"],
  "activeId": "optional theme ID",
  "activation": "optional opaque activation token"
}
```

Saved themes merge with the built-ins by ID. Saved settings take precedence;
built-in display names follow the current Omarchy palette. Reviewed `osaka-jade`
and its stock successor `jade-horse` use **Osaka Classic** and **Jade Orbit**.
Both retain their real palette IDs and colors; the mapping does not reinstall or
impersonate Osaka Jade. Original’s exact Osaka calibration remains unchanged.
Reviewed `catppuccin` uses
**Catppuccin Frost** and **Mocha Bloom**; reviewed `tokyo-night` uses
**Tokyo Dusk** and **Night Ember**; reviewed `catppuccin-latte` uses
**Latte Cloud** and **Catppuccin Bloom**; reviewed `matte-black` uses
**Matte Ember** and **Black Lantern**; reviewed `flexoki-light` uses
**Flexoki Ink** and **Light Orbit**; reviewed `vantablack` uses
**Vanta Eclipse** and **Black Orbit**. The complete reviewed list lives in
`ui/theme/ThemeNames.js`. Unreviewed palettes, including `starship`,
use **default1** and **default2**, respectively. Add names to the reviewed registry
in `ui/theme/ThemeNames.js` only after the user reviews that palette. Color-profile
entries and automated contrast checks do not constitute a visual review.
Names update as presentation data without reapplying a preset, resetting its
camera, or changing the saved selection/publication. The retired built-in
`porcelain` is omitted from the chooser and its selection resolves to `meridian`,
without rewriting the publication or discarding its saved data;
other saved themes remain available. A new activation token selects `activeId`;
ordinary selection is stored separately. A malformed replacement retains the last
valid publication and exposes an error. Versions 1 and 2 remain supported.
[Osaka Classic](../assets/themes/original.json) and [Jade Orbit](../assets/themes/meridian.json)
are complete examples. Porcelain remains readable for legacy-format compatibility.

The optional design field defaults to Original:

```json
"interface": { "design": "original" }
```

The live built-ins use `original` and `meridian`; legacy `porcelain` data remains accepted. The globe appearance
range is 0–11; 10 is Meridian’s transparent cartography, 11 is Porcelain’s rose-tinted Paper Clay
material. Older appearances retain their meanings. Designs govern typography,
controls, illustrations, motion and semantic palette roles. Colors are independent
of design and update through the existing desktop palette watcher. New semantic
roles include `diagramInk`, `diagramAccent`, `globeLand`, `globeBorder`,
`globeOcean` and `globeHighlight`; JSON color values can reference them with `@`.
All palette-specific choices stay in ThemeColors/ColorProfiles.

Classic's `encryptionKey1/2/3` roles derive from `bright_blue`, `magenta` and
`bright_yellow`. Central RGB channel gains in `ColorRoles.derived` reproduce the
approved Osaka colors and scale the active palette's channels on every update;
the resulting label colors are corrected to at least 4.5:1 against the surface.
`modalScrim` derives from `darker_background` with the original 136/255 opacity.
These roles do not depend on the palette name or use a fixed Osaka override.
Orbit retains its existing illustration colors and dimming treatment. Animation
timing, geometry, key labels and reduced-motion behavior are unaffected.

Jade Orbit places Browser, Terminal, Share, Chat, Website folder, Running app
and Search at equal angles along the upper half of a circle centered on the
globe. Actions run from its left side over the top to its right side, leaving
the lower half free for the country sequence and renewal control. Logo,
Options, Themes and power share Classic’s header positions and scale. The logo’s
existing light effect indicates connection status; no separate status text is shown.
Cycling explanations remain below the circuit, with speed testing and circuit
inspection available through their cycling actions. Hover tooltips and accessible
names identify the icons. Target sizes remain at least 44 pixels and controls do
not move with the camera. Shared dialogs and handlers keep actions functional.

Orbit’s transparent cartography uses optical rails, directional transmissions,
relay acquisition and sequential retirement. Its space retains three star depths,
quiet twinkles, dust and nebula. Country illumination and the star occlusion mask
follow the actual globe geometry. Palette roles supply every effect color.
Osaka Classic retains its approved layout and original rendering effects.
Both stop animation work while hidden and show established routes in reduced motion.

Design conduits accept `circuitMaterial`, `circuitPrimary`, `circuitSecondary`,
and `circuitHighlight`;
palette and material changes update the active renderer immediately. Original's
existing effect layers and renderer remain independent of these conduits.

The two built-in interfaces follow the desktop background and light/dark mode.
Omarchy’s live `Style.font` family, size tokens and scale supply typography through
ThemeDesign; the design does not force a separate font. Normal text
targets at least 4.5:1 and meaningful controls/details 3:1, including tinted
surfaces. Original retains its approved Osaka Jade values. Reduced motion shows
established structures. Changes close open overlays and release outgoing animation
resources without requesting circuits, changing exit locks or restarting Tor.

File-sharing alignment accepts `center` or `left`, defaulting to `center`:

```json
"interface": {
  "fileSharing": {
    "titleAlignment": "center",
    "footerAlignment": "center",
    "addAlignment": "center"
  }
}
```

Rows remain left-aligned. Theme files contain data, never commands, imports or
executable code. Validation lives in backend/preset_schema.py and
ui/theme/EffectSettings.js; the native test harness imports the actual plugin.

The temporary theme gallery and design studies are retired. These built-ins are
self-contained; no theme builder or visualizer is loaded or installed.

Jade Orbit centers the globe vertically, uses palette-derived green text on Osaka
Jade, and returns user zoom to the route framing in about three seconds after
input settles. Rotation and zoom recover together; Classic retains its slower return.

Palette-specific design treatments live in `ColorProfiles.designs[paletteId][design]`.
`roles` define shared UI, illustration and effect colors. `settings` target exact
paths in the resolved presentation, allowing circuit/globe/space tuning without
rewriting saved presets. Colors reference raw desktop palette roles (`@blue`) or
mix two roles (`{base:"blue",blend:"magenta",amount:.45}`); no fixed theme colors
belong in the treatment. Text and meaningful UI details receive contrast checks.
Absent treatments retain the existing renderer and palette resolution unchanged.
Keep layout and functional behavior in the shared components, not palette branches.
Action icons use one ink color throughout, including file-sharing arrows and
cycling illustrations. This shared behavior applies to every palette and design.
Action icons use accent-colored lighting on hover and keyboard focus in every
palette and both designs. Orbit has no circular hover backdrop; active-service
markers remain visible and disabled actions stay dim.
Optional `actionInk` and `actionAccent` roles tune icon idle and hover/focus colors
independently of text and effects. Vantablack uses its grey accent at rest and its
white foreground when highlighted, so hover brightens the monochrome icons.
White strengthens hover/focus strokes through `actionStrokeScale`, removes the
blurred hover shadow with `actionGlowScale`, and uses
`logoActiveStrokeScale` with contrasting idle/active logo roles. Its Orbit dialogs
use `overlayOutline` and `overlayBorder` for a clear edge without a grey backdrop.
`circuitInkGain` and `circuitStrokeScale` strengthen native circuit opacity and
stroke width for light palettes. Both default to 1, preserving other palettes.
An optional palette-derived `circuitUnderlay` adds a thin contrasting edge to
route strokes where they cross dark globe surfaces.
`coverageVoid` selects the coverage-composited space renderer for Classic on
light surfaces, where additive glow would disappear. Its wide folded nebula
uses `voidLightColor` and `spaceSecondaryColor`; other Classic palettes keep
their original shader.
`circuitLift` can raise the design conduit above the globe; absent this option,
the existing route geometry is preserved.

Catppuccin's approved pair is blue-white **Catppuccin Frost** and
rose-white **Mocha Bloom** over subdued slate cartography, with pale text,
monochrome Orbit icons and soft pastel nebulae. Only the exact `catppuccin` ID
activates these definitions; Catppuccin Latte is separate. The review/name registry
is independent; other palettes retain `default1` / `default2` until user approval.
Osaka Jade's approved appearance remains the regression reference.

Both Catppuccin designs use palette-derived `logoLight` roles matching their
blue-white or rose-white effects. Orbit's rim and haze stay restrained so the
bright circuit remains distinct from the subdued globe. The existing connection
gate still controls the light; disconnected and unavailable states retain their
unlit appearance.
The tray's `trayLight` role follows the selected design's `logoLight`, or its
`uiAccent` when no logo treatment is defined. This keeps the icon aligned with
design-specific lighting, including when the panel is closed.
`ColorProfiles.chrome` supplies desktop fallbacks and off-state colors; Osaka
retains its approved palette green. The workspace underline uses the same
resolved color and appears only while on the Tor workspace. The runtime owns its
popup independently of the outer bar-entry wrapper, preventing the shell from
adding a second open-panel mark while retaining popup handoff and dismissal.

Tokyo Night pairs **Tokyo Dusk**, an indigo/blue Classic with coral relay effects,
with **Night Ember**, a navy Orbit with rose controls and pale rails/coral pulses.
Both use accent lighting on action-icon hover and keyboard focus. All colors
come from the Tokyo Night palette; the other approved palettes are unchanged.
