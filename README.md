# Tor Workspace

A Tor workspace for Omarchy 4: an animated circuit globe, isolated application
launchers, file sharing, chat, and onion website hosting.

This project is independent of Omarchy and the Tor Project.

## Install

Requires **Omarchy 4 with the Lua-based Hyprland configuration, x86_64**. Python
and native modules are installed during setup; the normal dashboard and globe load
before they are available. The installer works with or without an AI account.

```sh
omarchy plugin add https://github.com/0xLalice/tor-workspace.git --enable
```

Omarchy clones, validates and enables the plugin; it does not install dependencies
or run setup hooks. Open the onion widget, choose **Installation**, then **Install**.
In the setup terminal, type **i** to install or **q** to cancel. If a local agent is
configured, **r** opens an optional source review. Exiting that review returns
to the same terminal, including when the agent needs sign-in.

The installer requests your desktop password through sudo when system packages
or the root-owned Tor backend need work. Builds and browser downloads run as
your desktop user. Setup verifies readiness, reloads the shell, and preserves
the current Tor state. [Installation guide](docs/INSTALL.md)

## Use

Turn Tor on from the panel, then open applications from its launchers. They run
in the Tor network namespace. Ordinary desktop applications keep their ordinary
connection; moving a window to a workspace does not route its traffic.

- The globe retains a representative route from a real observed circuit while
  Tor runs. It is an illustration, not a claim that every connection uses it.
  Its tooltip identifies it as the last observed route. Actions remain available
  when initialized Tor has no spare circuits; operations prepare the connections
  they need, using their existing progress and error feedback.
- **New circuit** clears the drawing and waits for a confirmed replacement.
  A failed request leaves it empty. The live circuit-count note is hidden at zero.
- Choose and lock an exit country on the globe. Tor confirms the applied policy,
  disconnects incompatible connections, and waits for a matching route before
  launching applications. Unavailable countries stay blocked. Unlocking preserves
  the drawing and releases the country constraint for subsequent circuit selection.
- The bar onion is faded when Tor is off and lit/pulsing when on. Reduced motion
  keeps its light steady. Unavailable actions and their overlays are disabled.
- The terminal header shows the requested country, then observes its exit IP
  through Tor and looks up that exact IP in Tor’s local country database. It
  shows the observed country and flags mismatches explicitly. The IP check has a
  twelve-second budget per service, with one independent fallback. Failures
  distinguish timeouts, DNS, TLS and service errors; Ctrl+C skips the check and
  `tor-info` retries it. No failed check is presented as a verified exit.
  The terminal window opens immediately and shows route checks before entering
  the isolated shell. Launch actions require a fresh, ready country-policy state;
  a route lost after clicking is rechecked visibly, with a bounded wait.
  Header, status and prompt-marker colors use terminal palette slot 4, so
  Omarchy theme changes recolor existing text in open Foot terminals. This uses
  the theme's terminal blue role (often its accent), without changing Bash or
  adding a watcher. Headers printed by older versions require reopening once.
- File sharing stops with Tor by default. **Resume sharing with Tor** in Options opts in to resuming active file shares in this desktop
  session after a new Tor connection has a verified circuit. Resumed shares get
  new onion links; old links remain offline. Stop sharing cancels that file, and
  disabling resume cancels waiting shares. Files on disk are never removed.
  Shares already running during the update need one manual restart to enable
  resume; the panel identifies this instead of interrupting their links.
- Chat shows whether a room is open and how many browser connections it has,
  including your own. Counts do not identify people or store their messages.
  Rooms created before this feature report the count as unavailable; creating
  a new room enables it. Chat rooms do not resume automatically.
- **Website folder** serves a folder containing `index.html`. **Running app**
  exposes an app already listening on a local port; it does not start the app.
  Publish one at a time. Each launch gets a new .onion link; stopping publication
  takes the link offline.

Tor uses a named workspace, represented by the onion after the numbered
workspaces. It does not consume a numbered slot or intercept window moves.

Options has one key selector for a paired shortcut: **Super+U** opens Tor and
**Super+Shift+U** moves the focused window into Tor. Changing the letter updates
both together. Both combinations must be free; installation tries U, I, H, Q, R,
then Z and leaves the pair unassigned if none is available. Existing user bindings
are never replaced. Delete the letter and press Enter to clear the pair.

To move a window out, use your normal move-to-workspace binding (Omarchy default:
**Super+Shift+1–9**). User-authored bindings remain under your control.

The Themes chooser offers **Osaka Classic** and **Jade Orbit**. Osaka Classic keeps
the approved original presentation. Jade Orbit places seven evenly spaced actions
along a circular arc above and beside a smaller globe, leaving room below for
the circuit. Both inherit the active Omarchy palette and shell typography, including live changes.
Stars, nebula and country illumination remain part of both designs. Theme selection
changes presentation without renewing circuits, changing exit locks or restarting Tor.
Saved publications remain supported and are never rewritten. The retired Porcelain
selection resolves to Jade Orbit. See the [theme contract](docs/themes.md).

Tor notes appear automatically after a short delay, stay for about 12 seconds,
then leave a quiet interval (one minute in the built-in themes). Hovering a note
or opening its explanation keeps it available while you read.

## Update and repair

The public plugin ID is `tor.workspace`. Existing development installations are
migrated by `install/install-user.py`; it preserves bar placement and Git history,
and backs up the old plugin outside the shell’s plugin directory.

The plugin checks its Git remote in the background at startup and hourly. When
an update is available, the version beside the logo gains an accent badge and
an upward arrow. Click the version to open the changelog at any time: installed
release notes are available offline, and new releases appear above them when
GitHub has an update. **Options → Update available** opens the same overlay.
**Update** checks the selected release against your machine. Ordinary releases
apply directly. When system packages or the root-owned backend need work, the
same button opens the setup terminal for confirmation and optional agent review. Background checks disable
credential helpers and password prompts. Private HTTPS repositories that require
your credential helper must be updated manually with the command below, which
can use your normal Git authentication. Offline checks never prevent using the plugin.

You can also use the standard command:

```sh
omarchy plugin update tor.workspace
```

On versions through 0.2.3, an agent-only button can block a signed-out user.
Run the standard update command above once, then run `omarchy restart shell`.
If the panel shows **Installation**, choose **Install** to finish in the new setup terminal.
C++ source changes, incompatible Qt versions, and stale privileged backend files
require repair. Local builds preserve Git metadata and leave tracked files clean,
so Omarchy can fast-forward future updates. Restart the shell after rebuilding
native libraries. Keep personal edits in the exported theme file rather than
editing the installed checkout.

## Remove

Close Tor applications. Remove the per-user system backend **before** deleting
its installer:

```sh
cd ~/.config/omarchy/plugins/tor.workspace
sudo /usr/bin/python3 -I system/uninstall.py
omarchy plugin remove tor.workspace
hyprctl reload
hyprctl configerrors
```

Backend removal stops this user's Tor services and removes their namespace,
firewall rules, units, and enrollment. It refuses network cleanup while remaining
processes still use the namespace. Shared backend files are removed only after
the last enrolled user is removed. Omarchy's plugin removal alone does not remove
these system resources.

The guarded Lua include becomes inactive when the plugin is absent. Personal
themes, browser/profile data, Tor state, backups, and installed system packages
are retained. See [installation details](docs/INSTALL.md#removal).

## Technical reference

- [Architecture and language responsibilities](docs/architecture.md)
- [Permissions, networking, and security reporting](SECURITY.md)
- [Contributing and checks](CONTRIBUTING.md)
- [Marketplace release gates](docs/marketplace.md)
- [Map attribution](docs/MAP-DATA.md)

Project code is [MIT licensed](LICENSE). Bundled data has separate terms described
in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
