# Marketplace preparation

Tor Workspace is distributed directly through GitHub. Marketplace submission is separate.

## Required repository layout

The [publishing guide](https://plugins.omarchy.org/publish.html) and
[submission procedure](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
require one public GitHub repository per plugin, a root `manifest.json`, README,
license, documented dependencies, and safe installation and removal instructions.
An actual preview image is optional. `tor.workspace` is our stable plugin ID;
`omarchy.*` is reserved for first-party plugins.

The repository is a directly installable plugin checkout. The theme builder and
its development history are excluded. Compilation happens locally; native
binaries, credentials, local settings, and test VM disks are excluded from Git.

Suggested listing metadata: category **System**, tags **security**, **workspaces**,
**bar**. Before submission, check that the ID remains available in the marketplace.
Do not describe this third-party plugin as an official Omarchy or Tor product.

## Gates before public submission

Track execution and evidence in the [release checklist](RELEASE_CHECKLIST.md).
An unchecked acceptance item blocks release even when CI is green.

- Complete a clean Omarchy VM test: install from Git, missing-dependency panel,
  agent handoff, review, package installation, user-native compilation, system
  setup, signed browser download, readiness, Tor startup and isolation checks.
- Exercise a Git update after setup, source/Qt-change rebuild, failed setup and
  repair, plugin/backend removal, and reinstall. Preserve the clean VM baseline.
- Review the privileged network rules, user broker, downloader, update/removal
  paths and all direct-versus-Tor requests. Automated checks are not a security audit.
- Verify ownership and third-party notices; choose a real preview without private
  IPs, onion URLs, hostnames or account details if a preview will be submitted.
- Enable and verify GitHub private vulnerability reporting when making the
  repository public, then update `SECURITY.md` with its working channel before
  submission. GitHub only supports this feature on public repositories.
- Run CI and `omarchy plugin validate .` on the exact proposed commit. Inspect
  the marketplace's current [security baseline](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SECURITY.md).
