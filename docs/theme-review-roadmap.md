# Omarchy theme review roadmap

## Scope and progress

Baseline checked on 2026-10-20: **Omarchy v4.0.6**, the latest official release
at the time of review. Its 22 bundled themes are all installed on the review
machine (which currently runs Omarchy 4.0.4). The release's theme list, rather
than locally installed community themes, defines this milestone.

- [Official release theme directory](https://github.com/omacom/omarchy/tree/v4.0.6/themes)
- [Official release](https://github.com/omacom/omarchy/releases/tag/v4.0.6)
- [Development theme directory](https://github.com/omacom/omarchy/tree/quattro/themes)

**22 of 22 palettes approved; 44 of 44 design appearances approved.**
Osaka Jade, Catppuccin, Tokyo Night, Catppuccin Latte, Matte Black, Flexoki Light, Vantablack, Nord, Kanagawa, Gruvbox, Everforest, Ristretto, Rose Pine, Ethereal, Hackerman, Last Horizon, Lumon, Lupine, Miasma, Retro 82, Solitude and White are approved. Preserve them as regression references.
Automated palette checks and existing ColorProfiles entries do not confer approval.

Keep this list pinned to the release above. Before release of the plugin, compare
it with the then-current official Omarchy release and append any new bundled themes.
Check palette content as well as names: a changed palette needs another review.

## Review queue

Review one palette at a time, both designs together. The proposed order starts
with the default desktop palette, then contrasts dark, light and monochrome cases
before covering the remaining families. Modes below describe the installed
palette files; names alone do not determine light/dark appearance.

The names in pending rows are the actual temporary UI names. Final names are
chosen only after visual adaptation and user approval.

| Order | Official palette / ID | Mode | Design 1 | Design 2 | Display names | Review notes |
| --- | --- | --- | --- | --- | --- | --- |
| Reference | Osaka Jade / `osaka-jade` | Dark | Approved | Approved | Osaka Classic / Jade Orbit | Preserve approved appearance and effects |
| 1 | Tokyo Night / `tokyo-night` | Dark | Approved | Approved | Tokyo Dusk / Night Ember | Indigo/blue Classic with coral relay effects; navy Orbit with rose controls, pale rails/coral pulses, accent hover lighting. Appearance approved 2026-10-20 |
| 2 | Catppuccin / `catppuccin` | Dark | Approved | Approved | Catppuccin Frost / Mocha Bloom | Blue-white Classic and rose-white Orbit; approved 2026-10-20. Preserve palette-relative effects and monochrome Orbit icons |
| 3 | Catppuccin Latte / `catppuccin-latte` | Light | Approved | Approved | Latte Cloud / Catppuccin Bloom | Light Classic; Orbit with slate ink and palette-derived mauve accents. Approved 2026-10-20 |
| 4 | Matte Black / `matte-black` | Dark | Approved | Approved | Matte Ember / Black Lantern | Approved 2026-10-20: orange/neutral Classic without red decorative effects; charcoal Orbit, orange circuit with pale highlights, neutral ink, neutral globe rim and restrained orange background glow |
| 5 | Flexoki Light / `flexoki-light` | Light | Approved | Approved | Flexoki Ink / Light Orbit | Approved 2026-10-20: neutral ink, stronger native routes, dark Classic particles, blue/mauve atmosphere on cream; Orbit retains a restrained narrow cloud band |
| 6 | Vantablack / `vantablack` | Dark | Approved | Approved | Vanta Eclipse / Black Orbit | Approved 2026-10-20: monochrome designs with grey idle actions brightening to palette-white on hover/focus; disabled actions remain dim |
| 7 | White / `white` | Light | Approved | Approved | White Graphite / Chalk Orbit | Approved 2026-10-22: charcoal Classic globe and stronger smoke; pale Orbit globe with restrained haze, visible ink circuits and stars, and separated light overlays. |
| 8 | Nord / `nord` | Dark | Approved | Approved | Nord Frost / Aurora Orbit | Approved 2026-10-22: icy cyan/white Classic; darker Orbit with pale lavender circuits and restrained violet atmosphere. Native loading repaired for Quickshell virtual URLs. |
| 9 | Kanagawa / `kanagawa` | Dark | Approved | Approved | Kanagawa Wave / Edo Lantern | Approved 2026-10-22: indigo/foam Classic and parchment/gold Orbit, with subdued navy globes. |
| 10 | Gruvbox / `gruvbox` | Dark | Approved | Approved | Gruvbox Copper / Patina Orbit | Approved 2026-10-22: copper/amber Classic and charcoal/aqua Orbit; tray lighting follows the selected design. |
| 11 | Everforest / `everforest` | Dark | Approved | Approved | Everforest Mist / Woodland Haze | Approved 2026-10-22: cool forest-mist Classic and warm fog-grey Orbit; brighter routes over subdued slate globes. |
| 12 | Ristretto / `ristretto` | Dark | Approved | Approved | Ristretto Roast / Crema Orbit | Approved 2026-10-22: copper Classic and espresso Orbit with cream/caramel highlights, guided by the brown/orange wallpaper. |
| 13 | Rose Pine / `rose-pine` | Light | Approved | Approved | Rose Nebula / Pine Mist | Approved 2026-10-22: rose/lavender Classic and pale teal Orbit, with stronger gas, stars and globe atmosphere, dark routes and separated overlays. |
| 14 | Ethereal / `ethereal` | Dark | Approved | Approved | Ethereal Starlight / Astral Ember | Approved 2026-10-22: blue-white Classic and orange/peach Orbit with a cool blue globe and atmosphere. |
| 15 | Hackerman / `hackerman` | Dark | Approved | Approved | Hackerman Signal / Neon Grid | Approved 2026-10-22: cyan Classic and neon-green Orbit with dark blue globes and pale routes. |
| 16 | Last Horizon / `last-horizon` | Dark | Approved | Approved | Horizon Dusk / Last Light | Approved 2026-10-22: muted rose Classic and cool blue-teal Orbit, charcoal globes and pale circuits. |
| 17 | Lumon / `lumon` | Dark | Approved | Approved | Lumon Frost / Severed Blue | Approved 2026-10-22: icy-white Classic over deep navy and blue Orbit with a softer slate globe and restrained haze. |
| 18 | Lupine / `lupine` | Light | Approved | Approved | Lupine Sky / Blossom Drift | Approved 2026-10-22: blue Classic and navy/sky-blue Orbit with charcoal text, visible gas, dark stars and circuits, and separated light overlays. |
| 19 | Miasma / `miasma` | Dark | Approved | Approved | Miasma Veil / Stone Reverie | Approved 2026-10-22: muted olive Classic and stone/ivory Orbit with smoky charcoal globes and pale circuits. |
| 20 | Retro 82 / `retro-82` | Dark | Approved | Approved | Retro Groove / Vinyl Drift | Approved 2026-10-22: orange Classic and teal Orbit with navy globes and pale circuits, following the vinyl and sunset backgrounds. |
| 21 | Solitude / `solitude` | Dark | Approved | Approved | Solitude Silver / Quiet Parchment | Approved 2026-10-22: silver Classic and parchment Orbit, with charcoal globes and restrained smoke inspired by the ink-and-paper backgrounds. |

## Procedure for each palette

1. **Inspect.** Apply the real Omarchy palette and inspect both plugin designs at
   the same dimensions and comparable circuit/animation states. Record the palette
   version or content hash, plugin commit and findings in the review record below.
2. **Adapt.** Adjust semantic palette roles, derived shades and contrast. Preserve
   each design's layout, animation identity, shared header placement and behavior.
   Keep color choices centralized. Avoid copying dashboards or adding arbitrary
   decoration to compensate for color problems.
3. **Verify.** Recheck both designs, every screen and the shared regression checks.
   Keep captures outside the shipped plugin and reference their locations.
4. **Review together.** Show the results to the user and incorporate feedback.
   Keep the palette pending until both designs are explicitly approved.
5. **Name and record.** Choose two distinct names associated with the Omarchy
   palette, using its words or an agreed motif. For multiword palette names,
   prefer distributing its words between the two names, as Osaka Classic / Jade
   Orbit does. Single-word names can use the word in one name and a related motif
   in the other. Name pairs require user approval or an explicit request to choose and apply them; do not finalize names before appearance approval.
6. **Deliver.** Add the approved pair to `ui/theme/ThemeNames.js`, retain stable
   `original` / `meridian` IDs, update this table, install and verify the changes,
   then commit and push. Never rewrite the user's publication or selection.

Stages: Pending → Reviewing → Adapting → Awaiting user review → Approved.
A failed regression reopens the affected review. A naming suggestion is not an approval.

## Visual and functional checklist

Use the same checklist for both designs:

- Dashboard: panel surface, typography, header/logo states, disabled buttons,
  action placement, globe framing and circuit labels.
- Effects: stars, nebula, country fills/borders/lighting, exit illumination,
  circuit establishment, flowing traffic, renewal and retirement.
- Every overlay: explanations, encryption keys, rendezvous/file transfer,
  speed comparison, relay inspection, built circuits, sharing, chat, hosting,
  search, options, themes, installation and updates.
- States: Tor off, connecting/recovering, ready, empty/loading results, errors,
  cancellation and locked/unlocked exit-country selection.
- Accessibility: normal and narrow widths, keyboard focus, hover, disabled states,
  reduced motion, text readability and meaningful diagram/control contrast.
  Check actual composited surfaces: target 4.5:1 for normal text and 3:1 for
  meaningful non-text details. Keep encryption layers distinguishable.
- Switching: names, colors and font settings update together; selected design and
  settings persist; palette changes do not restart Tor or change exit restrictions.
  Animations stop while hidden. Check for performance regressions after effect changes.

Classic's encryption colors and modal tint now use palette-derived roles,
calibrated to preserve Osaka's approved appearance (completed 2026-10-20).
Exact Osaka output, palette updates, dimmer opacity and encryption contrast are
covered by tests. Keep the shared neutral shadow and renderer fallback decisions
explicit. Recheck Osaka after changes to shared color logic; other palettes still
require the visual reviews above.

## Review record template

Catppuccin appearance and naming approved on 2026-10-20. Visual review used the
installed plugin at its regular 460-pixel panel width with real circuits.
Palette/contrast checks, the QML suites and package checks passed. Comparison
captures and resolved-color snapshots are stored outside the package in
the maintainer's `tor-theme-validation/catppuccin-review` directory.
Broader installation and performance release gates remain separate.

Append one record per palette when its review begins:

```text
Palette / official version / colors hash:
Plugin commit / viewport:
Design 1 findings and fixes:
Design 2 findings and fixes:
Screens and states still outstanding:
Checks and capture locations:
Proposed name pair:
User approval and date:
Delivered commit:
```

## Upcoming and optional themes

- **Starship** (`starship`): present on the official development branch on
  2026-10-20, absent from v4.0.6. Track for inclusion when officially released.
- **Sakura Mochi**, **Aether**, **Waveform Dark**: local community additions,
  outside the official-release milestone. They continue to use default1/default2
  until separately reviewed. Aether and Waveform Dark currently lack a local
  `colors.toml`; that alone does not establish compatibility or incompatibility,
  because Omarchy can convert older theme formats during application.

Completing this roadmap finishes the palette-review aspect of release readiness.
Installation, onion-service functionality, packaging and performance remain
separate release criteria.
