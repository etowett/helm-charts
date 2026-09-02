#!/usr/bin/env bash
#
# PostToolUse(Edit|Write) — append a missing trailing newline.
#
# Cheap and universal: YAML, JSON, Markdown and shell all want one, and a file
# without it produces a "\ No newline at end of file" marker in every future
# diff. Always exits 0; a formatting nicety must never block a turn.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
file="$(hook_json_field "$input" '.tool_input.file_path')"
[ -n "$file" ] && [ -f "$file" ] && [ -s "$file" ] || exit 0

# Binary files have no business gaining a newline.
case "$file" in
  *.tgz | *.gz | *.png | *.jpg | *.jpeg | *.ico | *.pdf) exit 0 ;;
esac

[ "$(tail -c 1 "$file" | wc -l | tr -d ' ')" = "0" ] && printf '\n' >>"$file"
exit 0
