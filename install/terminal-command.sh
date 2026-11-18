#!/usr/bin/env bash
# The terminal owns sudo's interactive authentication; no password is captured.
umask 077
result_file=$1
shift
trap 'printf "%s\n" "$?" > "$result_file"' EXIT
trap 'exit 130' INT
trap 'exit 129' HUP
trap 'exit 143' TERM
"$@"
exit "$?"
