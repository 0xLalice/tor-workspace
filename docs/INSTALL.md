# Installation and repair

Open **Installation → Install**. Type **i** in the setup terminal to proceed or
**q** to cancel. When an agent is available, **r** opens a source review. Exit
the agent to return to this terminal. Installation also works on machines with
no agent or AI account.

The same terminal handles updates that need system changes. Before applying a
confirmed update, the installer rechecks the selected Git revision and local
edits. Ordinary user-only updates run directly from the panel.

## Optional review

Review the incoming Git changes, the installation scripts under `install/` and
the root-owned backend under `system/`. The agent explains privileges and any
concerns. The terminal owns the subsequent installation and sudo prompt.

## Complete setup

Run commands from this plugin directory as the desktop user. Preserve existing
theme files and Tor state. Never run compilation, browser installation or the
user installer as root. Never start Tor merely to finish installation.

This is an installation workflow, not a development validation run. Do not run
the full Python or graphics test suites during installation. They require installed
dependencies and desktop access, can take several minutes, and are maintained
for development/release validation in CONTRIBUTING.md. The completion checks
below are the installation smoke test.

Run desktop checks in the desktop user's session with access to its Wayland,
Hyprland and systemd user sockets. An agent sandbox may deny those connections
even when environment variables exist. A permission error is not evidence that
the desktop or launcher is broken: use the agent's permitted desktop-session
execution mechanism, or report that verification is blocked. Do not run those
checks as root or bypass enforced sandbox restrictions. Sandbox-created empty
`.agents`, `.codex` or `.aws` directories can also make package inventory checks
reject an otherwise unchanged checkout. Verify the real checkout from a permitted
session; do not delete those directories, relax inventory checks, or refresh hashes.

1. During review, run `python3 -B install/setup_status.py` to identify unfinished
   steps. This JSON reporting command exits zero when the report ran, even if
   setup is incomplete. Inspect `ready` and `issues`. Check installed/available Tor
   versions: Tor **0.4.9.14 or newer** is required. If the configured repository
   cannot supply it, report the actual version and blocker; do not bypass package
   policy or signature checks. Missing packages on a fresh machine are expected.
2. The panel opens `install/interactive-setup.sh install`. To open the same
   installer manually, run `bash install/interactive-setup.sh install` from the
   installed plugin directory. Confirming runs `install/setup-session.py`.
3. The session verifies the source inventory and computes missing runtime/build
   packages from the report. It obtains one normal sudo authentication in this
   terminal, installs only missing packages through `omarchy pkg add`, checks the
   Tor minimum, builds native modules as the desktop user, then invokes the fixed
   root-owned backend installer with `sudo -n /usr/bin/python3 -I system/install.py`.
   A bounded-to-this-session keeper refreshes the same terminal's sudo timestamp
   noninteractively while compilation runs. It exits and invalidates that timestamp
   on success, failure or cancellation. No password is stored, no sudoers rule is
   added, and the agent/build tools never run as root. If no privileged work is
   needed, authentication is skipped. Failed/expired authorization is incomplete
   setup, not success; inspect the failure rather than adding new password prompts.
4. After releasing administrator authorization, the session downloads and
   signature-verifies Tor Browser as the desktop user if absent, registers the
   widget/workspace with backups, reloads Hyprland and checks configuration errors.
   It requires actual readiness before returning success. Existing browser bundles,
   settings, Git history and Tor state are preserved. Tor is not started.
5. After the helper succeeds, rerun `python3 -B install/setup_status.py` and require
   `ready: true`. Restart the shell with `omarchy restart shell` to load native
   libraries. Following local CU Pilot rules, activate the Tor workspace using
   `hyprctl dispatch 'hl.dsp.focus({workspace="name:Tor"})'`, let the switch settle,
   then run `omarchy-shell tor.workspace open`. Check
   `omarchy-shell tor.workspace status`: wait for the initial installation check,
   require `installation.ready` and `opened`, and visually confirm the rendered
   panel. Successful IPC exit alone does not establish that it opened.

Do not split normal installation into the older separate `packages` and `backend`
terminal actions: separate TTYs cause repeated sudo prompts. They remain available
for focused manual repair only. For a manual full installation in an already-open
terminal, run `python3 -B install/setup-session.py` as the desktop user after review.

If Python or foot itself is absent, bootstrap those Omarchy baseline prerequisites
in the default terminal and explain that exceptional repair before proceeding.
If package databases need an update, stop and report the prerequisite; use the
normal `omarchy update` flow, never `pacman -Sy`, forced mirror changes, disabled
signatures or package guards. The normal one-session path assumes a working
Omarchy base and its normal sudo timestamp policy. Cancellation or policy denial
must not trigger hidden retries or a claim of successful installation.

Report any blocked or failed checks accurately, including a later targeted retry.
Do not describe an unsuccessful full test run as passed because one failed suite
subsequently passed alone. Stop setup once readiness and the panel are verified;
do not begin fault-injection or recovery experiments in the user's live session.

The installation button stays available until readiness checks pass. After a
Qt upgrade, rebuild local native modules using the same build path.
If the widget still cannot load, inspect the shell's QML errors; restarting is
necessary to unload old native libraries.

`source-hashes.json` checks package integrity against the included inventory;
it is not a publisher signature. Do not regenerate it during installation.

After cancelled authentication, an interrupted build/download or partial setup,
rerun the read-only report and finish the missing steps. Builds publish only
after successful compilation, the browser replaces an existing bundle only
after signature verification, and user registration avoids duplicate widgets
and workspace includes while preserving Git history and user settings. An
interrupted browser download may restart on the next invocation. Repeating setup
is supported; opening an agent never marks it complete. Installation keeps Tor
off; start it explicitly afterward for functional testing. Ordinary Tor terminal
launches use the enrolled user's socket without repeated administrator authentication.

## Removal

Review `system/uninstall.py` and run it with administrator authentication to
remove the per-user backend and its network state. Close Tor applications first: removal stops this user’s Tor services. It retains
the network guard if other namespace processes remain. Remove the
plugin with Omarchy's plugin tools. Before removing its files, run
`python3 -B backend/shortcuts.py remove` from the installed plugin to remove only
its registered shortcut handles. Reload Hyprland after removal to clear the
integration, then check `hyprctl configerrors`. The guarded Lua include tolerates a missing
plugin. Keep personal published theme files unless the user requests removal.

## Dependency roles

| Packages | Purpose |
| --- | --- |
| `python` | Runtime services and setup scripts |
| `cmake gcc make qt6-base qt6-declarative qt6-shadertools` | Local C++ and shader builds (Qt 6.7 or newer) |
| `tor iproute2 nftables` | Tor gateway, network namespaces and firewall guard |
| `foot curl gnupg` | Isolated terminal, bounded HTTPS requests and browser signature verification |
| `iso-codes onionshare` | Country names and onion service sharing/chat/hosting |

The custom visitor pages are verified with OnionShare 2.6.5. Other versions use
OnionShare's own pages; they are not claimed as tested custom-template targets.

Omarchy supplies Hyprland, Quickshell, Git, systemd and the shell/plugin tools.
Build packages may be needed again after an update. Current Tor Browser acquisition
supports x86_64; other architectures are not supported by this release.

Public installations check for updates over anonymous HTTPS. Run `omarchy plugin update tor.workspace` to review the diff and update manually.

Tor terminals use a private resolver directory inside the session service so host
DNS updates cannot replace their Tor DNS settings. Backend updates recreate the
launcher mount namespace; reopen existing Tor terminals to use the new resolver.
Tor itself and its country preference are retained during this update.
