# Omarchy 4.0.6 and 4.5 compatibility

The 4.5 update exposed independent desktop and plugin integration failures.
These are not a change to the saved Tor design IDs (`original`, `meridian`).

| Symptom | Cause | Plugin handling |
| --- | --- | --- |
| Dashboard shrinks to 80 × 120 on a 1920 × 1080 desktop | The 4.5 bar surface fills its screen. The copied popup used its window height as bar thickness, reducing available card height to the 120-pixel minimum. | Use `barSizeFor(screen.name)` when available, otherwise the 4.0 `barSize`. Use window dimensions only for click-coordinate translation. |
| Onion icon displaced | The new bar measures component bounds; the asynchronous vector did not provide stable bounds. The nested launcher also did not fill the runtime item. | Fill the loader/launcher and provide a fixed, transparent icon canvas. Both shell versions support this geometry. |
| Jade Horse shows generic design labels | Palette IDs index the display-name registry; `jade-horse` was absent. | Map it to Osaka Classic / Jade Orbit while retaining `osaka-jade`. Colors continue to come from the actual selected palette. |
| Blank background and missing generated terminal theme after selecting Osaka Jade | The main package removed its palette, but the installed intros package retained its directory. The theme picker/setter could accept that incomplete directory. | This is an upstream desktop failure. The plugin must not recreate or alter stock Omarchy themes. |

Package comparison: `omarchy-4.0.6-1` contains 22 palettes;
`omarchy-4.5.0-3` contains 23. `osaka-jade` was removed; `jade-horse` and
`starship` were added. All 21 shared IDs and palettes are unchanged, including
`miasma`. Jade Horse is a replacement palette, not an identical rename.

The 42 plugin variants attached to those shared palettes retain their names,
settings and resolved colors. Legacy Osaka Jade remains supported. Starship
uses the functional generic pair `default1` / `default2`; a named, individually
reviewed Starship pair is not yet part of this plugin. Do not present generic
palette/contrast validation as approval of new artwork.

Upstream references: [Jade Horse replacement](https://github.com/omacom/omarchy/pull/16594),
[incomplete Osaka Jade selection](https://github.com/omacom/omarchy/issues/17198),
[proposed palette guard](https://github.com/omacom/omarchy/pull/17218).

## Regression checks

`tests/popup_geometry_test.py` loads the actual popup under Quickshell against
both full-screen and strip-sized hosts, in all four bar positions. It checks
card size, position, available space and the click-forwarding strip. Its only
mapped host is a transparent background layer with an empty input region.

Both it and `tests/installation_test.py` accept `OMARCHY_TEST_SHELL_ROOT` to
select extracted packaged shell components. This checks the actual old/new
QML imports, launcher bounds and bootstrap without downgrading the desktop.
It complements, rather than replaces, live checks in both OS environments.

For each supported version, install the same Git revision, restart the shell,
verify the bar and icon, open the dashboard, switch both designs, open and
dismiss overlays, and check for QML errors. Confirm the active palette and
native-module readiness through `omarchy-shell tor.workspace status` and
`omarchy-shell tor.workspace paletteStatus`. Keep screenshots, exact package
versions and test logs outside the distributable checkout.

Preserve the old VM package set for compatibility checks. Updating that VM to
4.5 would remove the environment needed to verify 4.0 behavior. Full release
acceptance remains governed by [the release checklist](RELEASE_CHECKLIST.md).
