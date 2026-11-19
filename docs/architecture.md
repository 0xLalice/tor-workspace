# Architecture

This is the single maintained source repository for the Tor Workspace plugin.
The old builder is retired; existing exported JSON themes remain compatible.
There is no release-export step or alternate development layout.

## Code map

| Directory | Language | Responsibility |
| --- | --- | --- |
| `ui/shell/` | QML | Omarchy widget, panel and runtime process coordination |
| `ui/dashboard/`, `ui/dialogs/`, `ui/components/` | QML | Dashboard, action overlays and reusable visual components |
| `ui/globe/`, `ui/circuit/` | QML / JavaScript | Globe, camera, circuit presentation and geometry |
| `ui/antipode/` | QML / JavaScript | Antipode exploration |
| `ui/theme/` | QML / JavaScript | Default appearance, validated theme application and palette |
| `ui/performance/` | QML | Optional diagnostics, loaded only when requested |
| `backend/` | Python | Unprivileged Tor control, application launch requests, sharing, chat, hosting, theme loading and geography |
| `system/` | Python | Privileged installer/remover and namespace/firewall controller; session broker installed as root-owned code but run as the desktop user |
| `install/` | Python | Read-only readiness, verified Tor Browser acquisition and user configuration registration |
| `native/circuit/` | C++ | Qt Quick QPainter circuit renderer; CPU painting |
| `native/gpu/` | C++ / GLSL | Dense exit lights through Qt scene-graph geometry and shaders |
| `native/performance/` | C++ | Optional render-thread timing, not GPU execution time |
| `native/CMakeLists.txt` | CMake | Build definition for the three Qt modules |
| `integration/workspace.lua` | Lua | Named workspace registration and initial window placement |
| `integration/tor-bashrc` | Bash | Dedicated terminal header and prompt integration |
| `assets/` | JSON, GeoJSON, images, GLSL/QSB, JavaScript data, HTML/CSS | Themes, maps, textures, shaders, pages served to onion visitors |
| `tools/`, `tests/`, `.github/` | Python / QML / YAML | Native build, package checks, regression tests and CI |
| `build/` | Generated, Git-ignored | Local Qt libraries, module descriptors and compatibility stamps |
| `docs/` | Markdown | Installation, architecture, theme contract and data attribution |

`ui/qmldir` is the UI type index. Components import that index; JavaScript and
asset references are relative to their owning component. Native wrappers import
only `build/qml/`, never source directories. Native libraries are built locally. Bundled QSB shader assets remain in `assets/`.

## Why these languages

QML is Omarchy's UI integration language. JavaScript handles UI state and geometry
inside its engine. C++ is restricted to rendering hot paths and render-thread
measurement. It does not control Tor or perform privileged setup.

Python handles structured JSON, the Tor control protocol, concurrent workers,
sockets, peer credentials, descriptor passing and process lifecycle. Replacing
that with shell would make these boundaries harder to audit. Bash is limited to
terminal integration. Lua is needed for this generation of Hyprland's configuration API;
it registers `name:Tor` and places newly launched Tor windows there.
It does not intercept window moves or replace existing keyboard shortcuts. The one-time
migration restores windows from the previously allocated numbered workspace
and removes its saved number. Optional movement bindings belong to the user’s
Hyprland configuration. Options additionally manages one paired shortcut (Super+key and Super+Shift+key) through `backend/shortcuts.py`. The helper checks live bindings, stores preferences in `keybindings.json`, and removes only its own Lua binding handles. It reapplies them after compositor configuration reloads.

`backend/updates.py` checks origin HEAD, matching Omarchy’s plugin updater. It
fetches into a private Git ref without changing the worktree or FETCH_HEAD,
caches results for an hour (five minutes after failure), and reads bounded
plain-text release entries from `docs/releases.json`. Discovery disables credential helpers,
terminal prompts and desktop askpass; SSH uses batch mode. Private HTTPS remotes
requiring a credential helper can be updated manually using normal Git credentials.
Installed history is emitted before the network check; available entries are shown above it. The header reads
the installed version from the manifest rather than maintaining a separate label. Local changes or divergent
history block the update action. The Update button starts an independent user service. It validates the selected revision in a temporary checkout and checks readiness against the installed system and native builds. Privileged setup opens a confirmation terminal with optional agent review. Confirmation rechecks the selected revision and invokes the same setup helper used for first installs. User-only updates fast-forward to the selected commit, finish any user setup and reload the shell. A Git-local marker allows interrupted setup to resume. Public installations use anonymous HTTPS.

## Installation and execution

`ui/shell/BarWidget.qml` always loads the normal dashboard. It runs the read-only
`install/setup_status.py` check and updates `RenderCapabilities.nativeReady`.
Every native import is behind a gated Loader, so an unbuilt checkout can display
the bundled globe. Tor-dependent controls remain disabled until setup is ready.

The Installation button opens `ui/dialogs/InstallationDialog.qml`. Its Install
button opens the account-independent [setup terminal](INSTALL.md). Agent review
and the bundled manual are optional. After installation, readiness checks inspect packages, backend contents, enrollment, browser,
workspace registration, socket and native source/Qt/architecture compatibility.

`tools/build-native.py` compiles as the desktop user into `build/qml/`.
`system/install.py` installs root-owned files and per-user systemd units, enabling
only the idle launcher socket. The session broker and Tor controller run as the
desktop user inside the network namespace. Network creation is a root-owned
oneshot unit. Starting Tor requires an explicit user action.

`install/install-user.py` preserves Git metadata and existing bar placement,
backs up user configuration, and registers a guarded Lua include. It migrates the
previous developer ID and include path to `tor.workspace`, preserving existing
bar placement and Git metadata. The old plugin directory is backed up outside
the plugin search path, then retired so only one widget remains. The user-facing
name is **Tor Workspace**.

The retained observed circuit is presentation state. Its lifetime does not
change Tor's circuit selection or expiry. The filesystem reorganization changes
neither network policy nor the privileged execution model.

Both panel and bar status reads only observe circuits. The controller publishes
`serviceReady` once Tor is initialized and the applied country policy has
eligible exits; unused circuit expiry does not clear it. Fresh controller data
and matching policy are still required for the action controls. The representative
drawing never grants availability and is identified as the last observed route
in its tooltip.

Explicit application launches, country changes and New circuit requests can
invoke bounded recovery. It sends `SIGNAL ACTIVE`, lets Tor select the path and
waits for actual route verification. Existing builds get an observation window;
failed attempts back off. Status polling never resets or extends this demand.
The privileged application boundary retains its strict route/country checks.
File shares, rooms and hosted apps require an available Tor service and let Tor
build their onion-service circuits; they do not require an unrelated exit circuit.
Their existing connection/publication feedback reports progress and failure.
Tor's default idle timeout remains unchanged. Regression coverage includes
`exit_controller_test.py`, `circuit_recovery_test.py`, `share_resume_test.py` and
`tst_action_availability.qml`.

Compact overlays share `OverlayPanel`, `OverlayAction`, and `OverlayToggle` for
palette, focus/hover states and reduced-motion-aware fades. Options and Themes
own their dialog content outside the dashboard. Circuit hover information uses
one reusable tooltip across the globe and route labels.

## Runtime responsibilities

`RuntimeWidget.qml` wires backend results, dashboard signals and shell IPC.
`ServiceTransport.qml` serializes each service's JSON commands through one shared
implementation. Start/retry check current availability when dequeued; status and
Stop require Python rather than full installation readiness. Polls are coalesced,
user commands remain ordered, and rejected starts or process failures drain the
queue with visible feedback. Closing an overlay does not send Stop.

`AppearanceSync.qml` owns publication settings, theme watching and the palette
gate. Its connection targets `qs.Commons` as `Omarchy.Color`, avoiding Qt's
similarly named type. Staged palette files wait for the actual shell signal.
`AgentHandoff.qml` owns the independent user-service launch and working directory
for installation, manual instructions and updates. Installation and update prompts
remain separate; failures return to the corresponding dialog.

Dashboard overlay entry points use `openOverlay`/`closeOverlays`, including IPC
and file/folder picker returns. Native Popup Escape/outside-click dismissal shares
the same presentation lifecycle and never stops the published service.

## Two built-in designs, one runtime

`DesignDefinitions.js` describes structure, typography, spacing and motion;
`ThemeDesign.qml` exposes these decisions to the shared dashboard, dialogs and
small illustrations. `ThemeColors.qml` resolves semantic colors through the
existing Omarchy palette watcher. Both built-ins follow the desktop surface;
Omarchy Style supplies the live font family, typography tokens and scale.
Osaka Classic retains its exact Osaka Jade color mappings. OrbitControls arranges
shared actions around Jade Orbit’s smaller globe without following camera movement.

The built-in JSON IDs are stable. Python merges publications by ID, with saved
settings taking precedence. A QML bootstrap supplies both before Python is
available. Neither selection nor rendering writes published.json.

Original retains Ember and the native painter. `DesignRoutes.qml` manages
construction, established and retirement states for Jade Orbit and legacy Porcelain data.
`CircuitPainter::drawDesign` builds their high-volume primitives using the same
cached route geometry and projection. Descriptors resolve on presentation changes,
not in frame work. Drawing buffers are reused, and hidden native loaders release
their objects. There is no Canvas copy of either new conduit renderer. Camera,
route state, native timers and small illustration animations stop when inactive;
reduced motion shows complete structures. Theme switching closes overlays and
crossfades circuit presenters while retaining route identity and geometry, without
touching Tor control. Sky clocks and camera pose remain continuous.

`tools/ThemeBenchmark.qml` imports these actual sources and records native
render-thread frame submissions. `tools/benchmark.py` records isolated-process
CPU and memory alongside the capture. Frame submissions are not GPU execution
time or compositor presentation. Captures stay outside the shipped package.
`tools/compare_benchmarks.py` validates matching measurement conditions and
complete frame streams before comparing the three-run medians against the
pre-change Original baseline. Whole-shell CPU observations remain separate.
