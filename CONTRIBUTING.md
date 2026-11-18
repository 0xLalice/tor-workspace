# Contributing

This is the canonical plugin source repository. Keep its root directly installable
by `omarchy plugin add`. Do not add theme-builder tools, personal settings,
credentials, build products, or developer history to this checkout.

Install/build requirements are in [docs/INSTALL.md](docs/INSTALL.md). Before committing:

```sh
python3 tools/check_package.py --refresh-hashes
python3 tools/check_package.py
python3 -m unittest discover -s tests -p '*_test.py'
omarchy plugin validate .
python3 tools/build-native.py
python3 tools/test_ui.py
```

Use `--refresh-hashes` only when intentionally changing source for a new commit;
review the diff first. It inventories all source files, excluding Git metadata, Python caches and `build/`. This is an
accidental-corruption check, not a signature. End-user setup must never refresh
source hashes to bypass a verification failure.

Local native builds are ignored by Git. `build-info.json` binds the result to its
Qt version, architecture, and native source digest. Restart the shell after
rebuilding loaded libraries. A build must not run privileged setup or start Tor.

CI checks inventory, documentation links, package conventions, Python syntax,
Git-preserving setup regressions, real visitor pages in Chromium, and all three native builds. It does not install
system services, change host networking, or substitute for the clean Omarchy VM
checks listed in [release gates](docs/marketplace.md).

Use the [release checklist](docs/RELEASE_CHECKLIST.md) for feature wiring and
acceptance. Browser tests need a development-only environment outside the plugin:

```sh
python3 -m venv --system-site-packages /tmp/tor-web-tests
/tmp/tor-web-tests/bin/pip install playwright==1.64.1
/tmp/tor-web-tests/bin/playwright install chromium
/tmp/tor-web-tests/bin/python -B tools/test_web.py
```

Alternatively pass `--chromium /path/to/chromium`. The suite starts real
loopback-only OnionShare servers and disposable browsers. It never starts Tor or
touches user services. A successful run proves visitor-page integration; desktop
wiring and onion transport still need the separate VM checks. Run against each
supported OnionShare package, not a mocked version number.

Change the manifest version and prepend its entry in `docs/releases.json` for
each release; package validation requires them to match. Keep install/update/removal
instructions synchronized with code. Generated historical data must preserve its
source provenance and attribution. Keep each source module under 512 KiB so the
marketplace can inspect it completely.

Keep each changelog entry to its version and at most two short lines about core
user-facing features. Avoid implementation details and feature inventories.

For every UI or theme change, use the actual plugin in the QML suites and native
benchmark harness. The retired builder and workshop checkouts are local archives,
never maintained sources or runtime dependencies. Keep Original’s approved
Osaka Jade settings, colors and wording unchanged. New designs belong in the
data contract described in [presentation themes](docs/THEMES.md) and focused shared components. Palette choices belong
in ThemeColors; new visual components and shaders must not contain fixed colors.
Use `ColorProfiles.designs[paletteId][paletteProfile]` for individual palette treatments,
and keep approval/naming in `ThemeNames` separate. Compare resolved settings and
roles before/after: palettes outside the requested scope must be identical.
Verify the live resolved configuration after installation; plugin hot reload can
retain older QML components. Restart the shell if necessary, preserving Tor state.
Publish release commits on `main`. Omarchy follows the default branch. Bump the manifest and prepend two short user-facing changes to `docs/releases.json` in the same commit.
Keep action overlays compact: controls, short status, and at most a brief footer.

Use the shared overlay header, body and footer. Titles and short footers are
centered; keep reading content, lists and form fields left-aligned. Primary
actions use ActionCard: a 40px icon card with a small label beneath it. Center
single cards or ActionCardRow groups. Inline row actions stay flat. Reuse
ActionGlyph for matching dashboard and overlay icons. File sharing is the
visual reference. Shortcut settings remain one compact line for the
Super+key / Super+Shift+key pair, with both checked for conflicts.

Palette and native performance checks:

```sh
python3 tools/check_palettes.py
python3 tools/benchmark.py --output /path/outside/plugin/measurements --themes original meridian --seconds 60 --runs 3
python3 tools/compare_benchmarks.py --baseline /path/outside/plugin/baseline --integrated /path/outside/plugin/measurements --output /path/outside/plugin/comparison.json --themes original meridian
```

The benchmark imports the actual UI and native modules. It has no editor,
publication interface, Tor control or simulated replacement renderer. Run on the
same hardware, 460×690 window, desktop palette and refresh rate. Use medians of
three runs per scenario; FPS must be at least 95% of the baseline, p95 no more
than 110%, and isolated-process CPU no more than 110%. Measure whole-shell CPU
separately. Stop other test/build activity while collecting acceptance captures.
Keep measurements and visual galleries outside the distributable tree.
The runner and comparison reject interrupted frame streams. Repeat excluded
samples rather than counting time spent on another workspace as a performance
regression. Preserve the excluded capture and its reason outside the package.
