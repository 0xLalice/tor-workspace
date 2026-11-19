#!/usr/bin/env bash
# First installs and privileged updates share the same desktop-user terminal.
set -eu
plugin_dir=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
cd -- "$plugin_dir"
case "${1:-}" in
  install) [[ $# == 1 ]] || exit 2; subject="the installed plugin" ;;
  update) [[ $# == 2 && $2 =~ ^[0-9a-f]{40,64}$ ]] || exit 2; subject="the changes from HEAD to $2" ;;
  *) exit 2 ;;
esac
(( EUID != 0 )) || { echo "Run Tor Workspace setup as your desktop user."; exit 1; }

printf 'Tor Workspace %s\n\n' "$1"
echo "Setup checks the required packages, Tor backend and desktop integration."
echo "If system packages or backend files need installing, sudo asks for your desktop password here."
echo "Builds and browser downloads run as your desktop user."
agent=$(omarchy default agent 2>/dev/null) || agent=""
case "$agent" in
  pi|omp|opencode|claude|codex|grok|gemini|openclaw|hermes|copilot|crush|cursor-agent|muse)
    command -v "$agent" >/dev/null || agent="" ;;
  *) agent="" ;;
esac

while true; do
  printf '\n[i] Continue with %s    [q] Cancel' "$1"
  if [[ -n $agent ]]; then printf '    [r] Review first with %s' "$agent"; fi
  printf '\n> '
  read -r choice || exit 130
  case "$choice" in
    i|I) break ;;
    q|Q) exit 0 ;;
    r|R)
      [[ -n $agent ]] || continue
      echo "Exit the agent to return to this installer."
      prompt="Review $subject in this Tor Workspace checkout. Explain changes, privileges and any concerns. This is a read-only review. Leave installation, updates and authentication to the setup terminal."
      if ! bash "$plugin_dir/install/agent-session.sh" "$prompt"; then
        echo "Agent review did not finish. You can continue with setup or cancel."
      fi ;;
  esac
done

if [[ $1 == update ]]; then
  exec /usr/bin/python3 -B "$plugin_dir/install/update-session.py" --confirmed "$2"
fi
if [[ ! -x /usr/bin/python3 ]]; then omarchy pkg add python; fi
/usr/bin/python3 -B "$plugin_dir/install/setup-session.py"
exec omarchy restart shell
