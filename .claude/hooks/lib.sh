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

# hook_command_skeleton <command> — the command text reduced to what a shell
# would EXECUTE, with quoting resolved rather than discarded.
#
# Two passes:
#   1. Drop heredoc bodies entirely. `bash <<EOF … EOF` is opaque to us anyway,
#      and a PR or issue body fed through one is pure data.
#   2. Strip the quote characters but KEEP what they contained — with every
#      shell metacharacter inside them replaced by a space.
#
# That second rule is the whole design, and getting it wrong breaks the guards
# in one direction or the other:
#
#   * DROPPING quoted content (the obvious simplification) silently disarms
#     them: `git push origin "HEAD:main"` loses its refspec and reads as a bare
#     push, and `git push origin "main"` reads as a push with no ref at all.
#     Both then sail past a guard that catches the unquoted spelling.
#   * KEEPING quoted content verbatim makes them fire on prose: an issue body
#     that says "never git commit on main" would split into a segment starting
#     with `git`.
#
# Keeping the content but neutralising `; & | ( ) $ \` and newlines inside it
# satisfies both. A quoted span can no longer *start* a segment — it stays part
# of the word it sits in, so `--body "…git commit…"` remains an argument of the
# `gh` command — while `"HEAD:main"` stays visible as the operand it is.
hook_command_skeleton() {
  printf '%s' "$1" | awk '
    # Pass 1 (line-oriented): drop heredoc bodies — but not the substitutions
    # inside an unquoted one, which the shell really does execute.
    BEGIN { sq = sprintf("%c", 39); dq = sprintf("%c", 34); delim = ""; strip = 0; quoted = 1 }

    # subs(line) — only the text inside $(…) and `…` spans, joined by `;` so the
    # segment splitter sees each as its own command. Everything else in the line
    # is data: a PR body written through a heredoc must stay invisible.
    function subs(line,   out, i, n, c, depth, buf) {
      out = ""; n = length(line); i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (c == "$" && substr(line, i + 1, 1) == "(") {
          depth = 1; i += 2; buf = ""
          while (i <= n && depth > 0) {
            c = substr(line, i, 1)
            if (c == "(") depth++
            else if (c == ")") { depth--; if (depth == 0) { i++; break } }
            buf = buf c; i++
          }
          out = out "; " buf
          continue
        }
        if (c == "`") {
          i++; buf = ""
          while (i <= n && substr(line, i, 1) != "`") { buf = buf substr(line, i, 1); i++ }
          i++
          out = out "; " buf
          continue
        }
        i++
      }
      return out
    }
    {
      if (delim != "") {
        t = $0
        if (strip) sub(/^\t+/, "", t)        # `<<-` strips leading tabs
        if (t == delim) { delim = ""; next } # closing delimiter — drop it
        # <<"EOF" / <<'"'"'EOF'"'"' is fully literal; bare <<EOF expands.
        if (!quoted) { e = subs(t); if (e != "") print e }
        next
      }
      line = $0
      if (match(line, /<<-?[ \t]*/)) {
        op = substr(line, RSTART, RLENGTH)
        rest = substr(line, RSTART + RLENGTH)
        strip = (op ~ /-/) ? 1 : 0
        first = substr(rest, 1, 1)
        quoted = (first == sq || first == dq) ? 1 : 0
        if (quoted) rest = substr(rest, 2)
        if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/))
          delim = substr(rest, RSTART, RLENGTH)
        else
          delim = ""                         # `<<<herestring`, `a<<b` shift, …
      }
      print line
    }
  ' | awk '
    # Pass 2 (whole input): unquote, neutralising metacharacters inside quotes.
    BEGIN { sq = sprintf("%c", 39); dq = sprintf("%c", 34) }
    # Inside quotes these are literal text to the shell, so they must not be
    # able to start a segment here either. Two levels, because the shell has
    # two: single quotes make EVERYTHING literal, double quotes still perform
    # substitution.
    function safe_sq(c) {
      if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" ||
          c == "$" || c == "`" || c == "\n") return " "
      return c
    }
    function safe_dq(c) {
      # `$` and a backtick survive: `echo "$(git commit)"` really does run git,
      # so the segment splitter must still see the substitution. Everything else
      # is literal inside double quotes, exactly as in single quotes.
      if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" ||
          c == "\n") return " "
      return c
    }
    { buf = buf $0 "\n" }
    END {
      n = length(buf); s = 0; d = 0; out = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (s) {                                   # single quotes: all literal
          if (c == sq) { s = 0; continue }
          out = out safe_sq(c); continue
        }
        if (d) {                                   # double quotes: \ escapes
          if (c == "\\") {
            e = substr(buf, i + 1, 1)
            # A backslash-escaped $ or ` is literal even in double quotes.
            if (e == "$" || e == "`") { i++; out = out " "; continue }
            if (e == dq || e == "\\") { i++; out = out safe_dq(e); continue }
            out = out c; continue
          }
          if (c == dq) { d = 0; continue }
          # `$(` opens a real substitution even here. Emit the pair intact so
          # the segment splitter can see it — safe_dq would otherwise blank the
          # `(` and leave a lone `$`, which matches nothing.
          if (c == "$" && substr(buf, i + 1, 1) == "(") { out = out "$("; i++; continue }
          out = out safe_dq(c); continue
        }
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

# hook_unwrap_shell — consume a leading `sh|bash|zsh -c` so the command it is
# handed is judged on its own terms. Sets the positional parameters of the
# CALLER via the `unwrapped` array.
#
# `bash -c "git push origin main"` otherwise reads as a `bash` command and is
# waved through. This only follows what is spelled out: a script file, `eval`,
# or a command built from a variable stays invisible, which is the same
# documented blind spot as a computed refspec.
hook_unwrap_shell() {
  # shellcheck disable=SC2034 # read by the caller, which sources this file
  unwrapped=("$@")
  case "${1:-}" in
    sh | bash | zsh | dash | ksh) ;;
    *) return 0 ;;
  esac
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -c)
        shift
        # shellcheck disable=SC2034 # read by the caller
        unwrapped=("$@")
        return 0
        ;;
      -*) shift ;;
      *) return 0 ;; # `bash script.sh` — the file's contents are not visible
    esac
  done
  return 0
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
