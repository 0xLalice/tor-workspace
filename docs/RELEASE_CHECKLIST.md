# Release verification

## Evidence rules

- Test the exact candidate source, recording its commit, source inventory,
  Omarchy/Qt/Tor/OnionShare/browser versions and VM baseline outside the package.
- A signal firing, a worker starting, or an onion address appearing is not a
  completed feature test. Verify the result at the other end.
- Distinguish component checks, real dependency integration, and desktop/Tor
  acceptance. A mock cannot certify the boundary it replaces.
- A skipped, timed-out or unavailable check remains unverified. Record failures
  before retrying; do not convert a transport failure into a pass because local
  HTTP works.
- Preserve the clean VM snapshot and matching UEFI state. Use harmless fixtures,
  disposable browser profiles and test-only services. Never stop users' active
  host services to test recovery. Keep credentials, onion addresses, screenshots
  and logs outside Git.
- Before release, repeat affected acceptance checks after the final change and
  run CI on the proposed commit. A historical run is supporting evidence only.

## Main feature map and acceptance

| Feature | Implementation path | Required observable result |
| --- | --- | --- |
| Fresh installation | `BarWidget` → `InstallationDialog` → setup terminal → `setup-session.py` | Unbuilt panel opens; Install opens the setup terminal in the plugin directory; explicit confirmation precedes setup; one sudo session; packages/build/backend/signed browser/workspace complete; panel opens with Tor off. |
| Missing agent/manual setup | setup terminal / bundled guide | Signed-out users can install directly; failed optional review returns to the terminal; cancelling applies nothing. |
| Tor on/off | power button → `RuntimeWidget.controlTor` → `lifecycle.py` → system broker | Start is explicit; initialized Tor with confirmed policy enables actions even without spare circuits; idle status reads never build circuits; operations prepare their required connections; Stop clears availability and takes services offline; reopening the panel never starts Tor. |
| Browser and terminal | dashboard → `launch.py` → root-owned `client.py` / `session.py` | Actual windows open in Tor workspace; namespace differs from ordinary desktop; HTTPS exit is Tor; terminal observes exact exit and country; failed launch never opens an ordinary application as fallback. |
| Country lock/new circuit | globe/footer → runtime → `exit_controller.py` | Policy readback and matching exit precede launch; unavailable country stays blocked; renewal confirms a replacement; existing onion services survive exit renewal. |
| File sharing | picker → dashboard pending selection → runtime queue → `share.py` → `share_page.py` | Actual selected file publishes; visitor follows page's Download link and receives identical bytes; multiple files have independent links; duplicate selection does not duplicate a worker; Cancel publishes nothing. |
| File recovery | Options → resume preference → share worker | Default off/on does not resume; opt-in waits for a new verified Tor session and creates a new link; Stop and disabling resume cancel waiting work; deleted/unreadable file produces a useful error. |
| Chat | `ChatDialog` → runtime → `chat.py` → OnionShare adapter | Real browser shows nickname/messages; two clients exchange messages both ways; count goes 2→1→0; missing script gives visible feedback; closing overlay keeps room; Stop invalidates it. |
| Folder hosting | folder picker → `HostDialog` → `host.py` → OnionShare website | Root index, relative assets and links work over onion transport; cancel/invalid folder/no index reports correctly; original folder survives Stop. |
| Local app hosting | port input → `host.py` → `ADD_ONION` | A real loopback app is reached through the onion link; invalid/dead port is rejected; Stop removes publication without stopping the app. |
| Onion search | `DarknetDialog` → `launch.py` | Dedicated Tor Browser opens the configured onion search endpoint; no ordinary browser fallback. |
| Circuit/relay information | globe/circuit UI → local circuits / relay / antipode helpers | Actual observed data or explicit unavailable state; stale responses do not overwrite newer selections; relay requests use Tor; retained illustration does not enable network actions. |
| Speed comparison | speed overlay → `speed_compare.py` | Explicit direct and Tor measurements remain separate; cancelled process stops; failures aren't reported as speed; UI discloses the direct test. |
| Themes/renderers | palette watcher → palette gate → shared appearance → native renderers | All 22 palettes, both built-ins, custom publication; smooth transitions after Omarchy; no resize, flash, circuit redraw/request or camera reset; hidden/reduced-motion stops unnecessary work. |
| Options/shortcuts | Options → runtime → `shortcuts.py` | Both shortcut halves checked for conflicts; changes survive reload; clearing removes only plugin-owned bindings; resume option appears only in Options. |
| Updates/repair | update dialog → direct update or confirmed setup → readiness | Offline use works; dirty/divergent Git blocks update; user settings/history survive; required native/backend repair is explicit; repeated setup creates no duplicate widget/include. |
| Removal/reinstall | `system/uninstall.py` → Omarchy removal | Refuse unsafe namespace cleanup with remaining processes; remove owned units/network resources only; retain files/profiles/preferences; reinstall works. |

## Update acceptance and final public access

Keep a disposable VM checkout at an earlier real commit, preserving its settings
and Git history. Check both a versioned release with feature notes and the commit-summary fallback for a maintenance change.

- [ ] With credential helpers disabled, standard installation from the public
  GitHub URL succeeds. Private authenticated installation does not satisfy this.
- [ ] The installed UI displays bundled history offline, checks without opening
  authentication dialogs, and shows the actual pending release notes or commit
  summaries above installed history.
- [ ] Local edits/divergence block Update, including edits made after discovery
  was cached. Source, settings and history remain intact on failure/cancellation.
- [ ] Update applies the selected release and verifies readiness. Privileged updates complete through the setup terminal with or without agent review.
- [ ] After completion, readiness passes, no update remains pending, settings
  survive, and repeated checking causes no duplicate configuration or dialogs.
- [ ] GitHub private vulnerability reporting is enabled and its reporting link
  works; repository history and published artifacts contain no private test data.

