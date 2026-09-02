#!/usr/bin/env bash
#
# PreToolUse(Bash) guard — AGENTS.md: every change lands on a branch and is
# merged through a reviewed PR. This blocks `git commit` on main and any
# `git push` whose refspec would update it.
#
# Best-effort convenience guard, not a security control; branch protection on
# the remote is the real one. Exit 2 blocks the call and feeds the message back.
#
# What it is careful about — a guard with a high false-positive rate gets
# routinely overridden, and then it protects nothing:
#
#   * It judges the working tree the command will actually run in, which is not
#     necessarily the one the hook runs in. A PreToolUse hook fires BEFORE the
#     command and in the session's directory, so a leading `cd <worktree>` and a
#     `git -C <dir>` are both followed and the branch re-read there.
#   * A push is judged by its REFSPEC, not by the checked-out branch. Pushing a
#     feature branch or a tag is fine from anywhere.
#   * Only text a shell would EXECUTE is inspected (hook_command_skeleton drops
#     heredoc bodies and quoted spans), so an issue or PR body that discusses
#     committing to main is data, not a violation.
#
# Limitations, all the same shape: only what is spelled out in the command text
# is seen. A branch or directory change made inside a script, through `eval`, or
# through a variable is invisible.
#
# Escape hatch for the rare legitimate case: HELM_CHARTS_ALLOW_MAIN_COMMIT=1,
# exported into the session or written as a prefix on the command itself — a
# hook runs in its own process, so a prefix never reaches this script's
# environment and has to be read off the command line.
set -uo pipefail
set -f # the `set -- $seg` word-splits below must not glob

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${HELM_CHARTS_ALLOW_MAIN_COMMIT:-0}" = "1" ] && exit 0
[ -t 0 ] && exit 0

input="$(cat)"
cmd="$(hook_json_field "$input" '.tool_input.command')"
[ -n "$cmd" ] || exit 0

hook_cwd="$(hook_json_field "$input" '.cwd')"
current_dir="${hook_cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# Refs that may only be updated through a pull request.
is_protected() {
  case "${1#refs/heads/}" in
    main | master) return 0 ;;
  esac
  return 1
}

branch_at() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || true; }

resolve_dir() {
  # shellcheck disable=SC2088 # these are match patterns for literal input,
  # not a tilde we expect the shell to expand — $HOME is substituted by hand.
  case "$1" in
    /*) printf '%s' "$1" ;;
    "~") printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *) printf '%s/%s' "$current_dir" "$1" ;;
  esac
}

deny_commit() {
  hook_deny "you are on '$1' — commit to a branch instead." \
    "Run:  git switch -c eutychus/<issue>-<slug>   as its own command, then commit." \
    "Branch read from the tree this command runs in: $2." \
    "Compound commands are read left to right, so 'git switch -c x && git commit' is fine." \
    "Override a genuine exception with HELM_CHARTS_ALLOW_MAIN_COMMIT=1."
}

deny_push() {
  hook_deny "refusing to push $1 — chart changes land on main via PR." \
    "Push a feature branch or a release tag instead, then: gh pr create." \
    "Pushing any other ref from this tree is allowed, whatever branch is checked out." \
    "Override a genuine exception with HELM_CHARTS_ALLOW_MAIN_COMMIT=1."
}

# guard_push <args-after-push...> — deny when the refspec would update main.
# $judged is the branch of the tree this push runs in.
guard_push() {
  local tok want_value=0 remote_seen=0 bulk=0 refs="" ref target
  while [ "$#" -gt 0 ]; do
    tok="$1"
    shift
    if [ "$want_value" -eq 1 ]; then
      want_value=0
      continue
    fi
    case "$tok" in
      --all | --mirror) bulk=1 ;;
      -o | --push-option | --repo | --receive-pack | --exec) want_value=1 ;;
      -* | "") ;;
      *)
        # first bare word is the remote, everything after it is a refspec
        if [ "$remote_seen" -eq 0 ]; then remote_seen=1; else refs="$refs $tok"; fi
        ;;
    esac
  done

  [ "$bulk" -eq 1 ] && deny_push "with --all/--mirror, which includes main"

  # No refspec: git pushes the current branch.
  if [ -z "${refs// /}" ]; then
    is_protected "$judged" && deny_push "'$judged' (the checked-out branch)"
    return 0
  fi

  for ref in $refs; do
    ref="${ref#+}" # +src:dst — a forced update is still an update
    case "$ref" in
      *:*)
        target="${ref#*:}" # `:branch` deletes it remotely; still an update
        [ -n "$target" ] || target="${ref%%:*}"
        ;;
      *) target="$ref" ;;
    esac
    [ "$target" = "HEAD" ] && target="$judged"
    case "$target" in
      refs/tags/* | refs/remotes/*) continue ;;
    esac
    is_protected "$target" && deny_push "'${target#refs/heads/}'"
  done
}

# guard_checkout <args-after-checkout/switch...> — update the branch believed
# for the rest of the chain, so `git switch -c feat && git commit` passes.
guard_checkout() {
  local tok create=0
  while [ "$#" -gt 0 ]; do
    tok="$1"
    shift
    case "$tok" in
      -b | -B | -c | -C | --create | --force-create)
        create=1
        continue
        ;;
      --) return 0 ;;
      -* | "") continue ;;
    esac
    if [ "$create" -eq 1 ]; then
      effective="$tok"
    elif git -C "$current_dir" rev-parse --verify --quiet "refs/heads/$tok" >/dev/null 2>&1; then
      effective="$tok" # a real branch; anything else is a pathspec
    fi
    return 0
  done
}

effective="$(branch_at "$current_dir")"

# Split the skeleton into ordered segments on the shell sequencing operators.
segments="$(hook_command_segments "$cmd")"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  # shellcheck disable=SC2086 # deliberate word-split; `set -f` disables globbing
  set -- $seg
  [ $# -eq 0 ] && continue

  # Leading `VAR=value` environment assignments, and the documented escape hatch
  # spelled as a prefix (a hook never sees a prefix in its own environment).
  while [ $# -gt 0 ]; do
    case "$1" in
      HELM_CHARTS_ALLOW_MAIN_COMMIT=1) exit 0 ;;
      [A-Za-z_]*=*) shift ;;
      sudo | command | env | time | nohup) shift ;;
      *) break ;;
    esac
  done
  [ $# -eq 0 ] && continue

  if [ "$1" = "cd" ]; then
    if [ -n "${2:-}" ] && [ "$2" != "-" ]; then
      current_dir="$(resolve_dir "$2")"
      effective="$(branch_at "$current_dir")"
    fi
    continue
  fi

  [ "$1" = "git" ] || continue
  shift

  # git's own options sit before the subcommand. -C is the only one that says
  # which tree the command operates on.
  own_tree=1
  target_dir="$current_dir"
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        shift
        [ $# -gt 0 ] && {
          target_dir="$(resolve_dir "$1")"
          own_tree=0
          shift
        }
        ;;
      -c | --git-dir | --work-tree | --namespace | --exec-path)
        shift
        [ $# -gt 0 ] && shift
        ;;
      --*=* | -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || continue

  if [ "$own_tree" -eq 1 ]; then judged="$effective"; else judged="$(branch_at "$target_dir")"; fi

  subcmd="$1"
  shift
  case "$subcmd" in
    checkout | switch) [ "$own_tree" -eq 1 ] && guard_checkout "$@" ;;
    commit) is_protected "$judged" && deny_commit "$judged" "$target_dir" ;;
    push) guard_push "$@" ;;
  esac
done <<EOF
$segments
EOF

exit 0
