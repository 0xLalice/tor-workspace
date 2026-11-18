#!/usr/bin/env bash
# The user service survives QML reloads and can report a failed terminal launch.
failure_target=installationFailed
if [[ $1 == --failure-target ]]; then
  failure_target=$2
  shift 2
fi
case "$failure_target" in installationFailed|updateFailed) ;; *) exit 2 ;; esac
"$@"
result=$?
if (( result != 0 )); then
  omarchy-shell tor.workspace "$failure_target"
fi
exit "$result"
