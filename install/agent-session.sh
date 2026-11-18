#!/usr/bin/env bash
# Run inside the agent terminal, independently of plugin/shell reloads.
failure_target=${2:-installationFailed}
case "$failure_target" in installationFailed|updateFailed) ;; *) exit 2 ;; esac
plugin_dir=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P) || exit 1
cd -- "$plugin_dir" || exit 1
if [[ $(omarchy default agent) == codex ]]; then
  # Install explicitly selects this project. Scope trust to this invocation and
  # exact path; keep Omarchy's normal sandbox/automatic approval-review mode.
  # Pass the path inside a TOML value: CLI dotted keys split dots in paths.
  # TOML quoted keys need escaped backslashes and double quotes.
  trusted_path=${plugin_dir//\\/\\\\}
  trusted_path=${trusted_path//\"/\\\"}
  trusted_path=${trusted_path//$'\n'/\\n}
  trusted_path=${trusted_path//$'\r'/\\r}
  trusted_path=${trusted_path//$'\t'/\\t}
  codex --approve-for-me -c "projects={\"$trusted_path\"={trust_level=\"trusted\"}}" -- "$1"
else
  omarchy agent prompt --inline "$1"
fi
result=$?
if (( result != 0 )); then
  omarchy-shell tor.workspace "$failure_target"
fi
exit "$result"
