#!/usr/bin/env bash
#
# Shared helpers for this repo's agent hooks. Sourced by the scripts beside it,
# which run under both Claude Code and the Codex CLI, so nothing here may assume
# a client-specific environment.
#
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Two roots, and they are not the same thing — pick deliberately.
#
#   hook_repo_root      the *project* the session was opened on. Client env var
#                       first, so installed tooling is found where it lives.
#   hook_worktree_root  the working tree the command actually runs in. What git
#                       state — branch, status, diff — must be read from.
#
# They diverge inside a `git worktree`: $CLAUDE_PROJECT_DIR keeps pointing at
# the main checkout, so anything deciding on a branch through hook_repo_root
# judges the wrong tree.

hook_repo_root() {
  printf '%s' "${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
}

hook_worktree_root() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ]; then
    printf '%s' "$top"
    return 0
  fi
  printf '%s' "${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-$(pwd)}}"
}

# hook_json_field <payload> <dotted.path> — echo a string field, or nothing.
# jq when available, python3 otherwise; with neither, the hook sees an empty
# value and no-ops rather than failing the turn.
hook_json_field() {
  local payload="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "${path} // empty" 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -c '
import json, sys
keys = [k for k in sys.argv[1].lstrip(".").split(".") if k]
try:
    cur = json.load(sys.stdin)
    for key in keys:
        cur = cur.get(key) if isinstance(cur, dict) else None
    print("" if cur is None else cur if isinstance(cur, str) else json.dumps(cur))
except Exception:
    print("")
' "$path" 2>/dev/null || true
  fi
}

# hook_command_skeleton <command> — the command text with heredoc bodies and
# quoted spans removed, so only tokens a shell would EXECUTE survive.
#
# This is the difference between script and data. Splitting a raw command string
# on punctuation treats every quoted mention of `git commit` as a command, so a
# PR body or an issue body that merely *documents* this workflow trips the
# guard. Two portable awk passes: drop heredoc bodies, then drop quoted spans.
hook_command_skeleton() {
  printf '%s' "$1" | awk '
    # Pass 1 (line-oriented): drop heredoc bodies.
    BEGIN { sq = sprintf("%c", 39); dq = sprintf("%c", 34); delim = ""; strip = 0 }
    {
      if (delim != "") {
        t = $0
        if (strip) sub(/^\t+/, "", t)        # `<<-` strips leading tabs
        if (t == delim) { delim = ""; next } # closing delimiter — drop it
        next                                 # body line — drop it
      }
      line = $0
      if (match(line, /<<-?[ \t]*/)) {
        op = substr(line, RSTART, RLENGTH)
        rest = substr(line, RSTART + RLENGTH)
        strip = (op ~ /-/) ? 1 : 0
        first = substr(rest, 1, 1)
        if (first == sq || first == dq) rest = substr(rest, 2)
        if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/))
          delim = substr(rest, RSTART, RLENGTH)
        else
          delim = ""                         # `<<<herestring`, `a<<b` shift, …
      }
      print line
    }
  ' | awk '
    # Pass 2 (whole input): drop single- and double-quoted spans, multiline.
    BEGIN { sq = sprintf("%c", 39); dq = sprintf("%c", 34) }
    { buf = buf $0 "\n" }
    END {
      n = length(buf); s = 0; d = 0; out = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (s) { if (c == sq) s = 0; continue }
        if (d) { if (c == dq) d = 0; continue }
        if (c == sq) { s = 1; continue }
        if (c == dq) { d = 1; continue }
        if (c == "\\") { i++; out = out substr(buf, i, 1); continue }
        out = out c
      }
      printf "%s", out
    }
  '
}

# hook_command_segments <command> — the commands a shell would run, one per
# line, in order.
#
# Splits the skeleton on every sequencing operator AND on the punctuation that
# opens a nested execution context — `$(`, backticks, `(`, `)`. Without that
# last part `$(git commit -m x)` arrives as a single segment whose first token
# is `$(git`, which matches nothing and slips through. Quoted spans are already
# gone by this point, so a parenthesis that survives really is a subshell.
hook_command_segments() {
  hook_command_skeleton "$1" |
    sed -E 's/&&/\n/g; s/\|\|/\n/g; s/;/\n/g; s/\|/\n/g; s/&/\n/g; s/\$\(/\n/g; s/[`()]/\n/g'
}

# hook_deny <headline> [detail...] — refuse the tool call and say why.
# Exit status 2 is the "block with feedback" contract in both clients.
hook_deny() {
  printf '\n⛔ helm-charts hook: %s\n' "$1" >&2
  shift
  for line in "$@"; do printf '   %s\n' "$line" >&2; done
  printf '\n' >&2
  exit 2
}
