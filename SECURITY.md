# Security and permissions

Tor Workspace is an unsandboxed Omarchy plugin. It is not a system-wide VPN,
Tor Browser replacement, anonymity guarantee, or independently audited security
product. Marketplace acceptance, if later obtained, is not a security audit.

## Privileged setup

Review `docs/INSTALL.md`, `system/`, `system/tor_workspace.py`, `install/browser_install.py`, and
`install/install-user.py` before setup. Native compilation and browser downloads run as
the desktop user. Administrator authentication is needed for system packages,
root-owned backend files, systemd units and network configuration.

The backend installs under `/usr/local/lib/omarchy-tor`, enrolls users under
`/etc/omarchy-tor/users`, and owns units named `omarchy-tor-*-UID`. Its runtime
network uses `omarchy-tor-UID`, an `otUID` interface, and an `omarchy_tor_UID`
nftables table. It can add interface-specific UFW rules when UFW is installed.
Review `system/tor_workspace.py` for the exact rules and namespace DNS configuration.
No blanket passwordless sudo rule is installed.

The socket is restricted to the enrolled UID. The session broker checks peer
credentials and validates launch requests; workers run as that user with no
capabilities. UI state and workspace placement are not security boundaries.

Setup backs up the user's shell/Hyprland configuration and adds the plugin and
a guarded Lua include. It preserves existing settings and Omarchy shortcuts.
Root backend removal must precede deleting the plugin. Remaining namespace
processes prevent removal of the network guard.

## Network access

- Tor connects to its network when enabled. Only applications launched through
  the plugin's isolation path use that namespace; other host traffic is unaffected.
- Tor Browser setup directly contacts Tor Project release/download endpoints
  and `keys.openpgp.org`. It verifies the archive with a pinned Tor Project signing
  fingerprint before extracting it as the user. Package installation uses the
  machine's configured Arch repositories.
- Terminal exit checks contact `icanhazip.com`, with `check.torproject.org` as a
  fallback, through Tor. Exit-country lookup uses Tor's local GeoIP database.
  The globe's ordinary-connection origin and explicit-IP map attribution query
  `api.country.is` directly; these are separate from exit verification.
  Relay details use Tor Project Onionoo through Tor. The public aggregate onion
  estimate uses a direct HTTPS request to Tor Metrics and a local cache.
- The explicitly requested speed comparison performs both a direct and a Tor
  measurement. Its direct test uses Fast.com/Netflix endpoints and its Tor test
  uses Cloudflare. The direct measurement intentionally reveals the ordinary
  network address to that service.
- Sharing, chat, and website hosting create onion services for the content you
  explicitly choose. Treat an onion service address as sensitive when access is
  meant to remain private.
- Globe map assets are bundled and rendered offline. No analytics or
  marketplace reporting is implemented by this plugin.

## Reporting

Report suspected vulnerabilities through [GitHub private vulnerability reporting](https://github.com/0xLalice/tor-workspace/security/advisories/new). Keep Tor control cookies, browser profiles, onion addresses and shared files out of reports.
