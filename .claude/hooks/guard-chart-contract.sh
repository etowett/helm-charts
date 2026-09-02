#!/usr/bin/env bash
#
# PreToolUse(Bash) guard — the chart contract, enforced at commit time.
#
# AGENTS.md states it and CI enforces it with `ct lint --check-version-increment`,
# but CI is minutes away and the failure arrives after the PR is already open.
# This is the same rule, four seconds earlier: a commit that changes a chart's
# rendered output must also bump `Chart.yaml` version and record the change in
# that chart's CHANGELOG.md.
#
# What counts as "changes rendered output": templates/, values.yaml,
# values.schema.json, Chart.yaml (anything but the version line), .helmignore.
# README and examples edits alone do not — examples are CI-validated but do not
# ship in the package, and a docs-only fix should not force a release.
#
# Judged against what is actually STAGED, read from git, not from the command
# text — so `git commit -a`, `git commit --amend` and a pre-staged index are all
# seen correctly. Only text a shell would execute is inspected, so a PR body
# that discusses committing is data, not a violation.
#
# Escape hatch: HELM_CHARTS_SKIP_CONTRACT=1, exported or as a command prefix.
set -uo pipefail
set -f

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${HELM_CHARTS_SKIP_CONTRACT:-0}" = "1" ] && exit 0
[ -t 0 ] && exit 0

input="$(cat)"
cmd="$(hook_json_field "$input" '.tool_input.command')"
[ -n "$cmd" ] || exit 0

hook_cwd="$(hook_json_field "$input" '.cwd')"
current_dir="${hook_cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}"

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

# --- find a `git commit` in the command, and the tree it runs in -------------

commit_dir=""
amend=0
stage_all=0
segments="$(hook_command_skeleton "$cmd" | sed -E 's/&&/\n/g; s/\|\|/\n/g; s/;/\n/g; s/\|/\n/g; s/&/\n/g')"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  # shellcheck disable=SC2086
  set -- $seg
  [ $# -eq 0 ] && continue

  while [ $# -gt 0 ]; do
    case "$1" in
      HELM_CHARTS_SKIP_CONTRACT=1) exit 0 ;;
      [A-Za-z_]*=*) shift ;;
      sudo | command | env | time | nohup) shift ;;
      *) break ;;
    esac
  done
  [ $# -eq 0 ] && continue

  if [ "$1" = "cd" ]; then
    [ -n "${2:-}" ] && [ "$2" != "-" ] && current_dir="$(resolve_dir "$2")"
    continue
  fi

  [ "$1" = "git" ] || continue
  shift

  target_dir="$current_dir"
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        shift
        [ $# -gt 0 ] && {
          target_dir="$(resolve_dir "$1")"
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
  [ "$1" = "commit" ] || continue
  shift

  commit_dir="$target_dir"
  for tok in "$@"; do
    case "$tok" in
      --amend) amend=1 ;;
      -a | --all | -am | -am*) stage_all=1 ;;
    esac
  done
done <<EOF
$segments
EOF

[ -n "$commit_dir" ] || exit 0
git -C "$commit_dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# --- what does this commit actually change? ----------------------------------

# `--amend` re-writes the previous commit, so its files are in scope too.
# `-a`/`-am` stages every tracked modification, so compare against the worktree.
diff_base="--cached"
[ "$amend" -eq 1 ] && diff_base="--cached HEAD~1"
changed="$(
  {
    # shellcheck disable=SC2086
    git -C "$commit_dir" diff --name-only $diff_base 2>/dev/null
    [ "$stage_all" -eq 1 ] && git -C "$commit_dir" diff --name-only HEAD 2>/dev/null
  } | sort -u
)"
[ -n "$changed" ] || exit 0

# Charts whose PACKAGED content changed. README.md and examples/ are excluded on
# purpose: they are validated by CI but do not ship, so a docs fix must not force
# a version bump.
packaging_changed="$(
  printf '%s\n' "$changed" |
    grep -E '^charts/[^/]+/(templates/|Chart\.yaml$|values\.yaml$|values\.schema\.json$|\.helmignore$)' |
    sed -E 's#^charts/([^/]+)/.*#\1#' | sort -u
)"
[ -n "$packaging_changed" ] || exit 0

violations=()
for chart in $packaging_changed; do
  version_bumped=0
  changelog_touched=0

  # A Chart.yaml in the diff is not enough — the `version:` line itself must move.
  # shellcheck disable=SC2086
  if git -C "$commit_dir" diff $diff_base -- "charts/$chart/Chart.yaml" 2>/dev/null |
    grep -Eq '^\+[[:space:]]*version:'; then
    version_bumped=1
  fi
  if [ "$stage_all" -eq 1 ] && [ "$version_bumped" -eq 0 ] &&
    git -C "$commit_dir" diff HEAD -- "charts/$chart/Chart.yaml" 2>/dev/null |
    grep -Eq '^\+[[:space:]]*version:'; then
    version_bumped=1
  fi

  printf '%s\n' "$changed" | grep -qx "charts/$chart/CHANGELOG.md" && changelog_touched=1

  missing=""
  [ "$version_bumped" -eq 0 ] && missing="Chart.yaml version"
  [ "$changelog_touched" -eq 0 ] && missing="${missing:+$missing and }CHANGELOG.md entry"
  [ -n "$missing" ] && violations+=("$chart: missing $missing")
done

[ "${#violations[@]}" -eq 0 ] && exit 0

details=()
for v in "${violations[@]}"; do details+=("• $v"); done
details+=(
  ""
  "The chart contract (AGENTS.md → Conventions): a change to templates/,"
  "values.yaml, values.schema.json or Chart.yaml ships in the package, so it"
  "needs a version bump and a changelog entry. CI enforces the version half"
  "via 'ct lint --check-version-increment' — this catches both, now."
  ""
  "README.md and examples/ edits alone are exempt and never reach this hook."
  "Override a genuine exception with HELM_CHARTS_SKIP_CONTRACT=1."
)
hook_deny "chart change without a version bump and changelog entry." "${details[@]}"
