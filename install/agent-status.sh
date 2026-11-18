#!/usr/bin/env bash
# Read-only and usable even before Python is installed.
set -eu
agent=$(omarchy default agent 2>/dev/null) || agent=""
case "$agent" in
  pi|omp|opencode|claude|codex|grok|gemini|openclaw|hermes|copilot|crush|cursor-agent|muse)
    if command -v "$agent" >/dev/null 2>&1; then
      printf '%s\n' '{"available":true}'
      exit 0
    fi ;;
esac
printf '%s\n' '{"available":false}'
