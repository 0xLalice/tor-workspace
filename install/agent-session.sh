#!/usr/bin/env bash
# Optional source review; the setup terminal owns installation and authentication.
plugin_dir=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P) || exit 1
cd -- "$plugin_dir" || exit 1
if [[ $(omarchy default agent) == codex ]]; then
  # Scope the review to the selected plugin checkout.
  # Pass the path inside a TOML value: CLI dotted keys split dots in paths.
  # TOML quoted keys need escaped backslashes and double quotes.
  trusted_path=${plugin_dir//\\/\\\\}
  trusted_path=${trusted_path//\"/\\\"}
  trusted_path=${trusted_path//$'\n'/\\n}
  trusted_path=${trusted_path//$'\r'/\\r}
  trusted_path=${trusted_path//$'\t'/\\t}
  codex --sandbox read-only -c "projects={\"$trusted_path\"={trust_level=\"trusted\"}}" -- "$1"
else
  omarchy agent prompt --inline "$1"
fi
